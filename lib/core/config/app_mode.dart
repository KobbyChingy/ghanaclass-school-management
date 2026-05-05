/// Central build/runtime flags for temporarily disabling features.
///
/// This file intentionally keeps the surface area minimal.
class AppMode {
  /// When true, Server Mode is always enabled regardless of saved preferences.
  static const bool forceServerModeOn = true;

  /// When true, Server Mode (remote backend auth/sync) is hard-disabled.
  ///
  /// This overrides the `server_enabled` preference so the app can run fully
  /// offline and login works without a running backend.
  static const bool forceServerModeOff = false;

  static bool resolveServerEnabled(bool? savedPreference) {
    if (forceServerModeOn) return true;
    if (forceServerModeOff) return false;
    return savedPreference ?? false;
  }
}
