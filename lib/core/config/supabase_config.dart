class SupabaseConfig {
  const SupabaseConfig._();

  static const String url = String.fromEnvironment(
    'GHANACLASS_SUPABASE_URL',
    defaultValue: 'https://eqrkfynzaznoarcziepm.supabase.co',
  );

  static const String publishableKey = String.fromEnvironment(
    'GHANACLASS_SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_7oThgrzPu25cDp-4i_7I-w_y8YJ7H0f',
  );

  static bool get isConfigured =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;
}