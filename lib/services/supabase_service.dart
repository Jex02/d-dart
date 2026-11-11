import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/campus_location.dart';
import '../models/class_schedule.dart';
import '../models/problem_report.dart';
import '../models/system_config.dart';
import '../models/user_profile.dart';
import '../mock_data.dart';

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

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String verificationBucket = 'verification-documents';

  SupabaseClient get client => Supabase.instance.client;
  UserProfile? cachedProfile;

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

    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
        'student_id': studentId,
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
      }

      try {
        await client.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'student_id': studentId,
          'role': 'customer',
          'account_type': accountType,
          'verification_status': verificationStatus,
          'cor_verified': isStudent && corVerified,
          'id_document_path': ?idDocPath,
          'cor_document_path': ?corDocPath,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Warning: Could not save to profiles table: $e');
      }

      if (initialSchedule != null && initialSchedule.isNotEmpty && response.session != null) {
        try {
          await saveClassSchedule(initialSchedule);
        } catch (e) {
          debugPrint('Warning: Could not save initial schedule: $e');
        }
      }
    }

    return response;
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
      email: email,
      password: password,
    );
    await fetchUserProfileModel();
    return res;
  }

  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  Future<void> signOut() async {
    cachedProfile = null;
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
    if (user == null) return null;

    final map = await fetchUserProfile();
    if (map != null) {
      cachedProfile = UserProfile.fromJson(map);
      return cachedProfile;
    }

    final meta = user.userMetadata ?? {};
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
  }) async {
    final uid = currentUser?.id;
    await client.from('problem_reports').insert({
      'request_id': ?requestId,
      'reporter_id': ?uid,
      'category': category,
      'description': description.trim(),
      'status': 'open',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<ProblemReport>> fetchProblemReports() async {
    final rows = await client
        .from('problem_reports')
        .select()
        .order('created_at', ascending: false);
    return (rows as List)
        .map((e) => ProblemReport.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
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

  // ==========================================
  // RUNNER SCHEDULES (COR SYNC)
  // ==========================================

  Future<void> saveClassSchedule(
    List<ClassSession> sessions, {
    Uint8List? corImageBytes,
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
        fileName: 'cor_document.jpg',
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
}
