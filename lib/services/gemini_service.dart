import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/gemini_constants.dart';
import '../constants/supabase_constants.dart';
import '../models/class_schedule.dart';

class GeminiService {
  /// Active Gemini API Key (defaults to GeminiConstants.apiKey)
  static String apiKey = GeminiConstants.apiKey;

  /// Check whether a real local API key is configured via --dart-define
  static bool get hasRealApiKey =>
      apiKey.isNotEmpty &&
      !apiKey.contains('ReplaceWithYours') &&
      !apiKey.startsWith('AIzaSyDemo');

  /// Inspects file magic bytes to send an accurate MIME type to Gemini Vision.
  @visibleForTesting
  static String detectImageMimeType(Uint8List bytes) {
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && // R
        bytes[1] == 0x49 && // I
        bytes[2] == 0x46 && // F
        bytes[3] == 0x46 && // F
        bytes[8] == 0x57 && // W
        bytes[9] == 0x45 && // E
        bytes[10] == 0x42 && // B
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  /// Normalizes common weekday abbreviations/casings into canonical names.
  @visibleForTesting
  static String normalizeWeekday(String rawDay) {
    final cleaned = rawDay.trim().toLowerCase();
    switch (cleaned) {
      case 'mon':
      case 'monday':
      case 'm':
        return 'Monday';
      case 'tue':
      case 'tues':
      case 'tuesday':
      case 't':
        return 'Tuesday';
      case 'wed':
      case 'wednesday':
      case 'w':
        return 'Wednesday';
      case 'thu':
      case 'thur':
      case 'thurs':
      case 'thursday':
      case 'th':
        return 'Thursday';
      case 'fri':
      case 'friday':
      case 'f':
        return 'Friday';
      case 'sat':
      case 'saturday':
      case 's':
        return 'Saturday';
      default:
        return rawDay.trim();
    }
  }

  /// Inspects uploaded document, verifies if it is a valid CIT-U COR / Study Load,
  /// and extracts enrolled class schedules.
  /// Uses local GEMINI_API_KEY if supplied via --dart-define; otherwise routes
  /// through the Supabase `verify-cor` Edge Function, falling back to Demo Mode
  /// if the Edge Function or secret is not yet configured.
  static Future<CorVerificationResult> verifyAndExtractCOR(
    Uint8List imageBytes, {
    String? expectedStudentId,
    String? expectedName,
  }) async {
    if (imageBytes.isEmpty) {
      return CorVerificationResult.invalid(
        'No document image provided. Please select an image.',
      );
    }

    if (hasRealApiKey) {
      return _callLiveGeminiVision(
        imageBytes,
        expectedStudentId: expectedStudentId,
        expectedName: expectedName,
      );
    }

    final edgeResult = await _callSupabaseVerifyCor(
      imageBytes,
      expectedStudentId: expectedStudentId,
    );
    if (edgeResult != null) {
      return edgeResult;
    }

    debugPrint(
      '[GeminiService] Running in Development Demo Mode (no local GEMINI_API_KEY and verify-cor secret/function unavailable).',
    );
    return _generateDemoVerificationResult(
      imageBytes,
      expectedStudentId: expectedStudentId,
      expectedName: expectedName,
    );
  }

  static Future<List<ClassSession>> extractScheduleFromCOR(Uint8List imageBytes) async {
    final result = await verifyAndExtractCOR(imageBytes);
    return result.sessions;
  }

  /// Parses raw JSON text returned by Gemini into a structured [CorVerificationResult].
  @visibleForTesting
  static CorVerificationResult parseGeminiResponseJson(
    String rawText, {
    String? expectedStudentId,
  }) {
    try {
      String cleaned = rawText.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
            .replaceFirst(RegExp(r'\s*```$'), '')
            .trim();
      }

      final dynamic decoded = jsonDecode(cleaned);
      if (decoded is! Map<String, dynamic>) {
        return CorVerificationResult.invalid(
          'Unexpected response format from AI schedule extractor.',
        );
      }

      final bool isValid = decoded['is_valid'] == true;
      final String rejectionReason = decoded['rejection_reason']?.toString() ?? '';
      final String? detectedStudentName = decoded['student_name']?.toString();
      final String? detectedStudentId = decoded['student_id']?.toString();

      if (!isValid) {
        return CorVerificationResult.invalid(
          rejectionReason.isNotEmpty
              ? rejectionReason
              : 'The uploaded image was not recognized as a valid CIT-U Certificate of Registration.',
        );
      }

      final List<dynamic> sessionList =
          (decoded['sessions'] is List) ? decoded['sessions'] as List<dynamic> : [];
      if (sessionList.isEmpty) {
        return CorVerificationResult.invalid(
          'The document was recognized, but no enrolled class schedule sessions could be found.',
        );
      }

      final sessions = <ClassSession>[];
      for (final item in sessionList) {
        if (item is Map) {
          final parsed = ClassSession.fromJson(Map<String, dynamic>.from(item));
          final normalizedDay = normalizeWeekday(parsed.day);
          final session = parsed.day == normalizedDay
              ? parsed
              : parsed.copyWith(day: normalizedDay);
          if (ClassSession.validDays.contains(session.day) && session.hasValidTimeRange) {
            sessions.add(session);
          }
        }
      }

      if (sessions.isEmpty) {
        return CorVerificationResult.invalid(
          'Class schedule rows were detected, but none had valid days or start/end times.',
        );
      }

      if (expectedStudentId != null &&
          detectedStudentId != null &&
          detectedStudentId.trim().isNotEmpty) {
        final expectedDigits = expectedStudentId.replaceAll(RegExp(r'[^0-9]'), '');
        final detectedDigits = detectedStudentId.replaceAll(RegExp(r'[^0-9]'), '');
        if (expectedDigits.isNotEmpty &&
            detectedDigits.isNotEmpty &&
            expectedDigits != detectedDigits) {
          debugPrint(
            '[GeminiService] Note: Extracted ID ($detectedStudentId) differs from input ($expectedStudentId)',
          );
        }
      }

      return CorVerificationResult.valid(
        message: 'CIT-U COR verified successfully! Enrolled schedule confirmed.',
        studentName: detectedStudentName,
        studentId: detectedStudentId,
        sessions: sessions,
      );
    } catch (e) {
      return CorVerificationResult.invalid(
        'Could not parse extracted schedule data: ${e.toString()}',
      );
    }
  }

