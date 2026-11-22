class UserProfile {
  final String id;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String studentId;
  final String role; // 'customer', 'runner', 'admin'
  final String accountType; // 'student', 'faculty_staff', 'admin'
  final String verificationStatus; // 'pending', 'verified', 'rejected'
  final bool corVerified;
  final String? idDocumentPath;
  final String? corDocumentPath;
  final String? rejectionReason;
  final String? assignedCanteen;

  const UserProfile({
    required this.id,
    required this.fullName,
    this.email = '',
    this.phoneNumber = '',
    this.studentId = '',
    this.role = 'customer',
    this.accountType = 'student',
    this.verificationStatus = 'pending',
    this.corVerified = false,
    this.idDocumentPath,
    this.corDocumentPath,
    this.rejectionReason,
    this.assignedCanteen,
  });

  bool get isStudent => accountType == 'student';
  bool get isFacultyOrStaff => accountType == 'faculty_staff';
  bool get isAdmin => accountType == 'admin' || role == 'admin';
  bool get isCanteenAdmin =>
      isAdmin && assignedCanteen != null && assignedCanteen!.trim().isNotEmpty;
  bool get isSuperAdmin => isAdmin && !isCanteenAdmin;
  bool get isVerified => verificationStatus == 'verified';
  bool get isPending => verificationStatus == 'pending';
  bool get isRejected => verificationStatus == 'rejected';

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Wildcat';
    return trimmed.split(' ').first;
  }

  /// Dedicated presentation exception: runner@gmail.com is authorized for demonstration.
  bool get isDemoRunner => email.toLowerCase().trim() == 'runner@gmail.com';

  /// Only verified student accounts with a verified COR schedule may operate in Runner Mode.
  /// Dedicated presentation exception: runner@gmail.com is authorized for demonstration.
  bool get canUseRunnerMode => (isStudent && isVerified && corVerified) || isDemoRunner;

  String get accountTypeLabel {
    if (isCanteenAdmin) {
      return 'Canteen Admin ($assignedCanteen)';
    }
    switch (accountType) {
      case 'faculty_staff':
        return 'Faculty / Staff';
      case 'admin':
        return 'Super Admin';
      default:
        return 'Student';
    }
  }

  String get verificationLabel {
    switch (verificationStatus) {
      case 'verified':
        return 'Verified';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawCanteen = json['assigned_canteen']?.toString().trim();
    return UserProfile(
      id: json['id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'customer',
      accountType: json['account_type']?.toString() ?? 'student',
      verificationStatus: json['verification_status']?.toString() ?? 'pending',
      corVerified: json['cor_verified'] == true,
      idDocumentPath: json['id_document_path']?.toString(),
      corDocumentPath: json['cor_document_path']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      assignedCanteen: (rawCanteen != null && rawCanteen.isNotEmpty) ? rawCanteen : null,
    );
  }
}
