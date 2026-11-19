import 'dart:async';
import 'package:flutter/material.dart';
import 'canteen_menu_manager_screen.dart';
import 'login.dart';
import 'main_dashboard.dart';
import 'models/campus_location.dart';
import 'models/class_schedule.dart';
import 'models/delivery_order.dart';
import 'models/problem_report.dart';
import 'models/user_profile.dart';
import 'services/duty_lock_service.dart';
import 'services/supabase_service.dart';
import 'utils/validators.dart';
import 'widgets/responsive_shell.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = SupabaseService();

  bool _loadingUsers = true;
  bool _loadingReports = true;
  bool _loadingConfig = true;

  String _userFilter = 'pending';
  String _monitorFilter = 'all';

  // Report filtering and search states
  String _reportRoleFilter = 'all'; // 'all', 'customer', 'runner'
  String _reportStatusFilter = 'all'; // 'all', 'open', 'reviewing', 'resolved', 'dismissed'
  final _reportSearchCtrl = TextEditingController();
  StreamSubscription? _reportsRealtimeSub;

  List<UserProfile> _profiles = [];
  List<ProblemReport> _reports = [];
  List<CampusLocation> _locations = [];

  final _bufferCtrl = TextEditingController();
  final _dailyLimitCtrl = TextEditingController();
  final _expirationCtrl = TextEditingController();
  final _deliveryFeeCtrl = TextEditingController();

  // Co-Admin / Canteen Admin account creation form state
  final _coAdminNameCtrl = TextEditingController();
  final _coAdminEmailCtrl = TextEditingController();
  final _coAdminPhoneCtrl = TextEditingController();
  final _coAdminPasswordCtrl = TextEditingController();
  final _coAdminConfirmPasswordCtrl = TextEditingController();
  String? _selectedAssignedCanteen; // null => Full Super Admin; otherwise specific canteen
  bool _creatingCoAdmin = false;
  bool _obscureCoAdminPassword = true;
  late Stream<List<Map<String, dynamic>>> _allDeliveriesStream;

  @override
  void initState() {
    super.initState();
    _allDeliveriesStream = _service.streamAllDeliveries();
    _reportsRealtimeSub = _service.streamProblemReports().listen((_) {
      _loadReports(silent: true);
    });
    _loadAllAdminData();
  }

  @override
  void dispose() {
    _reportsRealtimeSub?.cancel();
    _reportSearchCtrl.dispose();
    _bufferCtrl.dispose();
    _dailyLimitCtrl.dispose();
    _expirationCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _coAdminNameCtrl.dispose();
    _coAdminEmailCtrl.dispose();
    _coAdminPhoneCtrl.dispose();
    _coAdminPasswordCtrl.dispose();
    _coAdminConfirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAllAdminData() async {
    await Future.wait([
      _loadProfiles(),
      _loadReports(),
      _loadConfigsAndLocations(),
    ]);
  }

  Future<void> _loadProfiles() async {
    if (!mounted) return;
    setState(() => _loadingUsers = true);
    try {
      final list = await _service.fetchAllProfiles();
      if (mounted) {
        setState(() {
          _profiles = list;
          _loadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingUsers = false);
        _showAdminError('Failed to load profiles: $e');
      }
    }
  }

  Future<void> _loadReports({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => _loadingReports = true);
    try {
      final list = await _service.fetchProblemReports();
      if (mounted) {
        setState(() {
          _reports = list;
          _loadingReports = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingReports = false);
        _showAdminError('Failed to load problem reports: $e');
      }
    }
  }

  Future<void> _loadConfigsAndLocations() async {
    if (!mounted) return;
    setState(() => _loadingConfig = true);
    try {
      final config = await _service.fetchSystemConfig();
      final locs = await _service.fetchAllLocations();
      if (mounted) {
        _bufferCtrl.text = config.preClassBufferMinutes.toString();
        _dailyLimitCtrl.text = config.dailyDeliveryLimit.toString();
        _expirationCtrl.text = config.requestExpirationMinutes.toString();
        _deliveryFeeCtrl.text = config.standardDeliveryFee.toStringAsFixed(2);
        setState(() {
          _locations = locs;
          _loadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingConfig = false);
        _showAdminError('Failed to load system settings: $e');
      }
    }
  }

  void _showAdminError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.redAccent, content: Text(message)),
    );
  }

  Future<void> _handleSignOut() async {
    await _service.signOut();
    DutyLockService.reset();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: DDartTheme.scaffoldBg(context),
        appBar: AppBar(
          backgroundColor: DDartTheme.primaryMaroon,
          foregroundColor: Colors.white,
          title: const Text(
            'D-DART Admin Console',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          actions: [
            const ThemeToggleButton(iconColor: Colors.white, iconSize: 21),
            IconButton(
              tooltip: 'Switch / Mode Preview',
              icon: const Icon(Icons.dashboard_customize_outlined),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MainDashboard()),
                );
              },
            ),
            IconButton(
              tooltip: 'Refresh All',
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllAdminData,
            ),
            IconButton(
              tooltip: 'Sign Out',
              icon: const Icon(Icons.logout),
              onPressed: _handleSignOut,
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: DDartTheme.gold,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.verified_user_outlined, size: 18), text: 'Accounts'),
              Tab(icon: Icon(Icons.admin_panel_settings_outlined, size: 18), text: 'Admins'),
              Tab(icon: Icon(Icons.restaurant_menu_outlined, size: 18), text: 'Menu'),
              Tab(icon: Icon(Icons.local_shipping_outlined, size: 18), text: 'Monitor'),
              Tab(icon: Icon(Icons.report_problem_outlined, size: 18), text: 'Reports'),
              Tab(icon: Icon(Icons.tune_outlined, size: 18), text: 'Settings & Locations'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: TabBarView(
              children: [
                _buildAccountsTab(),
                _buildCoAdminsTab(),
                const CanteenMenuManagerBody(),
                _buildMonitorTab(),
                _buildReportsTab(),
                _buildSettingsAndLocationsTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: ACCOUNT & DOCUMENT VERIFICATION (WBS 7.4)
  // ==========================================

  Widget _buildAccountsTab() {
    final nonAdminProfiles = _profiles.where((p) => !p.isAdmin).toList();
    final filtered = nonAdminProfiles.where((p) {
      if (_userFilter == 'all') return true;
      if (_userFilter == 'verified') return p.isVerified;
      return p.verificationStatus == _userFilter;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: ['pending', 'verified', 'rejected', 'all'].map((filter) {
              final count = filter == 'all'
                  ? nonAdminProfiles.length
                  : filter == 'verified'
                      ? nonAdminProfiles.where((p) => p.isVerified).length
                      : nonAdminProfiles.where((p) => p.verificationStatus == filter).length;
              return ChoiceChip(
                label: Text('${filter.toUpperCase()} ($count)'),
                selected: _userFilter == filter,
                selectedColor: DDartTheme.primaryMaroon.withValues(alpha: 0.16),
                onSelected: (_) => setState(() => _userFilter = filter),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: _loadingUsers
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No $_userFilter accounts found.',
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadProfiles,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) =>
                            _buildProfileReviewCard(filtered[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildProfileReviewCard(UserProfile user) {
    final statusColor = user.isVerified
        ? Colors.green
        : user.isRejected
            ? Colors.red
            : Colors.orange.shade800;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    user.fullName.isEmpty ? user.email : user.fullName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user.verificationLabel.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${user.accountTypeLabel}  •  ID: ${user.studentId.isEmpty ? '-' : user.studentId}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
            Text(
              '${user.email}  •  ${user.phoneNumber}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            if (user.isStudent)
              Text(
                'COR Verified: ${user.corVerified ? 'Yes' : 'No'}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _inspectUserDocsAndSchedule(user),
                  icon: const Icon(Icons.folder_shared_outlined, size: 16),
                  label: const Text('Inspect Docs & Schedule'),
                ),
                if (!user.isVerified)
                  ElevatedButton.icon(
                    onPressed: () => _approveUser(user),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Verify'),
                  ),
                if (!user.isRejected)
                  OutlinedButton.icon(
                    onPressed: () => _rejectUser(user),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 2: DEDICATED CO-ADMIN MANAGEMENT
  // ==========================================

  Widget _buildCoAdminsTab() {
    final admins = _profiles.where((p) => p.isAdmin).toList();

    return RefreshIndicator(
      onRefresh: _loadProfiles,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_add_alt_1, color: DDartTheme.primaryMaroon),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Create Admin / Canteen Admin',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Provision either a Full Super Admin or a Canteen Admin locked strictly to one canteen\'s food menu.',
                    style: TextStyle(fontSize: 12, color: DDartTheme.textSecondary(context)),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedAssignedCanteen,
                    decoration: const InputDecoration(
                      labelText: 'Admin Tier / Assigned Canteen',
                      prefixIcon: Icon(Icons.storefront_outlined, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Full Super Admin (All Console Access)'),
                      ),
                      ...CampusLocation.officialCanteens.map(
                        (canteen) => DropdownMenuItem<String?>(
                          value: canteen,
                          child: Text('Canteen Admin — $canteen'),
                        ),
                      ),
                    ],
                    onChanged: (val) => setState(() => _selectedAssignedCanteen = val),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _coAdminNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _coAdminEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_outlined, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _coAdminPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number (optional)',
                      hintText: 'e.g. 09171234567',
                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _coAdminPasswordCtrl,
                    obscureText: _obscureCoAdminPassword,
                    decoration: InputDecoration(
                      labelText: 'Temporary Password (min 6 chars)',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCoAdminPassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        onPressed: () => setState(
                          () => _obscureCoAdminPassword = !_obscureCoAdminPassword,
                        ),
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _coAdminConfirmPasswordCtrl,
                    obscureText: _obscureCoAdminPassword,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: Icon(Icons.lock_outline, size: 18),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creatingCoAdmin ? null : _handleCreateCoAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DDartTheme.primaryMaroon,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _creatingCoAdmin
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.admin_panel_settings, size: 18),
                      label: Text(
                        _creatingCoAdmin
                            ? 'Creating Account...'
                            : _selectedAssignedCanteen != null
                                ? 'Create $_selectedAssignedCanteen Admin'
                                : 'Create Full Super Admin',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: DDartTheme.primaryMaroon),
              const SizedBox(width: 6),
              Text(
                'Active Administrators (${admins.length})',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loadingUsers)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            )
          else if (admins.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No administrator accounts found.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          else
            ...admins.map(_buildCoAdminCard),
        ],
      ),
    );
  }

  Widget _buildCoAdminCard(UserProfile admin) {
    final isCurrentAdminUser = admin.id == _service.currentUser?.id;
    final isCanteenScoped = admin.isCanteenAdmin;
    final badgeLabel = isCurrentAdminUser
        ? 'SUPER ADMIN (YOU)'
        : isCanteenScoped
            ? 'CANTEEN • ${admin.assignedCanteen!.toUpperCase()}'
            : 'SUPER ADMIN';
    final badgeBg = isCanteenScoped
        ? DDartTheme.primaryMaroon.withValues(alpha: 0.14)
        : const Color(0xFFD4AF37).withValues(alpha: 0.2);
    final badgeFg = isCanteenScoped
        ? DDartTheme.accentText(context)
        : const Color(0xFF9C7B12);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: DDartTheme.primaryMaroon.withValues(alpha: 0.12),
              child: Icon(
                isCanteenScoped ? Icons.storefront : Icons.admin_panel_settings,
                color: DDartTheme.accentText(context),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(
                        admin.fullName.isEmpty ? admin.email : admin.fullName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeFg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    admin.phoneNumber.isNotEmpty
                        ? '${admin.email}  •  ${admin.phoneNumber}'
                        : admin.email,
                    style: TextStyle(fontSize: 12, color: DDartTheme.textSecondary(context)),
                  ),
                ],
              ),
            ),
            if (!isCurrentAdminUser) ...[
              IconButton(
                tooltip: 'Change Assigned Canteen',
                icon: Icon(Icons.edit_outlined, size: 19, color: DDartTheme.accentText(context)),
                onPressed: () => _showReassignCanteenDialog(admin),
              ),
              IconButton(
                tooltip: 'Delete Admin Account',
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDeleteCoAdmin(admin),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showReassignCanteenDialog(UserProfile admin) async {
    String? chosen = admin.assignedCanteen;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Assign Role • ${admin.firstName}'),
          content: DropdownButtonFormField<String?>(
            initialValue: chosen,
            decoration: const InputDecoration(
              labelText: 'Admin Tier / Assigned Canteen',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Full Super Admin (All Access)'),
              ),
              ...CampusLocation.officialCanteens.map(
                (canteen) => DropdownMenuItem<String?>(
                  value: canteen,
                  child: Text('Canteen Admin — $canteen'),
                ),
              ),
            ],
            onChanged: (v) => setDialogState(() => chosen = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DDartTheme.primaryMaroon,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (save != true) return;
    try {
      await _service.updateAdminCanteenScope(admin.id, chosen);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              chosen == null
                  ? '${admin.fullName} is now a Full Super Admin.'
                  : '${admin.fullName} is now assigned to $chosen.',
            ),
          ),
        );
        await _loadProfiles();
      }
    } catch (e) {
      if (mounted) _showAdminError('Failed to update admin scope: $e');
    }
  }

  Future<void> _handleCreateCoAdmin() async {
    final fullName = _coAdminNameCtrl.text.trim();
    final email = _coAdminEmailCtrl.text.trim();
    final phone = _coAdminPhoneCtrl.text.trim();
    final password = _coAdminPasswordCtrl.text;
    final confirmPassword = _coAdminConfirmPasswordCtrl.text;
    final assignedCanteen = _selectedAssignedCanteen;

    final validationError = Validators.validateFullName(fullName) ??
        Validators.validateEmail(email) ??
        (phone.isNotEmpty ? Validators.validatePhoneNumber(phone) : null) ??
        Validators.validatePassword(password) ??
        Validators.validateConfirmPassword(confirmPassword, password);

    if (validationError != null) {
      _showAdminError(validationError);
      return;
    }

    setState(() => _creatingCoAdmin = true);
    try {
      await _service.createCoAdminAccount(
        fullName: fullName,
        email: email,
        password: password,
        phoneNumber: phone,
        assignedCanteen: assignedCanteen,
      );
      _coAdminNameCtrl.clear();
      _coAdminEmailCtrl.clear();
      _coAdminPhoneCtrl.clear();
      _coAdminPasswordCtrl.clear();
      _coAdminConfirmPasswordCtrl.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text(
              assignedCanteen != null
                  ? '$assignedCanteen Admin created for $fullName ($email).'
                  : 'Super Admin account created for $fullName ($email).',
            ),
          ),
        );
        await _loadProfiles();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        _showAdminError('Could not create admin: $msg');
      }
    } finally {
      if (mounted) setState(() => _creatingCoAdmin = false);
    }
  }

  Future<void> _confirmDeleteCoAdmin(UserProfile admin) async {
    final displayName = admin.fullName.isEmpty ? admin.email : admin.fullName;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Delete Co-Admin?'),
          ],
        ),
        content: Text(
          'Permanently delete the co-administrator account for $displayName (${admin.email})?\n\n'
          'They will immediately lose access to the D-DART Admin Console.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Co-Admin'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _service.deleteCoAdminAccount(admin.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted co-admin account for $displayName.'),
          ),
        );
        await _loadProfiles();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        _showAdminError('Failed to delete co-admin: $msg');
      }
    }
  }

  Future<void> _inspectUserDocsAndSchedule(UserProfile user) async {
    final idUrl = user.idDocumentPath != null
        ? await _service.getSignedDocumentUrl(user.idDocumentPath!)
        : null;
    final corUrl = user.corDocumentPath != null
        ? await _service.getSignedDocumentUrl(user.corDocumentPath!)
        : null;
    final List<ClassSession> schedule =
        user.isStudent ? await _service.fetchClassSchedule(user.id) : [];

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.fullName.isEmpty ? user.email : user.fullName),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440, maxHeight: 500),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Uploaded ID Document', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (idUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      idUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Text('Could not load ID preview.'),
                    ),
                  )
                else
                  const Text('No ID image stored.', style: TextStyle(color: Colors.black54)),
                if (user.isStudent) ...[
                  const SizedBox(height: 14),
                  const Text('Uploaded COR / Study Load', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  if (corUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        corUrl,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Text('Could not load COR preview.'),
                      ),
                    )
                  else
                    const Text('No COR image stored.', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 14),
                  Text(
                    'Extracted Schedule (${schedule.length} sessions)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  if (schedule.isEmpty)
                    const Text('No schedule saved.', style: TextStyle(color: Colors.black54))
                  else
                    ...schedule.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• ${s.day} ${s.startTime}-${s.endTime}: ${s.subject}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _approveUser(UserProfile user) async {
    try {
      await _service.updateUserVerification(user.id, status: 'verified');
      await _loadProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.fullName} verified.')),
        );
      }
    } catch (e) {
      if (mounted) _showAdminError('Failed to approve user: $e');
    }
  }

  Future<void> _rejectUser(UserProfile user) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${user.fullName}?'),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason (optional)',
            hintText: 'e.g., ID photo blurry or mismatched student ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();
    if (confirmed != true) return;

    try {
      await _service.updateUserVerification(
        user.id,
        status: 'rejected',
        rejectionReason: reason,
      );
      await _loadProfiles();
    } catch (e) {
      if (mounted) _showAdminError('Failed to reject user: $e');
    }
  }

  // ==========================================
  // TAB 2: DELIVERY ACTIVITY MONITORING (WBS 7.6)
  // ==========================================

  Widget _buildMonitorTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _allDeliveriesStream,
      builder: (context, snapshot) {
        final allOrders = (snapshot.data ?? []).map(DeliveryOrder.fromJson).toList();
        final activeCount = allOrders
            .where((o) =>
                !const ['completed', 'cancelled', 'expired'].contains(o.effectiveStatus()))
            .length;
        final completedCount =
            allOrders.where((o) => o.effectiveStatus() == 'completed').length;

        final filtered = allOrders.where((o) {
          final status = o.effectiveStatus();
          if (_monitorFilter == 'active') {
            return !const ['completed', 'cancelled', 'expired'].contains(status);
          }
          if (_monitorFilter == 'completed') return status == 'completed';
          if (_monitorFilter == 'closed') {
            return status == 'cancelled' || status == 'expired';
          }
          return true;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _metricChip('Total', allOrders.length.toString(), DDartTheme.textPrimary(context)),
                  _metricChip('Active', activeCount.toString(), DDartTheme.accentText(context)),
                  _metricChip('Completed', completedCount.toString(), Colors.green),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: ['all', 'active', 'completed', 'closed'].map((f) {
                  return ChoiceChip(
                    label: Text(f.toUpperCase()),
                    selected: _monitorFilter == f,
                    onSelected: (_) => setState(() => _monitorFilter = f),
                  );
                }).toList(),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No delivery activity matching filter.',
                          style: TextStyle(color: Colors.black54)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final o = filtered[index];
                        final status = o.effectiveStatus();
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text(
                              o.description,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${o.pickupLocation} → ${o.dropoffLocation}\nStatus: ${status.toUpperCase()}  •  Fee: ₱${o.deliveryFee.toStringAsFixed(2)}',
                            ),
                            isThreeLine: true,
                            trailing: const Icon(Icons.history),
                            onTap: () => _showOrderStatusLogs(o),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _metricChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color),
      ),
    );
  }

  Future<void> _showOrderStatusLogs(DeliveryOrder order) async {
    List<Map<String, dynamic>> logs = [];
    try {
      logs = await _service.fetchStatusLogs(order.id);
    } catch (_) {}

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delivery Timeline (${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length)})'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420, maxHeight: 380),
          child: logs.isEmpty
              ? const Text('No status log entries yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.circle, size: 10, color: DDartTheme.primaryMaroon),
                      title: Text((log['status'] ?? '').toString().toUpperCase()),
                      subtitle: Text('${log['remarks'] ?? ''}\n${log['created_at'] ?? ''}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: REPORTED PROBLEM REVIEW (WBS 7.6)
  // ==========================================

  Widget _buildReportsTab() {
    if (_loadingReports) {
      return const Center(child: CircularProgressIndicator(color: DDartTheme.primaryMaroon));
    }

    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);

    // Summary counts
    final totalCount = _reports.length;
    final openCount = _reports.where((r) => r.status == 'open').length;
    final reviewingCount = _reports.where((r) => r.status == 'reviewing').length;
    final customerCount = _reports.where((r) => r.isCustomerReport).length;
    final runnerCount = _reports.where((r) => r.isRunnerReport).length;
    final resolvedCount =
        _reports.where((r) => r.status == 'resolved' || r.status == 'dismissed').length;

    // Filter logic
    final query = _reportSearchCtrl.text.trim().toLowerCase();
    final filtered = _reports.where((r) {
      if (_reportRoleFilter == 'customer' && !r.isCustomerReport) return false;
      if (_reportRoleFilter == 'runner' && !r.isRunnerReport) return false;
      if (_reportStatusFilter != 'all' && r.status != _reportStatusFilter) return false;

      if (query.isNotEmpty) {
        final matches = (r.reporterName?.toLowerCase().contains(query) ?? false) ||
            (r.reporterEmail?.toLowerCase().contains(query) ?? false) ||
            (r.reporterStudentId?.toLowerCase().contains(query) ?? false) ||
            (r.reportedUserName?.toLowerCase().contains(query) ?? false) ||
            (r.reportedUserEmail?.toLowerCase().contains(query) ?? false) ||
            (r.requestId?.toLowerCase().contains(query) ?? false) ||
            r.categoryLabel.toLowerCase().contains(query) ||
            r.description.toLowerCase().contains(query) ||
            r.adminNotes.toLowerCase().contains(query) ||
            (r.orderPickupLocation?.toLowerCase().contains(query) ?? false) ||
            (r.orderDropoffLocation?.toLowerCase().contains(query) ?? false);
        if (!matches) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => _loadReports(),
      color: DDartTheme.primaryMaroon,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header title & Full Super Admin Live Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispute & Problem Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Customer & Runner issues (Full Super Admin Console)',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade400, width: 0.9),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: Colors.green),
                    SizedBox(width: 4),
                    Text(
                      'LIVE SYNC',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Metric Stat Cards Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildReportStatCard(
                  title: 'Total Reports',
                  count: totalCount,
                  icon: Icons.assignment_outlined,
                  color: Colors.blueGrey,
                  isSelected: _reportRoleFilter == 'all' && _reportStatusFilter == 'all',
                  onTap: () {
                    setState(() {
                      _reportRoleFilter = 'all';
                      _reportStatusFilter = 'all';
                    });
                  },
                ),
                const SizedBox(width: 8),
                _buildReportStatCard(
                  title: 'Open Issues',
                  count: openCount,
                  icon: Icons.error_outline,
                  color: Colors.redAccent,
                  isSelected: _reportStatusFilter == 'open',
                  onTap: () {
                    setState(() => _reportStatusFilter = 'open');
                  },
                ),
                const SizedBox(width: 8),
                _buildReportStatCard(
                  title: 'Under Review',
                  count: reviewingCount,
                  icon: Icons.hourglass_top,
                  color: Colors.orange,
                  isSelected: _reportStatusFilter == 'reviewing',
                  onTap: () {
                    setState(() => _reportStatusFilter = 'reviewing');
                  },
                ),
                const SizedBox(width: 8),
                _buildReportStatCard(
                  title: 'Customer Reports',
                  count: customerCount,
                  icon: Icons.person_outline,
                  color: Colors.blue,
                  isSelected: _reportRoleFilter == 'customer',
                  onTap: () {
                    setState(() => _reportRoleFilter = 'customer');
                  },
                ),
                const SizedBox(width: 8),
                _buildReportStatCard(
                  title: 'Runner Reports',
                  count: runnerCount,
                  icon: Icons.directions_run_outlined,
                  color: Colors.amber.shade800,
                  isSelected: _reportRoleFilter == 'runner',
                  onTap: () {
                    setState(() => _reportRoleFilter = 'runner');
                  },
                ),
                const SizedBox(width: 8),
                _buildReportStatCard(
                  title: 'Resolved / Closed',
                  count: resolvedCount,
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  isSelected: _reportStatusFilter == 'resolved',
                  onTap: () {
                    setState(() => _reportStatusFilter = 'resolved');
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search Field
          TextField(
            controller: _reportSearchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by reporter, order ID, conduct issue, or keyword...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _reportSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _reportSearchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              filled: true,
              fillColor: DDartTheme.cardSubtle(context),
            ),
          ),
          const SizedBox(height: 12),

          // Role Filter Chips
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: Text('All ($totalCount)'),
                selected: _reportRoleFilter == 'all',
                onSelected: (val) {
                  if (val) setState(() => _reportRoleFilter = 'all');
                },
              ),
              ChoiceChip(
                avatar: const Icon(Icons.person, size: 16, color: Colors.blue),
                label: Text('Customer Reports ($customerCount)'),
                selected: _reportRoleFilter == 'customer',
                selectedColor: Colors.blue.withValues(alpha: 0.22),
                onSelected: (val) {
                  if (val) setState(() => _reportRoleFilter = 'customer');
                },
              ),
              ChoiceChip(
                avatar: Icon(Icons.directions_run, size: 16, color: Colors.amber.shade900),
                label: Text('Runner Reports ($runnerCount)'),
                selected: _reportRoleFilter == 'runner',
                selectedColor: Colors.amber.withValues(alpha: 0.22),
                onSelected: (val) {
                  if (val) setState(() => _reportRoleFilter = 'runner');
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Status Filter Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              FilterChip(
                label: const Text('All Statuses'),
                selected: _reportStatusFilter == 'all',
                onSelected: (val) {
                  if (val) setState(() => _reportStatusFilter = 'all');
                },
              ),
              FilterChip(
                label: Text('Open ($openCount)'),
                selected: _reportStatusFilter == 'open',
                selectedColor: Colors.red.withValues(alpha: 0.18),
                onSelected: (val) => setState(() => _reportStatusFilter = val ? 'open' : 'all'),
              ),
              FilterChip(
                label: Text('Reviewing ($reviewingCount)'),
                selected: _reportStatusFilter == 'reviewing',
                selectedColor: Colors.orange.withValues(alpha: 0.18),
                onSelected: (val) =>
                    setState(() => _reportStatusFilter = val ? 'reviewing' : 'all'),
              ),
              FilterChip(
                label: Text('Resolved (${_reports.where((r) => r.status == 'resolved').length})'),
                selected: _reportStatusFilter == 'resolved',
                selectedColor: Colors.green.withValues(alpha: 0.18),
                onSelected: (val) =>
                    setState(() => _reportStatusFilter = val ? 'resolved' : 'all'),
              ),
              FilterChip(
                label: Text('Dismissed (${_reports.where((r) => r.status == 'dismissed').length})'),
                selected: _reportStatusFilter == 'dismissed',
                onSelected: (val) =>
                    setState(() => _reportStatusFilter = val ? 'dismissed' : 'all'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reports List or Empty State
          if (filtered.isEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 54, color: textSecondary.withValues(alpha: 0.45)),
                  const SizedBox(height: 12),
                  Text(
                    _reports.isEmpty
                        ? 'No problem reports submitted yet.'
                        : 'No reports match your filters.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _reports.isEmpty
                        ? 'Reports filed by customers or runners will appear here.'
                        : 'Try adjusting your search keywords or filter options.',
                    style: TextStyle(fontSize: 12, color: textSecondary.withValues(alpha: 0.8)),
                  ),
                  if (_reports.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reset Filters'),
                      onPressed: () {
                        setState(() {
                          _reportRoleFilter = 'all';
                          _reportStatusFilter = 'all';
                          _reportSearchCtrl.clear();
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ] else ...[
            Text(
              'Showing ${filtered.length} of $totalCount reports',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
            ),
            const SizedBox(height: 8),
            ...filtered.map((report) => _buildReportDetailCard(report)),
          ],
        ],
      ),
    );
  }

  Widget _buildReportStatCard({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = DDartTheme.isDark(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.25 : 0.15)
              : DDartTheme.card(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : DDartTheme.outlineBorder(context),
            width: isSelected ? 1.8 : 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color.withValues(alpha: 0.16),
              child: Icon(icon, size: 15, color: color),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? color : DDartTheme.textPrimary(context),
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: DDartTheme.textSecondary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportDetailCard(ProblemReport report) {
    final isDark = DDartTheme.isDark(context);
    final textPrimary = DDartTheme.textPrimary(context);
    final textSecondary = DDartTheme.textSecondary(context);

    // Status colors
    Color statusBg;
    Color statusFg;
    switch (report.status.toLowerCase()) {
      case 'open':
        statusBg = Colors.red.withValues(alpha: 0.14);
        statusFg = Colors.red.shade700;
        break;
      case 'reviewing':
        statusBg = Colors.orange.withValues(alpha: 0.16);
        statusFg = Colors.orange.shade800;
        break;
      case 'resolved':
        statusBg = Colors.green.withValues(alpha: 0.14);
        statusFg = Colors.green.shade700;
        break;
      case 'dismissed':
      default:
        statusBg = Colors.grey.withValues(alpha: 0.18);
        statusFg = Colors.grey.shade700;
        break;
    }

    final isCustomer = report.isCustomerReport;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: DDartTheme.card(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: report.status == 'open'
              ? Colors.red.shade300
              : DDartTheme.outlineBorder(context),
          width: report.status == 'open' ? 1.4 : 0.9,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Role Badge + Category + Status Chip
            Row(
              children: [
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isCustomer
                        ? Colors.blue.withValues(alpha: 0.14)
                        : Colors.amber.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCustomer ? Icons.person : Icons.directions_run,
                        size: 13,
                        color: isCustomer ? Colors.blue.shade700 : Colors.amber.shade900,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCustomer ? 'CUSTOMER REPORT' : 'RUNNER REPORT',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isCustomer ? Colors.blue.shade700 : Colors.amber.shade900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Category pill
                Expanded(
                  child: Text(
                    report.categoryLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                ),

                // Status chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    report.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: statusFg,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Time & Date
            Text(
              _formatReportDate(report.createdAt),
              style: TextStyle(fontSize: 11.5, color: textSecondary),
            ),
            const Divider(height: 16),

            // Reporter details section
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DDartTheme.cardSubtle(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isCustomer
                        ? Colors.blue.withValues(alpha: 0.18)
                        : Colors.amber.withValues(alpha: 0.22),
                    child: Icon(
                      isCustomer ? Icons.person_outline : Icons.directions_run,
                      size: 18,
                      color: isCustomer ? Colors.blue.shade800 : Colors.amber.shade900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                report.reporterName ?? 'Unknown Reporter',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            if (report.reporterStudentId != null &&
                                report.reporterStudentId!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'ID: ${report.reporterStudentId}',
                                  style: TextStyle(fontSize: 10.5, color: textSecondary),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${report.reporterEmail ?? 'No email'} ${report.reporterPhone != null ? '• ${report.reporterPhone}' : ''}',
                          style: TextStyle(fontSize: 11.5, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Reported Party (if applicable)
            if (report.hasReportedUser) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.redAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Report Filed Against: ${report.reportedUserName} (${(report.reportedUserRole ?? 'User').toUpperCase()})',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.red.shade200 : Colors.red.shade900,
                            ),
                          ),
                          if (report.reportedUserEmail != null)
                            Text(
                              report.reportedUserEmail!,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.red.shade300 : Colors.red.shade700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Associated Order Details Box (if linked to order)
            if (report.hasOrder) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: DDartTheme.primaryMaroon.withValues(alpha: isDark ? 0.18 : 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: DDartTheme.primaryMaroon.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 15, color: DDartTheme.primaryMaroon),
                        const SizedBox(width: 6),
                        Text(
                          'Order ID: ${report.requestId!.length > 8 ? report.requestId!.substring(0, 8) : report.requestId}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: DDartTheme.primaryMaroon,
                          ),
                        ),
                        const Spacer(),
                        if (report.orderStatus != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: DDartTheme.primaryMaroon.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              report.orderStatus!.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: DDartTheme.primaryMaroon,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Route: ${report.orderPickupLocation ?? 'Canteen'} ➔ ${report.orderDropoffLocation ?? 'Campus Drop-off'}',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                    if (report.orderDescription != null &&
                        report.orderDescription!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Items: ${report.orderDescription}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: textSecondary),
                      ),
                    ],
                    if (report.orderEstimatedPrice != null || report.orderDeliveryFee != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Total: ₱${(report.orderEstimatedPrice ?? 0).toStringAsFixed(2)} + ₱${(report.orderDeliveryFee ?? 20).toStringAsFixed(2)} delivery fee',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 10),

            // Problem Description Box
            Text(
              'Reported Issue Details:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: DDartTheme.cardSubtle(context),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(
                    color: isCustomer ? Colors.blue.shade600 : Colors.amber.shade700,
                    width: 3.5,
                  ),
                ),
              ),
              child: Text(
                report.description,
                style: TextStyle(fontSize: 12.5, height: 1.35, color: textPrimary),
              ),
            ),

            // Admin Notes / Resolution (if already provided)
            if (report.adminNotes.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.admin_panel_settings, size: 14, color: Colors.green),
                        const SizedBox(width: 5),
                        Text(
                          'Admin Resolution Notes:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                          ),
                        ),
                        if (report.reviewerName != null) ...[
                          const Spacer(),
                          Text(
                            'By: ${report.reviewerName}',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      report.adminNotes,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.green.shade100 : Colors.green.shade900,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Actions Row
            Row(
              children: [
                // Delete button
                IconButton(
                  tooltip: 'Delete Report',
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                  onPressed: () => _confirmDeleteReport(report),
                ),

                const Spacer(),

                // Update Status & Review Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DDartTheme.primaryMaroon,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text(
                    'Review & Update Status',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _reviewProblemReport(report),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatReportDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[local.month - 1];
    final day = local.day;
    final year = local.year;
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final min = local.minute.toString().padLeft(2, '0');
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, $year • $hour:$min $ampm';
  }

  Future<void> _confirmDeleteReport(ProblemReport report) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text(
          'Are you sure you want to permanently delete this ${report.isCustomerReport ? 'Customer' : 'Runner'} report (${report.categoryLabel})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _service.deleteProblemReport(report.id);
        await _loadReports();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report deleted successfully.')),
          );
        }
      } catch (e) {
        if (mounted) _showAdminError('Failed to delete report: $e');
      }
    }
  }

  Future<void> _reviewProblemReport(ProblemReport report) async {
    String selectedStatus = report.status;
    final notesCtrl = TextEditingController(text: report.adminNotes);

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(
                report.isCustomerReport ? Icons.person : Icons.directions_run,
                color: DDartTheme.primaryMaroon,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Review ${report.isCustomerReport ? 'Customer' : 'Runner'} Report',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category: ${report.categoryLabel}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                if (report.reporterName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Reporter: ${report.reporterName} (${report.reporterRole})',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Resolution Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ProblemReport.statuses
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase())))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedStatus = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Admin Resolution / Internal Notes',
                    hintText: 'Enter resolution details, corrective actions, or refund remarks...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DDartTheme.primaryMaroon,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save Resolution'),
            ),
          ],
        ),
      ),
    );
    final notes = notesCtrl.text.trim();
    notesCtrl.dispose();
    if (save != true) return;

    try {
      await _service.updateProblemReportStatus(
        report.id,
        status: selectedStatus,
        adminNotes: notes,
      );
      await _loadReports();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            content: Text('Report marked as ${selectedStatus.toUpperCase()}.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showAdminError('Failed to update report: $e');
    }
  }

  // ==========================================
  // TAB 4: SYSTEM PARAMETERS & CAMPUS LOCATIONS (WBS 7.5)
  // ==========================================

  Widget _buildSettingsAndLocationsTab() {
    if (_loadingConfig) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'System Parameters',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _bufferCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Pre-Class Buffer (minutes)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dailyLimitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Daily Runner Delivery Limit',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _expirationCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Unclaimed Request Expiration (minutes)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _deliveryFeeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Standard Delivery Fee (₱)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveConfigs,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DDartTheme.primaryMaroon,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save System Parameters'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Campus Location Directory',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _showAddLocationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: DDartTheme.primaryMaroon,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.add_location_alt_outlined, size: 18),
              label: const Text('Add Location'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._locations.map(
          (loc) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: SwitchListTile(
              title: Text(loc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${loc.category.toUpperCase()}${loc.buildingCode.isNotEmpty ? ' · ${loc.buildingCode}' : ''}',
              ),
              value: loc.isActive,
              activeThumbColor: DDartTheme.primaryMaroon,
              onChanged: (val) async {
                try {
                  await _service.toggleLocationActive(loc.id, val);
                  await _loadConfigsAndLocations();
                } catch (e) {
                  if (mounted) _showAdminError('Failed to update location: $e');
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveConfigs() async {
    final buffer = int.tryParse(_bufferCtrl.text.trim());
    final dailyLimit = int.tryParse(_dailyLimitCtrl.text.trim());
    final expiration = int.tryParse(_expirationCtrl.text.trim());
    final fee = double.tryParse(_deliveryFeeCtrl.text.trim());

    if (buffer == null ||
        buffer < 0 ||
        dailyLimit == null ||
        dailyLimit < 1 ||
        expiration == null ||
        expiration < 1 ||
        fee == null ||
        fee < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Please enter valid positive numbers for all parameters.'),
        ),
      );
      return;
    }

    try {
      await _service.updateSystemConfig('pre_class_buffer_minutes', buffer.toString());
      await _service.updateSystemConfig('daily_delivery_limit', dailyLimit.toString());
      await _service.updateSystemConfig('request_expiration_minutes', expiration.toString());
      await _service.updateSystemConfig('standard_delivery_fee', fee.toStringAsFixed(2));
      await _service.updateSystemConfig('delivery_fee_short', fee.toStringAsFixed(2));
      await _service.updateSystemConfig('delivery_fee_medium', (fee + 5.0).toStringAsFixed(2));
      await _service.updateSystemConfig('delivery_fee_long', (fee + 10.0).toStringAsFixed(2));
      await DutyLockService.syncFromSupabase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green,
            content: Text('System parameters updated!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showAdminError('Failed to save system parameters: $e');
    }
  }

  Future<void> _showAddLocationDialog() async {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String category = 'pickup';

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Campus Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Location Name',
                  hintText: 'e.g. Engineering Building',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'pickup', child: Text('Pickup Location')),
                  DropdownMenuItem(value: 'dropoff', child: Text('Drop-off Destination')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => category = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Building Code (optional)',
                  hintText: 'e.g. ENG',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    final name = nameCtrl.text.trim();
    final code = codeCtrl.text.trim();
    nameCtrl.dispose();
    codeCtrl.dispose();

    if (save == true && name.isNotEmpty) {
      try {
        await _service.upsertLocation(
          name: name,
          category: category,
          buildingCode: code,
        );
        await _loadConfigsAndLocations();
      } catch (e) {
        if (mounted) _showAdminError('Failed to add location: $e');
      }
    }
  }
}
