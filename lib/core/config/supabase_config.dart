/// Supabase configuration for HerbaScan (Auth, Personal Herbarium, Storage).
///
/// Replace with your project's URL and anon key from:
/// Supabase Dashboard → Project Settings → API.
const String supabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://tsahfzmxqsgbxrrtbdnw.supabase.co',
);

const String supabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_XHJClWPasBxuBkHrMZ7NSw_IaiPy61V',
);

/// Redirect URL for auth links (password reset, change email). Must be added to
/// Supabase Dashboard → Authentication → URL Configuration → Redirect URLs.
/// Using a custom scheme so the link opens the app instead of a browser to localhost.
const String authRedirectUrl = 'herbascan://auth/callback';

/// Whether Supabase is configured (non-placeholder values).
bool get isSupabaseConfigured =>
    supabaseUrl.contains('YOUR_PROJECT') == false &&
    supabaseAnonKey.contains('YOUR_SUPABASE') == false;
