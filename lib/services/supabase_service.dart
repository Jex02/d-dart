import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/campus_location.dart';
import '../models/class_schedule.dart';
import '../models/order_message.dart';
import '../models/problem_report.dart';
import '../models/system_config.dart';
import '../models/user_profile.dart';
import '../mock_data.dart';
import '../data/campus_menu_catalog.dart';
import '../models/cart_item.dart';
import 'cart_service.dart';
import 'chat_read_tracker.dart';
import 'duty_lock_service.dart';
import 'remember_me_service.dart';

enum ClaimOrderStatus {
  claimed,
  alreadyClaimed,
  ineligible,
  dailyLimitReached,
  expired,
  failed,
}

class ClaimOrderResult {
  final ClaimOrderStatus status;
  final String message;

  const ClaimOrderResult(this.status, this.message);

  bool get isSuccess => status == ClaimOrderStatus.claimed;
}

class OrderCounterpartInfo {
  final String userId;
  final String fullName;
  final String studentId;
  final String accountType;
  final String? idDocumentPath;
  final String? idPhotoUrl;
  final String counterpartRole; // 'runner' or 'customer'

  const OrderCounterpartInfo({
    required this.userId,
    required this.fullName,
    this.studentId = '',
    this.accountType = 'student',
    this.idDocumentPath,
    this.idPhotoUrl,
    required this.counterpartRole,
  });

  String get displayName =>
      fullName.trim().isNotEmpty ? fullName.trim() : (counterpartRole == 'runner' ? 'Runner' : 'Customer');
}

class _PendingSignupArtifacts {
  final Uint8List? idDocumentBytes;
  final String idDocumentExt;
  final Uint8List? corDocumentBytes;
  final String corDocumentExt;
  final List<ClassSession> schedule;

