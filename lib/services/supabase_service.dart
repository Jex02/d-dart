import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/campus_location.dart';
import '../models/class_schedule.dart';
import '../models/user_profile.dart';
import '../mock_data.dart';

enum ClaimOrderStatus {
  claimed,
  alreadyClaimed,
  ineligible,
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

  User? get currentUser => client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  /// Sign up user (Student or Faculty/Staff) and persist profile, documents, and initial schedule.
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
    // AI-verified student COR or valid Faculty/Staff ID upload marks verified for WBS 1-6 flow.
    final verificationStatus =
        isStudent ? (corVerified ? 'verified' : 'pending') : 'verified';

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

      // Upload verification documents to Supabase Storage when authenticated session exists
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
          if (idDocPath != null) 'id_document_path': idDocPath,
          if (corDocPath != null) 'cor_document_path': corDocPath,
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

  /// Upload ID or COR image to private Supabase Storage bucket.
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

  /// Sign in existing user with email and password
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

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim());
  }

  /// Sign out current user
  Future<void> signOut() async {
    cachedProfile = null;
    await client.auth.signOut();
  }

  /// Update user active mode ('customer' or 'runner') without overwriting account_type
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

  /// Fetch raw user profile map
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

  /// Fetch typed [UserProfile], falling back cleanly to auth user metadata if needed.
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
  // CAMPUS LOCATIONS
  // ==========================================

  /// Fetch active campus pickup or dropoff locations with offline fallback.
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

  // ==========================================
  // DELIVERY / PABILI REQUESTS
  // ==========================================

  /// Create a new delivery request in `delivery_requests` table
  Future<Map<String, dynamic>> createOrder({
    required String pickup,
    required String dropoff,
    required String description,
    required double price,
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
      'delivery_fee': 20.0,
      'status': 'pending',
      'verification_code': otp,
      'special_instructions': instructions ?? '',
      'expires_at': now.add(expiresIn).toIso8601String(),
      if (userId != null) 'customer_id': userId,
      'created_at': now.toIso8601String(),
    };

    final response = await client
        .from('delivery_requests')
        .insert(orderData)
        .select()
        .single();

    return response;
  }

  /// Mark stale pending orders as expired in Supabase and mock data.
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

  /// Stream of pending delivery requests for runners (Realtime)
  Stream<List<Map<String, dynamic>>> streamAvailableOrders() {
    return client
        .from('delivery_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false);
  }

  /// Stream of current customer's orders (Realtime)
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

  /// Stream of orders claimed by the current runner (Realtime)
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

  /// Stream a single order by ID for live order tracking
  Stream<List<Map<String, dynamic>>> streamOrder(String orderId) {
    return client
        .from('delivery_requests')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);
  }

  /// Atomically claim a pending delivery request (first-come-first-served).
  Future<ClaimOrderResult> claimOrder(String orderId) async {
    final runnerId = currentUser?.id;

    // Try server-side atomic RPC first
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
      if (msg.contains('only verified student runners')) {
        return ClaimOrderResult(ClaimOrderStatus.ineligible, e.message);
      }
      // Fall through to conditional REST update if RPC isn't deployed yet
    } catch (_) {}

    // Conditional REST fallback (still atomic against status = 'pending')
    try {
      final updated = await client
          .from('delivery_requests')
          .update({
            'status': 'claimed',
            if (runnerId != null) 'runner_id': runnerId,
            'claimed_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('status', 'pending')
          .select()
          .maybeSingle();

      if (updated != null) {
        return const ClaimOrderResult(
          ClaimOrderStatus.claimed,
          'Delivery request claimed! Head to pickup.',
        );
      }
      return const ClaimOrderResult(
        ClaimOrderStatus.alreadyClaimed,
        'Too late — another runner already claimed this request.',
      );
    } catch (e) {
      // Offline mock fallback
      if (claimMockOrder(orderId, runnerId: runnerId)) {
        return const ClaimOrderResult(
          ClaimOrderStatus.claimed,
          'Delivery request claimed (offline mode).',
        );
      }
      return const ClaimOrderResult(
        ClaimOrderStatus.failed,
        'Could not claim this request. Please try again.',
      );
    }
  }

  /// Cancel an unclaimed ('pending') delivery request.
  Future<bool> cancelOrder(String orderId) async {
    try {
      final rpcRes = await client.rpc(
        'cancel_delivery_request',
        params: {'p_order_id': orderId},
      );
      if (rpcRes is List && rpcRes.isNotEmpty) {
        cancelMockOrder(orderId);
        return true;
      }
    } catch (_) {}

    try {
      final updated = await client
          .from('delivery_requests')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', orderId)
          .eq('status', 'pending')
          .select()
          .maybeSingle();

      if (updated != null) {
        cancelMockOrder(orderId);
        return true;
      }
      return false;
    } catch (_) {
      return cancelMockOrder(orderId);
    }
  }

  /// Advance delivery order status (purchasing -> en_route -> arrived)
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await client.from('delivery_requests').update({
      'status': newStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', orderId);
  }

  /// Verify 4-digit code against DB record and mark delivery as completed.
  Future<bool> verifyAndCompleteOrder(String orderId, String inputOtp) async {
    final trimmed = inputOtp.trim();
    if (trimmed.length != 4) return false;

    final data = await client
        .from('delivery_requests')
        .select('verification_code, status')
        .eq('id', orderId)
        .maybeSingle();

    if (data != null &&
        data['status'] == 'arrived' &&
        data['verification_code']?.toString() == trimmed) {
      final now = DateTime.now().toUtc().toIso8601String();
      await client
          .from('delivery_requests')
          .update({
            'status': 'completed',
            'completed_at': now,
            'updated_at': now,
          })
          .eq('id', orderId)
          .eq('status', 'arrived');
      return true;
    }
    return false;
  }

  // ==========================================
  // RUNNER SCHEDULES (COR SYNC)
  // ==========================================

  /// Save extracted/confirmed COR class sessions to `runner_schedules` and mark profile verified.
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
        'verification_status': 'verified',
        if (corDocPath != null) 'cor_document_path': corDocPath,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', userId);
      await fetchUserProfileModel();
    } catch (_) {}
  }

  /// Fetch saved class schedule for duty lock checks
  Future<List<ClassSession>> fetchClassSchedule() async {
    final userId = currentUser?.id;
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
