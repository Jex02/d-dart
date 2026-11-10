import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/services/gemini_service.dart';

void main() {
  group('GeminiService COR parser', () {
    test('parses valid fenced JSON schedule', () {
      const raw = '''
```json
{
  "is_valid": true,
  "rejection_reason": "",
  "student_name": "Juan Dela Cruz",
  "student_id": "23-1626-937",
  "sessions": [
    {
      "day": "Monday",
      "start_time": "09:00",
      "end_time": "12:00",
      "subject": "CS 321 - Software Dev 2"
    }
  ]
}
```
''';
      final result = GeminiService.parseGeminiResponseJson(
        raw,
        expectedStudentId: '23-1626-937',
      );
      expect(result.isValid, isTrue);
      expect(result.sessions.length, 1);
      expect(result.sessions.first.day, 'Monday');
      expect(result.sessions.first.subject, 'CS 321 - Software Dev 2');
    });

    test('rejects unrelated document', () {
      const raw = '''
{
  "is_valid": false,
  "rejection_reason": "Image appears to be food, not a CIT-U COR.",
  "sessions": []
}
''';
      final result = GeminiService.parseGeminiResponseJson(raw);
      expect(result.isValid, isFalse);
      expect(result.message, contains('food'));
    });

    test('rejects empty or invalid time ranges', () {
      const raw = '''
{
  "is_valid": true,
  "sessions": [
    {
      "day": "Monday",
      "start_time": "14:00",
      "end_time": "12:00",
      "subject": "Invalid Time"
    }
  ]
}
''';
      final result = GeminiService.parseGeminiResponseJson(raw);
      expect(result.isValid, isFalse);
    });

    test('handles malformed JSON cleanly', () {
      final result = GeminiService.parseGeminiResponseJson('{not-json');
      expect(result.isValid, isFalse);
    });
  });
}
