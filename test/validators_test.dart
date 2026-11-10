import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/utils/validators.dart';

void main() {
  group('Validators', () {
    test('validates student and faculty ID formats', () {
      expect(Validators.validateIdNumber('23-1626-937', 'student'), isNull);
      expect(Validators.validateIdNumber('bad-id', 'student'), isNotNull);
      expect(Validators.validateIdNumber('', 'student'), isNotNull);

      expect(Validators.validateIdNumber('EMP-1024', 'faculty_staff'), isNull);
      expect(Validators.validateIdNumber('FAC-204', 'faculty_staff'), isNull);
      expect(Validators.validateIdNumber('99', 'faculty_staff'), isNotNull);
    });

    test('validates email, phone, password, and budget', () {
      expect(Validators.validateEmail('student@cit.edu'), isNull);
      expect(Validators.validateEmail('not-an-email'), isNotNull);

      expect(Validators.validatePhoneNumber('09171234567'), isNull);
      expect(Validators.validatePhoneNumber('+639171234567'), isNull);
      expect(Validators.validatePhoneNumber('12345'), isNotNull);

      expect(Validators.validatePassword('123456'), isNull);
      expect(Validators.validatePassword('123'), isNotNull);

      expect(Validators.validateEstimatedBudget('85.50'), isNull);
      expect(Validators.validateEstimatedBudget('0'), isNotNull);
      expect(Validators.validateEstimatedBudget('abc'), isNotNull);
    });
  });
}
