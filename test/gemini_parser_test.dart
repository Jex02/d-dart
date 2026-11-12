import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sd2/services/gemini_service.dart';

void main() {
  group('GeminiService COR parser & helpers', () {
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

    test('normalizes weekday abbreviations in extracted schedule', () {
      const raw = '''
{
  "is_valid": true,
  "sessions": [
    {"day": "mon", "start_time": "08:00", "end_time": "09:30", "subject": "CS 101"},
    {"day": "Thurs", "start_time": "13:00", "end_time": "14:30", "subject": "IT 202"}
  ]
}
''';
      final result = GeminiService.parseGeminiResponseJson(raw);
      expect(result.isValid, isTrue);
      expect(result.sessions.length, 2);
      expect(result.sessions[0].day, 'Monday');
      expect(result.sessions[1].day, 'Thursday');
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

    test('detects PNG, WebP, and JPEG magic bytes accurately', () {
      final png = Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
      final webp = Uint8List.fromList([
        0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
      ]);
      final jpg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);

      expect(GeminiService.detectImageMimeType(png), 'image/png');
      expect(GeminiService.detectImageMimeType(webp), 'image/webp');
      expect(GeminiService.detectImageMimeType(jpg), 'image/jpeg');
    });
  });
}
