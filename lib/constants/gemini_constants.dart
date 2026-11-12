class GeminiConstants {
  /// Google AI Studio Gemini API Key.
  /// Pass at build/run time via:
  ///   flutter run --dart-define=GEMINI_API_KEY=your_key_here
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'AIzaSyDemoKeyReplaceWithYours',
  );

  /// Preferred Gemini Vision model (overrideable via --dart-define=GEMINI_MODEL=...)
  static const String model = String.fromEnvironment(
    'GEMINI_MODEL',
    defaultValue: 'gemini-3.5-flash-lite',
  );
}
