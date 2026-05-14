// KAMOS — API endpoint config.
//
// Base URL is supplied at build time via `--dart-define=KAMOS_API_BASE_URL=...`.
// Default is `http://localhost:8080`, matching backend `.env.example`.

class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'KAMOS_API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String googleClientId = String.fromEnvironment(
    'KAMOS_GOOGLE_CLIENT_ID',
    defaultValue: '',
  );
}
