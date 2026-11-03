class AppConfig {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const String livekitUrl = String.fromEnvironment(
    'LIVEKIT_URL',
    defaultValue: 'ws://127.0.0.1:7880',
  );

  static const String tokenEndpoint = String.fromEnvironment(
    'TOKEN_ENDPOINT',
    defaultValue: 'http://127.0.0.1:8787/token',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
