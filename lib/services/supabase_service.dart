import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/delivery_order.dart';
import '../models/class_schedule.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // ==========================================
  // AUTHENTICATION
  // ==========================================

  User? get currentUser => client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  /// Sign up student user and insert/update their profile in `profiles` table
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
    required String studentId,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone_number': phoneNumber,
        'student_id': studentId,
        'role': 'customer',
      },
    );

    if (response.user != null) {
      try {
        await client.from('profiles').upsert({
          'id': response.user!.id,
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'student_id': studentId,
          'role': 'customer',
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (_) {
        // Table may still be creating or RLS policy applied
      }
    }

    return response;
  }

  /// Sign in existing user with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign out current user
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Update user active role ('customer' or 'runner')
  Future<void> updateUserRole(String role) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    try {
      await client.from('profiles').update({
        'role': role,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (_) {}
  }

  /// Fetch user profile details
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
  }) async {
    final otp = (Random().nextInt(9000) + 1000).toString();
    final userId = currentUser?.id;

    final orderData = {
      'pickup_location': pickup,
      'dropoff_location': dropoff,
      'description': description,
      'estimated_price': price,
      'delivery_fee': 20.0,
      'status': 'pending',
      'verification_code': otp,
      'special_instructions': instructions ?? '',
      if (userId != null) 'customer_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    final response = await client
        .from('delivery_requests')
        .insert(orderData)
        .select()
        .single();

    return response;
  }

  /// Stream of pending delivery requests for runners (Realtime)
  Stream<List<Map<String, dynamic>>> streamAvailableOrders() {
    return client
        .from('delivery_requests')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('created_at', ascending: false);
  }

  /// Stream a single order by ID for live order tracking
  Stream<List<Map<String, dynamic>>> streamOrder(String orderId) {
    return client
        .from('delivery_requests')
        .stream(primaryKey: ['id'])
        .eq('id', orderId);
  }

  /// Claim a delivery request as a runner
  Future<void> claimOrder(String orderId) async {
    final runnerId = currentUser?.id;
    await client.from('delivery_requests').update({
      'status': 'claimed',
      if (runnerId != null) 'runner_id': runnerId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }

  /// Advance delivery order status (purchasing -> en_route -> arrived)
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    await client.from('delivery_requests').update({
      'status': newStatus,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', orderId);
  }

  /// Verify 4-digit code and mark delivery as completed
  Future<bool> verifyAndCompleteOrder(String orderId, String inputOtp) async {
    final data = await client
        .from('delivery_requests')
        .select('verification_code')
        .eq('id', orderId)
        .maybeSingle();

    if (data != null && data['verification_code'] == inputOtp.trim()) {
      await client.from('delivery_requests').update({
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', orderId);
      return true;
    }
    return false;
  }

  // ==========================================
  // RUNNER SCHEDULES (COR SYNC)
  // ==========================================

  /// Save extracted COR class sessions to `runner_schedules`
  Future<void> saveClassSchedule(List<ClassSession> sessions) async {
    final userId = currentUser?.id;
    if (userId == null) return;

    // Remove previous schedule records for clean sync
    await client.from('runner_schedules').delete().eq('user_id', userId);

    final rows = sessions.map((s) => {
      'user_id': userId,
      'day': s.day,
      'start_time': s.startTime,
      'end_time': s.endTime,
      'subject': s.subject,
      'created_at': DateTime.now().toIso8601String(),
    }).toList();

    if (rows.isNotEmpty) {
      await client.from('runner_schedules').insert(rows);
    }
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
                day: row['day'] ?? '',
                startTime: row['start_time'] ?? '',
                endTime: row['end_time'] ?? '',
                subject: row['subject'] ?? '',
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