  static Future<CorVerificationResult?> _callSupabaseVerifyCor(
    Uint8List imageBytes, {
    String? expectedStudentId,
  }) async {
    try {
      String? accessToken;
      try {
        accessToken = Supabase.instance.client.auth.currentSession?.accessToken;
      } catch (_) {}

      final mimeType = detectImageMimeType(imageBytes);
      final uri = Uri.parse('${SupabaseConstants.url}/functions/v1/verify-cor');
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'apikey': SupabaseConstants.anonKey,
              if (accessToken != null && accessToken.isNotEmpty)
                'Authorization': 'Bearer $accessToken',
            },
            body: jsonEncode({
              'imageBase64': base64Encode(imageBytes),
              'mimeType': mimeType,
              'model': GeminiConstants.model,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final rawText = decoded is Map ? decoded['raw_text']?.toString() : null;
        if (rawText != null && rawText.trim().isNotEmpty) {
          return parseGeminiResponseJson(
            rawText,
            expectedStudentId: expectedStudentId,
          );
        }
        return CorVerificationResult.invalid(
          'Unexpected empty response from COR verification service.',
        );
      }

      if (response.statusCode == 404 || response.statusCode == 503) {
        debugPrint('[GeminiService] verify-cor temporarily unavailable (${response.statusCode}); falling back to Demo Mode.');
        return null;
      }

      try {
        final errBody = jsonDecode(response.body);
        if (errBody is Map && errBody['error'] == 'missing_secret') {
          debugPrint('[GeminiService] GEMINI_API_KEY secret missing in Supabase.');
          return null;
        }
        final msg = errBody is Map ? errBody['message']?.toString() : null;
        return CorVerificationResult.invalid(
          msg ?? 'COR verification service returned status ${response.statusCode}.',
        );
      } catch (_) {
        return CorVerificationResult.invalid(
          'COR verification service returned status ${response.statusCode}.',
        );
      }
    } catch (e) {
      debugPrint('[GeminiService] Edge Function call unavailable: $e');
      return null;
    }
  }