  const _PendingSignupArtifacts({
    this.idDocumentBytes,
    this.idDocumentExt = 'jpg',
    this.corDocumentBytes,
    this.corDocumentExt = 'jpg',
    this.schedule = const [],
  });
}

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String verificationBucket = 'verification-documents';

  SupabaseClient get client => Supabase.instance.client;
  UserProfile? cachedProfile;

  /// Holds documents & schedule in memory when signup requires email confirmation
  /// before an authenticated Storage/PostgREST session exists.
  final Map<String, _PendingSignupArtifacts> _pendingSignupArtifacts = {};

  /// In-memory stream controllers for mock/offline direct messaging
  final Map<String, StreamController<List<OrderMessage>>> _mockMessageStreamControllers = {};

  // ==========================================
  // AUTHENTICATION & PROFILES
  // ==========================================

  User? get currentUser {
    try {
      return client.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated => currentUser != null;

  /// Checks whether a Student / Employee ID number is not yet registered.
  /// Uses a boolean-only Postgres RPC backed by `idx_profiles_unique_student_id`.
  Future<bool> isStudentIdAvailable(String studentId) async {
    final trimmed = studentId.trim();
    if (trimmed.isEmpty) return false;
    final result = await client.rpc(
      'is_student_id_available',
      params: {'p_student_id': trimmed},
    );
    return result == true;
  }

  /// Sign up user (Student or Faculty/Staff) with pending admin verification per SRS 3.1.1.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String studentId,
    String accountType = 'student',
    bool corVerified = false,
    List<ClassSession>? initialSchedule,
    Uint8List? idDocumentBytes,
    String idDocumentExt = 'jpg',
    Uint8List? corDocumentBytes,
    String corDocumentExt = 'jpg',
  }) async {
    final isStudent = accountType == 'student';
    const verificationStatus = 'pending';
    final normalizedEmail = email.trim().toLowerCase();
    final trimmedStudentId = studentId.trim();

    final response = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
        'student_id': trimmedStudentId,
        'role': 'customer',
        'account_type': accountType,
        'verification_status': verificationStatus,
        'cor_verified': isStudent && corVerified,
        if (initialSchedule != null && initialSchedule.isNotEmpty)
          'schedule': initialSchedule.map((s) => s.toJson()).toList(),
      },
    );

    if (response.user != null) {
      String? idDocPath;
      String? corDocPath;

      if (response.session != null) {
        final uid = response.user!.id;
        if (idDocumentBytes != null && idDocumentBytes.isNotEmpty) {
          idDocPath = await uploadVerificationDocument(
            userId: uid,
            fileName: 'id_document.$idDocumentExt',
            bytes: idDocumentBytes,
          );
        }
        if (corDocumentBytes != null && corDocumentBytes.isNotEmpty) {
          corDocPath = await uploadVerificationDocument(
            userId: uid,
            fileName: 'cor_document.$corDocumentExt',
            bytes: corDocumentBytes,
          );
        }

        try {
          await client.from('profiles').update({
            'full_name': fullName,
            'email': email.trim(),
            'phone_number': phoneNumber,
            'student_id': trimmedStudentId,
            'cor_verified': isStudent && corVerified,
            'id_document_path': ?idDocPath,
            'cor_document_path': ?corDocPath,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', uid);
        } catch (e) {
          debugPrint('Warning: Could not update profile details: $e');
        }

        if (initialSchedule != null && initialSchedule.isNotEmpty) {
          try {
            await saveClassSchedule(
              initialSchedule,
              corDocumentExt: corDocumentExt,
            );
          } catch (e) {
            debugPrint('Warning: Could not save initial schedule: $e');
          }
        }
      } else {
        // Email confirmation enabled: defer Storage upload & schedule insert until first login
        _pendingSignupArtifacts[normalizedEmail] = _PendingSignupArtifacts(
          idDocumentBytes: idDocumentBytes,
          idDocumentExt: idDocumentExt,
          corDocumentBytes: corDocumentBytes,
          corDocumentExt: corDocumentExt,
          schedule: initialSchedule ?? const [],
        );
      }
    }

    return response;
  }

  Future<void> _flushPendingSignupArtifacts() async {
    final user = currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null) return;

    final pending = _pendingSignupArtifacts.remove(email);
    if (pending == null) return;

    try {
      if (pending.idDocumentBytes != null && pending.idDocumentBytes!.isNotEmpty) {
        await uploadMyIdDocument(
          pending.idDocumentBytes!,
          ext: pending.idDocumentExt,
        );
      }

      if (pending.schedule.isNotEmpty) {
        await saveClassSchedule(
          pending.schedule,
          corImageBytes: pending.corDocumentBytes,
          corDocumentExt: pending.corDocumentExt,
        );
      } else if (pending.corDocumentBytes != null &&
          pending.corDocumentBytes!.isNotEmpty) {
        final corPath = await uploadVerificationDocument(
          userId: user.id,
          fileName: 'cor_document.${pending.corDocumentExt}',
          bytes: pending.corDocumentBytes!,
        );
        if (corPath != null) {
          await client.from('profiles').update({
            'cor_document_path': corPath,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', user.id);
        }
      }
    } catch (e) {
      debugPrint('Deferred signup artifact upload warning: $e');
    }
  }

  Future<String?> uploadVerificationDocument({
    required String userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final path = '$userId/$fileName';
      await client.storage.from(verificationBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      return path;
    } catch (e) {
      debugPrint('Storage upload warning ($fileName): $e');
      return null;
    }
  }

  /// Generates a short-lived signed URL so Admins or the owner can inspect private docs.
  Future<String?> getSignedDocumentUrl(String storagePath) async {
    if (storagePath.trim().isEmpty) return null;
    try {
      return await client.storage
          .from(verificationBucket)
          .createSignedUrl(storagePath, 300);
    } catch (_) {
      return null;
    }
  }

  /// Uploads or replaces the signed-in user's ID document and saves its path on profiles.
  Future<String?> uploadMyIdDocument(
    Uint8List bytes, {
    String ext = 'jpg',
  }) async {
    final userId = currentUser?.id;
    if (userId == null || bytes.isEmpty) return null;

    final path = await uploadVerificationDocument(
      userId: userId,
      fileName: 'id_document.$ext',
      bytes: bytes,
    );
    if (path == null) return null;

    await client.from('profiles').update({
      'id_document_path': path,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
    await fetchUserProfileModel();
    return path;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final res = await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    await _flushPendingSignupArtifacts();
    await fetchUserProfileModel();
    return res;
  }

  Future<void> resetPassword(String email, {String? redirectTo}) async {
    final effectiveRedirect =
        redirectTo ?? (kIsWeb ? Uri.base.origin : 'ddart://reset-password');
    await client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: effectiveRedirect,
    );
  }

  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    return await client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: OtpType.recovery,
    );
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    return await client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  Future<void> signOut() async {
    cachedProfile = null;
    CartService.instance.clearCart();
    DutyLockService.reset();
    ChatReadTracker.instance.clear();
    await RememberMeService.clearEphemeralFlag();
    await client.auth.signOut();
  }

  Future<void> updateUserRole(String role) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    try {
      await client.from('profiles').update({
        'role': role,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final userId = currentUser?.id;
    if (userId == null) return null;

    try {
      final res = await client.from('profiles').select().eq('id', userId).maybeSingle();
      return res;
    } catch (_) {
      return null;
    }
  }

  Future<UserProfile?> fetchUserProfileModel() async {
    final user = currentUser;
    if (user == null) {
      cachedProfile = null;
      return null;
    }
    if (cachedProfile != null && cachedProfile!.id != user.id) {
      cachedProfile = null;
    }

    final map = await fetchUserProfile();
    if (map != null) {
      cachedProfile = UserProfile.fromJson(map);
      return cachedProfile;
    }

    final meta = user.userMetadata ?? {};
    final rawMetaCanteen = meta['assigned_canteen']?.toString().trim();
    cachedProfile = UserProfile(
      id: user.id,
      fullName: meta['full_name']?.toString() ?? '',
      email: user.email ?? '',
      phoneNumber: meta['phone_number']?.toString() ?? '',
      studentId: meta['student_id']?.toString() ?? '',
      role: meta['role']?.toString() ?? 'customer',
      accountType: meta['account_type']?.toString() ?? 'student',
      verificationStatus: meta['verification_status']?.toString() ?? 'pending',
      corVerified: meta['cor_verified'] == true,
      assignedCanteen: (rawMetaCanteen != null && rawMetaCanteen.isNotEmpty)
          ? rawMetaCanteen
          : null,
    );
    return cachedProfile;
  }

  // ==========================================
  // SYSTEM CONFIGURATION & LOCATIONS
  // ==========================================

  Future<SystemConfig> fetchSystemConfig() async {
    try {
      final rows = await client.from('system_configurations').select();
      final list = (rows as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (list.isNotEmpty) {
        return SystemConfig.fromConfigRows(list);
      }
    } catch (_) {}
    return const SystemConfig();
  }

  Future<List<Map<String, dynamic>>> fetchRawConfigs() async {
    final rows = await client
        .from('system_configurations')
        .select()
        .order('config_key');
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> updateSystemConfig(String configKey, String configValue) async {
    await client.from('system_configurations').upsert({
      'config_key': configKey,
      'config_value': configValue,
      'updated_by': currentUser?.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'config_key');
  }

  Future<List<CampusLocation>> fetchLocations(String category) async {
    try {
      final rows = await client
          .from('locations')
          .select()
          .eq('category', category)
          .eq('is_active', true)
          .order('name');
      final parsed = (rows as List)
          .map((row) => CampusLocation.fromJson(Map<String, dynamic>.from(row)))
          .toList();
      if (parsed.isNotEmpty) return parsed;
    } catch (_) {}

    return category == 'pickup'
        ? CampusLocation.defaultPickups
        : CampusLocation.defaultDropoffs;
  }

  Future<List<CampusLocation>> fetchAllLocations() async {
    final rows = await client.from('locations').select().order('category').order('name');
    return (rows as List)
        .map((row) => CampusLocation.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<void> upsertLocation({
    String? id,
    required String name,
    required String category,
    String buildingCode = '',
    bool isActive = true,
  }) async {
    final payload = <String, dynamic>{
      'id': ?id,
      'name': name.trim(),
      'category': category,
      'building_code': buildingCode.trim(),
      'is_active': isActive,
    };
    await client.from('locations').upsert(payload);
  }

  Future<void> toggleLocationActive(String id, bool isActive) async {
    await client.from('locations').update({'is_active': isActive}).eq('id', id);
  }

  // ==========================================
  // DELIVERY / PABILI REQUESTS
  // ==========================================

  Future<Map<String, dynamic>> createOrder({
    required String pickup,
    required String dropoff,
    required String description,
    required double price,
    double deliveryFee = 20.0,
    String? instructions,
    Duration expiresIn = const Duration(minutes: 30),
  }) async {
    final otp = (Random().nextInt(9000) + 1000).toString();
    final userId = currentUser?.id;
    final now = DateTime.now().toUtc();

    final orderData = {
      'pickup_location': pickup,
      'dropoff_location': dropoff,
      'description': description,
      'estimated_price': price,
      'delivery_fee': deliveryFee,
      'status': 'pending',
      'verification_code': otp,
      'special_instructions': instructions ?? '',
      'expires_at': now.add(expiresIn).toIso8601String(),
      'customer_id': ?userId,
      'created_at': now.toIso8601String(),
    };

    final response = await client
        .from('delivery_requests')
        .insert(orderData)
        .select()
        .single();

    return response;
  }

  Future<int> fetchRunnerCompletedTodayCount() async {
    final userId = currentUser?.id;
    if (userId == null) return 0;

    try {
      final nowLocal = DateTime.now();
      final localMidnight = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
      final rows = await client
          .from('delivery_requests')
          .select('id')
          .eq('runner_id', userId)
          .eq('status', 'completed')
          .gte('completed_at', localMidnight.toUtc().toIso8601String());
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> expireStaleOrders() async {
    expireStaleMockOrders();
    try {
      await client.rpc('expire_stale_delivery_requests');
    } catch (_) {
      try {
        await client
            .from('delivery_requests')
            .update({
              'status': 'expired',
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('status', 'pending')
            .lte('expires_at', DateTime.now().toUtc().toIso8601String());
      } catch (_) {}
    }
  }

  Stream<List<Map<String, dynamic>>> streamAvailableOrders() {
    return client
        .from('delivery_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamCustomerOrders() {
    final userId = currentUser?.id;
    if (userId == null) {
      return Stream.value(mockDeliveryRequests);
    }
    return client
        .from('delivery_requests')
        .stream(primaryKey: ['id'])
        .eq('customer_id', userId)
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamRunnerAssignedOrders() {
    final userId = currentUser?.id;
    if (userId == null) {
      return Stream.value(
        mockDeliveryRequests.where((r) => r['status'] != 'pending').toList(),
      );
    }
    return client
        .from('delivery_requests')
        .stream(primaryKey: ['id'])
        .eq('runner_id', userId)
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamAllDeliveries() {
    return client
        .from('delivery_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> streamOrder(String orderId) {
    return client
        .from('delivery_requests')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);
  }

  Future<ClaimOrderResult> claimOrder(String orderId) async {
    final runnerId = currentUser?.id;
    if (runnerId == null || orderId.startsWith('ORD-')) {
      if (claimMockOrder(orderId, runnerId: runnerId)) {
        return const ClaimOrderResult(
          ClaimOrderStatus.claimed,
          'Delivery request claimed (offline mode).',
        );
      }
      return const ClaimOrderResult(
        ClaimOrderStatus.alreadyClaimed,
        'This request has already been claimed or expired.',
      );
    }

    try {
      final rpcRes = await client.rpc(
        'claim_delivery_request',
        params: {'p_order_id': orderId},
      );
      if (rpcRes is List && rpcRes.isNotEmpty) {
        return const ClaimOrderResult(
          ClaimOrderStatus.claimed,
          'Delivery request claimed! Head to pickup.',
        );
      }
      return const ClaimOrderResult(
        ClaimOrderStatus.alreadyClaimed,
        'This request has already been claimed or expired.',
      );
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('daily delivery limit reached')) {
        return ClaimOrderResult(ClaimOrderStatus.dailyLimitReached, e.message);
      }
      if (msg.contains('only verified student runners') ||
          msg.contains('academic duty lock') ||
          msg.contains('authentication required')) {
        return ClaimOrderResult(ClaimOrderStatus.ineligible, e.message);
      }
      return ClaimOrderResult(ClaimOrderStatus.failed, e.message);
    } catch (_) {
      return const ClaimOrderResult(
        ClaimOrderStatus.failed,
        'Could not claim this request. Please check your connection and try again.',
      );
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    if (!isAuthenticated || orderId.startsWith('ORD-')) {
      return cancelMockOrder(orderId);
    }

    try {
      final rpcRes = await client.rpc(
        'cancel_delivery_request',
        params: {'p_order_id': orderId},
      );
      if (rpcRes is List && rpcRes.isNotEmpty) {
        cancelMockOrder(orderId);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await client.from('delivery_requests').update({
      'status': newStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  Future<bool> verifyAndCompleteOrder(String orderId, String inputOtp) async {
    final trimmed = inputOtp.trim();
    if (trimmed.length != 4) return false;
    if (!isAuthenticated || orderId.startsWith('ORD-')) {
      throw StateError('Offline mode verification');
    }

    final rpcRes = await client.rpc(
      'verify_and_complete_delivery',
      params: {'p_order_id': orderId, 'p_code': trimmed},
    );
    return rpcRes is List && rpcRes.isNotEmpty;
  }

  Future<List<Map<String, dynamic>>> fetchStatusLogs(String requestId) async {
    final rows = await client
        .from('delivery_status_logs')
        .select()
        .eq('request_id', requestId)
        .order('created_at', ascending: true);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  // ==========================================
  // PROBLEM REPORTS & ADMIN MANAGEMENT (WBS 7)
  // ==========================================

  Future<void> submitProblemReport({
    String? requestId,
    required String category,
    required String description,
    String? reporterRole,
    String? reportedUserId,
  }) async {
    final uid = currentUser?.id;
    final role = reporterRole ?? (cachedProfile?.role ?? 'customer');
    await client.from('problem_reports').insert({
      'request_id': ?requestId,
      'reporter_id': ?uid,
      'reporter_role': role,
      'reported_user_id': ?reportedUserId,
      'category': category,
      'description': description.trim(),
      'status': 'open',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<ProblemReport>> fetchProblemReports() async {
    try {
      final res = await client.rpc('fetch_admin_problem_reports');
      if (res is List) {
        return res
            .map((e) => ProblemReport.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (_) {
      // Fallback to table query with nested relations if RPC is unavailable
    }

    try {
      final rows = await client
          .from('problem_reports')
          .select('''
            *,
            reporter:reporter_id (
              id, full_name, email, phone_number, student_id, role, account_type
            ),
            reported_user:reported_user_id (
              id, full_name, email, phone_number, student_id, role, account_type
            ),
            order:request_id (
              id, pickup_location, dropoff_location, description, status, estimated_price, delivery_fee
            )
          ''')
          .order('created_at', ascending: false);
      return (rows as List)
          .map((e) => ProblemReport.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      final rows = await client
          .from('problem_reports')
          .select()
          .order('created_at', ascending: false);
      return (rows as List)
          .map((e) => ProblemReport.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
  }

  Stream<List<Map<String, dynamic>>> streamProblemReports() {
    return client
        .from('problem_reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }

  Future<void> updateProblemReportStatus(
    String reportId, {
    required String status,
    String? adminNotes,
  }) async {
    await client.from('problem_reports').update({
      'status': status,
      'admin_notes': ?adminNotes,
      'reviewed_by': currentUser?.id,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', reportId);
  }

  Future<void> deleteProblemReport(String reportId) async {
    await client.from('problem_reports').delete().eq('id', reportId);
  }

  Future<List<UserProfile>> fetchAllProfiles() async {
    final rows = await client
        .from('profiles')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => UserProfile.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> updateUserVerification(
    String userId, {
    required String status,
    String? rejectionReason,
  }) async {
    await client.from('profiles').update({
      'verification_status': status,
      'rejection_reason': status == 'rejected' ? (rejectionReason ?? '') : null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  /// Creates a dedicated Co-Administrator or Canteen-Scoped Admin account via the
  /// `manage-co-admin` Edge Function without disturbing the current Super Admin session.
  Future<Map<String, dynamic>> createCoAdminAccount({
    required String fullName,
    required String email,
    required String password,
    String phoneNumber = '',
    String? assignedCanteen,
  }) async {
    final normalizedCanteen =
        (assignedCanteen != null && assignedCanteen.trim().isNotEmpty)
            ? assignedCanteen.trim()
            : null;
    try {
      final response = await client.functions.invoke(
        'manage-co-admin',
        body: {
          'action': 'create',
          'full_name': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'phone_number': phoneNumber.trim(),
          'assigned_canteen': ?normalizedCanteen,
        },
      );
      final Map<String, dynamic> created = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : {'email': email.trim().toLowerCase(), 'full_name': fullName.trim()};

      // Ensure assigned_canteen is persisted on public.profiles even if the
      // deployed Edge Function predates the assigned_canteen field.
      final newUserId = created['id']?.toString();
      if (normalizedCanteen != null && newUserId != null && newUserId.isNotEmpty) {
        await client
            .from('profiles')
            .update({
              'assigned_canteen': normalizedCanteen,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', newUserId);
        created['assigned_canteen'] = normalizedCanteen;
      }

      return created;
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw Exception(details['error'].toString());
      }
      throw Exception(details?.toString() ?? e.reasonPhrase ?? 'Failed to create co-admin account.');
    }
  }

  /// Permanently removes a dedicated Co-Administrator account via the `manage-co-admin` Edge Function.
  Future<void> deleteCoAdminAccount(String userId) async {
    try {
      await client.functions.invoke(
        'manage-co-admin',
        body: {
          'action': 'delete',
          'user_id': userId,
        },
      );
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw Exception(details['error'].toString());
      }
      throw Exception(details?.toString() ?? e.reasonPhrase ?? 'Failed to delete co-admin account.');
    }
  }

  // ==========================================
  // RUNNER SCHEDULES (COR SYNC)
  // ==========================================

  Future<void> saveClassSchedule(
    List<ClassSession> sessions, {
    Uint8List? corImageBytes,
    String corDocumentExt = 'jpg',
  }) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    await client.from('runner_schedules').delete().eq('user_id', userId);

    final rows = sessions
        .map((s) => {
              'user_id': userId,
              'day': s.day,
              'start_time': s.startTime,
              'end_time': s.endTime,
              'subject': s.subject,
              'created_at': DateTime.now().toUtc().toIso8601String(),
            })
        .toList();

    if (rows.isNotEmpty) {
      await client.from('runner_schedules').insert(rows);
    }

    String? corDocPath;
    if (corImageBytes != null && corImageBytes.isNotEmpty) {
      corDocPath = await uploadVerificationDocument(
        userId: userId,
        fileName: 'cor_document.$corDocumentExt',
        bytes: corImageBytes,
      );
    }

    try {
      await client.from('profiles').update({
        'cor_verified': true,
        'cor_document_path': ?corDocPath,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
      await fetchUserProfileModel();
    } catch (_) {}
  }

  Future<List<ClassSession>> fetchClassSchedule([String? targetUserId]) async {
    final userId = targetUserId ?? currentUser?.id;
    if (userId == null) return [];

    try {
      final data = await client
          .from('runner_schedules')
          .select()
          .eq('user_id', userId);

      return (data as List)
          .map((row) => ClassSession(
                day: row['day']?.toString() ?? '',
                startTime: row['start_time']?.toString() ?? '',
                endTime: row['end_time']?.toString() ?? '',
                subject: row['subject']?.toString() ?? '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ==========================================
  // CANTEEN MENU ITEMS (CATALOG & DATABASE)
  // ==========================================

  CanteenMenuItem _mapMenuRow(Map<String, dynamic> row) {
    final rawCanteens = row['available_canteens'];
    final List<String> availableCanteens = (rawCanteens is List)
        ? rawCanteens.map((e) => e.toString()).toList()
        : const [];

    return CanteenMenuItem(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      canteen: row['canteen']?.toString() ?? 'Main Canteen',
      category: row['category']?.toString() ?? 'Food and snacks',
      price: (row['price'] is num)
          ? (row['price'] as num).toDouble()
          : (double.tryParse(row['price']?.toString() ?? '0') ?? 0.0),
      unitDescription: row['unit_description']?.toString() ?? '',
      imageUrl: row['image_url']?.toString(),
      isAvailable: row['is_available'] != false,
      availableCanteens: availableCanteens,
    );
  }

  /// Fetches campus canteen menu items from `public.canteen_menu_items`.
  /// Falls back to [CampusMenuCatalog.allItems] if the table does not yet exist or is offline.
  Future<List<CanteenMenuItem>> fetchCanteenMenuItems() async {
    try {
      final data = await client
          .from('canteen_menu_items')
          .select()
          .eq('is_available', true);

      if (data.isNotEmpty) {
        return data
            .map<CanteenMenuItem>((row) => _mapMenuRow(Map<String, dynamic>.from(row)))
            .toList();
      }
    } catch (e) {
      debugPrint('fetchCanteenMenuItems: falling back to built-in campus catalog ($e)');
    }
    return CampusMenuCatalog.allItems;
  }

  /// Fetches menu items for Super Admin (all canteens) or Canteen Admin (scoped canteen),
  /// including temporarily unavailable / sold-out items.
  Future<List<CanteenMenuItem>> fetchManageableMenuItems({String? canteen}) async {
    var query = client.from('canteen_menu_items').select();
    if (canteen != null && canteen.trim().isNotEmpty) {
      query = query.eq('canteen', canteen.trim());
    }
    final rows = await query.order('category', ascending: true).order('name', ascending: true);
    return rows
        .map<CanteenMenuItem>((row) => _mapMenuRow(Map<String, dynamic>.from(row)))
        .toList();
  }

  /// Creates or updates a canteen menu item (RLS enforces canteen ownership for Canteen Admins).
  Future<CanteenMenuItem> upsertMenuItem(CanteenMenuItem item) async {
    final effectiveId = item.id.trim().isEmpty
        ? 'item-${DateTime.now().millisecondsSinceEpoch}'
        : item.id.trim();
    final canteens = item.availableCanteens.isNotEmpty
        ? item.availableCanteens
        : <String>[item.canteen];

    final payload = {
      'id': effectiveId,
      'name': item.name.trim(),
      'canteen': item.canteen.trim(),
      'category': item.category.trim(),
      'price': item.price,
      'unit_description': item.unitDescription.trim(),
      'image_url': (item.imageUrl != null && item.imageUrl!.trim().isNotEmpty)
          ? item.imageUrl!.trim()
          : null,
      'is_available': item.isAvailable,
      'available_canteens': canteens,
    };

    final res = await client
        .from('canteen_menu_items')
        .upsert(payload, onConflict: 'id')
        .select()
        .single();
    return _mapMenuRow(Map<String, dynamic>.from(res));
  }

  Future<void> toggleMenuItemAvailability(String itemId, bool isAvailable) async {
    await client
        .from('canteen_menu_items')
        .update({'is_available': isAvailable})
        .eq('id', itemId);
  }

  Future<void> deleteMenuItem(String itemId) async {
    await client.from('canteen_menu_items').delete().eq('id', itemId);
  }

  /// Uploads a menu item photo into the public `menu-images` Storage bucket
  /// and returns its public URL.
  Future<String> uploadMenuItemImage({
    required String canteen,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeCanteen = canteen.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path = '$safeCanteen/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await client.storage.from('menu-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from('menu-images').getPublicUrl(path);
  }

  /// Reassigns an admin account's canteen scope (Super Admin only; enforced by DB trigger).
  Future<void> updateAdminCanteenScope(String userId, String? assignedCanteen) async {
    final normalized =
        (assignedCanteen != null && assignedCanteen.trim().isNotEmpty)
            ? assignedCanteen.trim()
            : null;
    await client.from('profiles').update({
      'assigned_canteen': normalized,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', userId);
  }

  // ==========================================
  // IN-APP DIRECT MESSAGING (CUSTOMER & RUNNER)
  // ==========================================

  /// Fetches the counterpart's safe display name and signed ID photo URL
  /// for an active/completed order via the `get_order_counterpart_profile` RPC.
  Future<OrderCounterpartInfo?> fetchOrderCounterpart(String orderId) async {
    if (orderId.startsWith('ORD-') || !isAuthenticated) return null;
    try {
      final res = await client.rpc(
        'get_order_counterpart_profile',
        params: {'p_order_id': orderId},
      );
      Map<String, dynamic>? row;
      if (res is List && res.isNotEmpty) {
        row = Map<String, dynamic>.from(res.first as Map);
      } else if (res is Map) {
        row = Map<String, dynamic>.from(res);
      }
      if (row == null) return null;

      final idPath = row['id_document_path']?.toString();
      String? signedUrl;
      if (idPath != null && idPath.isNotEmpty) {
        signedUrl = await getSignedDocumentUrl(idPath);
      }

      return OrderCounterpartInfo(
        userId: row['user_id']?.toString() ?? '',
        fullName: row['full_name']?.toString() ?? '',
        studentId: row['student_id']?.toString() ?? '',
        accountType: row['account_type']?.toString() ?? 'student',
        idDocumentPath: idPath,
        idPhotoUrl: signedUrl,
        counterpartRole: row['counterpart_role']?.toString() ?? 'runner',
      );
    } catch (e) {
      debugPrint('fetchOrderCounterpart error: $e');
      return null;
    }
  }

  /// Streams real-time direct chat messages for a specific delivery request.
  /// Seamlessly falls back to reactive local in-memory streams for offline/demo orders.
  Stream<List<OrderMessage>> streamOrderMessages(String orderId) {
    if (orderId.startsWith('ORD-') || !isAuthenticated) {
      final controller = _mockMessageStreamControllers.putIfAbsent(
        orderId,
        () => StreamController<List<OrderMessage>>.broadcast(),
      );

      return () async* {
        yield getMockMessagesForOrder(orderId)
            .map((m) => OrderMessage.fromJson(m))
            .toList();
        yield* controller.stream;
      }();
    }

    try {
      return client
          .from('order_messages')
          .stream(primaryKey: ['id'])
          .eq('order_id', orderId)
          .order('created_at', ascending: true)
          .map((rows) => rows.map((r) => OrderMessage.fromJson(r)).toList());
    } catch (e) {
      debugPrint('streamOrderMessages exception: $e, falling back to mock stream');
      final controller = _mockMessageStreamControllers.putIfAbsent(
        orderId,
        () => StreamController<List<OrderMessage>>.broadcast(),
      );
      return () async* {
        yield getMockMessagesForOrder(orderId)
            .map((m) => OrderMessage.fromJson(m))
            .toList();
        yield* controller.stream;
      }();
    }
  }

  /// Sends a direct chat message between the customer and runner for an order.
  Future<bool> sendOrderMessage({
    required String orderId,
    required String message,
    required String senderRole,
    String? senderName,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return false;

    final senderId = currentUser?.id;
    final metaName = currentUser?.userMetadata?['full_name']?.toString().trim();
    final validCachedName =
        (cachedProfile != null && cachedProfile!.id == senderId && cachedProfile!.fullName.isNotEmpty)
            ? cachedProfile!.fullName
            : null;
    final effectiveSenderName = (senderName != null && senderName.trim().isNotEmpty)
        ? senderName.trim()
        : (validCachedName ??
            (metaName != null && metaName.isNotEmpty
                ? metaName
                : (senderRole == 'runner' ? 'Runner' : 'Customer')));

    if (orderId.startsWith('ORD-') || !isAuthenticated) {
      addMockOrderMessage(
        orderId: orderId,
        message: trimmed,
        senderRole: senderRole,
        senderName: effectiveSenderName,
        senderId: senderId ?? 'mock-user',
      );
      final updated = getMockMessagesForOrder(orderId)
          .map((m) => OrderMessage.fromJson(m))
          .toList();
      _mockMessageStreamControllers[orderId]?.add(updated);
      return true;
    }

    if (senderId == null) {
      throw Exception('You must be signed in to send messages.');
    }

    await client.from('order_messages').insert({
      'order_id': orderId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'sender_name': effectiveSenderName,
      'message': trimmed,
    });
    return true;
  }
}
