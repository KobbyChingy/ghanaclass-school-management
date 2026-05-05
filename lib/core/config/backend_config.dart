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

  /// Current tenant header expected by the backend.
  static const String tenantHeaderName = 'x-school-schema';
}