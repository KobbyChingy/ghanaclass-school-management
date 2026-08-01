class BackendConfig {
  const BackendConfig._();

  /// Public base URL for the GhanaClass backend API.
  ///
  /// This should point to the deployed API layer that fronts your Supabase
  /// project, not directly to the Supabase dashboard URL.
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'GHANACLASS_API_BASE_URL',
    defaultValue: 'https://api.example.com',
  );

  /// Default tenant schema sent in the current backend contract.
  static const String defaultSchoolSchema = String.fromEnvironment(
    'GHANACLASS_TENANT_SCHEMA',
    defaultValue: 'school_demo',
  );

  /// Returns true when the app was built with a real backend URL.
  static bool isValidApiBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    if (host.isEmpty) return false;
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') return false;
    if (host == 'api.example.com' || host == 'api.example') return false;

    return uri.scheme == 'https' || uri.scheme == 'http';
  }

  /// Current tenant header expected by the backend.
  static const String tenantHeaderName = 'x-school-schema';
}