  static Future<CorVerificationResult> _callLiveGeminiVision(
    Uint8List imageBytes, {
    String? expectedStudentId,
    String? expectedName,
  }) async {
    final base64Image = base64Encode(imageBytes);
    final mimeType = detectImageMimeType(imageBytes);
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/${GeminiConstants.model}:generateContent',
    );

    const systemPrompt = """
You are an official academic document validator and OCR specialist for Cebu Institute of Technology - University (CIT-U).
Your task is to analyze the provided image and determine whether it is an authentic Certificate of Registration (COR), Study Load, or Enrollment Assessment document from CIT-U.

CRITICAL VALIDATION RULES:
1. Verify if the image is an authentic academic document from CIT-U or contains a legitimate study load schedule with course codes and meeting times.
2. If the image is unrelated (e.g. food, animals, random objects, selfies, memes, receipts, blank images), set "is_valid": false and provide an explanatory "rejection_reason".
3. If it is valid:
   - Extract "student_name" (or null if unreadable)
   - Extract "student_id" (e.g. "23-1626-937") (or null if unreadable)
   - Extract all enrolled course sessions in "sessions". For each session:
     - "day": Full English weekday name ("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
     - "start_time": 24-hour time "HH:mm" (e.g. "07:30", "13:00")
     - "end_time": 24-hour time "HH:mm" (e.g. "09:00", "15:30")
     - "subject": Course code or subject name (e.g. "CS 321", "MATH 101")
   If a course meets multiple days (e.g. "MWF" or "TTH"), generate separate session items for each day.
   If no classes or schedules are found on the document, set "is_valid": false and state that no class schedule was detected.

Output strictly valid JSON with this exact schema:
{
  "is_valid": true,
  "rejection_reason": "",
  "student_name": "Jerick Ivan L. Davidon",
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
""";

    try {
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {"text": systemPrompt},
                    {
                      "inline_data": {
                        "mime_type": mimeType,
                        "data": base64Image,
                      }
                    }
                  ]
                }
              ],
              "generationConfig": {
                "response_mime_type": "application/json",
                "temperature": 0.1,
              }
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawText = data['candidates'][0]['content']['parts'][0]['text'] as String;
        return parseGeminiResponseJson(
          rawText,
          expectedStudentId: expectedStudentId,
        );
      } else {
        debugPrint('[GeminiService] API error ${response.statusCode}: ${response.body}');
        return CorVerificationResult.invalid(
          'Gemini AI service returned status ${response.statusCode}. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('[GeminiService] Network/parsing exception: $e');
      return CorVerificationResult.invalid(
        'Failed to connect to Gemini AI: ${e.toString()}',
      );
    }
  }

  /// Development demo validator when API key is not yet provided
  static CorVerificationResult _generateDemoVerificationResult(
    Uint8List imageBytes, {
    String? expectedStudentId,
    String? expectedName,
  }) {
    if (imageBytes.length < 1000) {
      return CorVerificationResult.invalid(
        'The uploaded image file is too small or corrupt. Please upload a clear photo of your COR.',
      );
    }

    final demoSessions = [
      ClassSession(day: 'Monday', startTime: '09:00', endTime: '12:00', subject: 'CS 321 - Software Dev 2'),
      ClassSession(day: 'Tuesday', startTime: '13:00', endTime: '15:30', subject: 'CS 323 - Mobile Computing'),
      ClassSession(day: 'Wednesday', startTime: '09:00', endTime: '12:00', subject: 'CS 321 - Software Dev 2'),
      ClassSession(day: 'Thursday', startTime: '13:00', endTime: '15:30', subject: 'CS 323 - Mobile Computing'),
      ClassSession(day: 'Friday', startTime: '10:00', endTime: '12:00', subject: 'GE 108 - Ethics'),
    ];

    return CorVerificationResult.valid(
      message: 'Demo Mode: Validated CIT-U COR with 5 class sessions.',
      studentName: expectedName ?? 'Jerick Ivan L. Davidon',
      studentId: expectedStudentId ?? '23-1626-937',
      sessions: demoSessions,
      isDemoFallback: true,
    );
  }
}
