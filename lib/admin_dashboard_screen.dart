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
    _loadAllAdminData();
  }

  @override
  void dispose() {
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

  Future<void> _loadReports() async {
    if (!mounted) return;
    setState(() => _loadingReports = true);
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
      return const Center(child: CircularProgressIndicator());
    }
    if (_reports.isEmpty) {
      return const Center(
        child: Text('No reported problems yet.', style: TextStyle(color: Colors.black54)),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _reports.length,
        itemBuilder: (context, index) {
          final report = _reports[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        report.categoryLabel,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Chip(
                        label: Text(
                          report.status.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(report.description),
                  if (report.requestId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Order ID: ${report.requestId}',
                        style: const TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  if (report.adminNotes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Admin Notes: ${report.adminNotes}',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DDartTheme.primaryMaroon,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _reviewProblemReport(report),
                      child: const Text('Update Review Status'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _reviewProblemReport(ProblemReport report) async {
    String selectedStatus = report.status;
    final notesCtrl = TextEditingController(text: report.adminNotes);

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Review: ${report.categoryLabel}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
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
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Resolution / Admin Notes',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
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
