class ApiConfig {
  // Compiled directly into the JS/native binary at build time — no file on
  // disk to be gitignored, missed by `git add`, or (as just discovered)
  // silently stripped by Netlify's dotfile-deploy rule. Pass it in per
  // build instead of shipping a .env asset:
  //
  //   flutter build web --release --dart-define=API_BASE_URL=https://pincef-talent-backend.onrender.com/api
  //   flutter run --dart-define=API_BASE_URL=http://localhost:4000/api
  static String get baseUrl => const String.fromEnvironment(
        'API_BASE_URL',
        // defaultValue: 'https://pincef-talent-backend.onrender.com/api',
        defaultValue: 'http://localhost:4000/api',
      );
}
