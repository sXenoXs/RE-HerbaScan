/// Supabase configuration for HerbaScan (Auth, Personal Herbarium, Storage).
///
/// Credentials are injected at build time via --dart-define flags:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://tsahfzmxqsgbxrrtbdnw.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=<your_anon_key>
///
/// Never hardcode credentials in source — use dart-define for all builds.
/// The anon key (sb_publishable_*) is safe for client use per Supabase design,
/// but keeping it out of source prevents accidental exposure in public repos.
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://tsahfzmxqsgbxrrtbdnw.supabase.co',
);

/// Supabase anon key — injected via --dart-define=SUPABASE_ANON_KEY=<key>.
/// No hardcoded defaultValue: if not provided at build time, isSupabaseConfigured
/// returns false and the app operates in offline-only mode.
const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: '',
);

/// Redirect URL for auth links (password reset, change email). Must be added to
/// Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.
/// Using a custom scheme so the link opens the app instead of a browser to localhost.
const String authRedirectUrl = 'herbascan://auth/callback';

/// Whether Supabase is configured with real (non-empty, non-placeholder) credentials.
bool get isSupabaseConfigured =>
    supabaseUrl.isNotEmpty &&
    supabaseAnonKey.isNotEmpty &&
    supabaseUrl.contains('YOUR_PROJECT') == false &&
    supabaseAnonKey.contains('YOUR_SUPABASE') == false;
