class Validators {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$',
  );
  static final RegExp _phoneRegex = RegExp(r'^(?:\+63|0)9\d{9}$');
  static final RegExp _studentIdRegex = RegExp(r'^\d{2}-\d{4}-\d{3}$');
  static final RegExp _facultyIdRegex = RegExp(
    r'^(?:EMP|FAC)-\d{3,6}$|^\d{2}-\d{4}-\d{3}$',
    caseSensitive: false,
  );

  static String? validateFullName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Full name is required.';
    if (trimmed.length < 2) return 'Enter your full name.';
    return null;
  }

  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email address is required.';
    if (!_emailRegex.hasMatch(trimmed)) return 'Enter a valid email address.';
    return null;
  }

  static String? validatePhoneNumber(String? value) {
    final cleaned = (value ?? '').replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty) return 'Phone number is required.';
    if (!_phoneRegex.hasMatch(cleaned)) {
      return 'Use PH mobile format (e.g. 09171234567 or +639171234567).';
    }
    return null;
  }

  static String? validateIdNumber(String? value, String accountType) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return accountType == 'faculty_staff'
          ? 'Faculty / Employee ID is required.'
          : 'Student ID is required.';
    }
    if (accountType == 'faculty_staff') {
      if (!_facultyIdRegex.hasMatch(trimmed)) {
        return 'Use format EMP-1024, FAC-1024, or XX-XXXX-XXX.';
      }
      return null;
    }
    if (!_studentIdRegex.hasMatch(trimmed)) {
      return 'Use Student ID format XX-XXXX-XXX (e.g. 23-1626-937).';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    final pwd = value ?? '';
    if (pwd.isEmpty) return 'Password is required.';
    if (pwd.length < 6) return 'Password must be at least 6 characters.';
    return null;
  }

  static String? validateConfirmPassword(String? value, String original) {
    if ((value ?? '').isEmpty) return 'Please confirm your password.';
    if (value != original) return 'Passwords do not match.';
    return null;
  }

  static String? validateEstimatedBudget(String? value) {
    final parsed = double.tryParse(value?.trim() ?? '');
    if (parsed == null || parsed <= 0) return 'Enter a valid amount greater than 0.';
    if (parsed > 10000) return 'Maximum Pabili budget per request is ₱10,000.';
    return null;
  }
}
