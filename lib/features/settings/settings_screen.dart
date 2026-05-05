import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/core/providers/admin_oversight_providers.dart';
import 'package:ghanaclass_school_management/core/providers/communication_providers.dart';
import 'package:ghanaclass_school_management/core/config/app_mode.dart';
import 'package:ghanaclass_school_management/core/config/backend_config.dart';
import 'package:ghanaclass_school_management/features/director/director_kpi_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSmsEnabledKey = 'sms_enabled';
const _kSmsUsernameKey = 'sms_africas_talking_username';
const _kSmsApiKeyKey = 'sms_africas_talking_api_key';
const _kSmsSenderIdKey = 'sms_sender_id';

const _kEmailEnabledKey = 'email_enabled';
const _kEmailSmtpHostKey = 'email_smtp_host';
const _kEmailSmtpPortKey = 'email_smtp_port';
const _kEmailSmtpUsernameKey = 'email_smtp_username';
const _kEmailSmtpPasswordKey = 'email_smtp_password';
const _kEmailFromAddressKey = 'email_from_address';
const _kEmailFromNameKey = 'email_from_name';
const _kEmailUseSslKey = 'email_smtp_use_ssl';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _headController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _mottoController;
  late TextEditingController _yearController;
  late TextEditingController _serverBaseUrlController;
  late TextEditingController _schoolSchemaController;

  late TextEditingController _smsUsernameController;
  late TextEditingController _smsApiKeyController;
  late TextEditingController _smsSenderIdController;

  late TextEditingController _emailSmtpHostController;
  late TextEditingController _emailSmtpPortController;
  late TextEditingController _emailSmtpUsernameController;
  late TextEditingController _emailSmtpPasswordController;
  late TextEditingController _emailFromAddressController;
  late TextEditingController _emailFromNameController;
  int _selectedTerm = 1;
  bool _didSeedSystemSettings = false;

  bool _serverEnabled = false;

  bool _smsEnabled = false;

  bool _emailEnabled = false;
  bool _emailUseSsl = false;
  
  bool _isSaving = false;
  bool _isResetting = false;
  bool _isBackingUp = false;
  bool _isRestoring = false;

  Uint8List? _pendingLogoBytes;
  bool _clearLogo = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _headController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _phoneNumberController = TextEditingController();
    _mottoController = TextEditingController();
    _yearController = TextEditingController();
    _serverBaseUrlController = TextEditingController();
    _schoolSchemaController = TextEditingController();

    _smsUsernameController = TextEditingController();
    _smsApiKeyController = TextEditingController();
    _smsSenderIdController = TextEditingController();

    _emailSmtpHostController = TextEditingController();
    _emailSmtpPortController = TextEditingController(text: '587');
    _emailSmtpUsernameController = TextEditingController();
    _emailSmtpPasswordController = TextEditingController();
    _emailFromAddressController = TextEditingController();
    _emailFromNameController = TextEditingController();

    _loadServerSettings();
    _loadSmsSettings();
    _loadEmailSettings();
  }

  Future<void> _loadServerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    if (AppMode.forceServerModeOn) {
      await prefs.setBool('server_enabled', true);
    }

    if (AppMode.forceServerModeOff) {
      // Hard-disable Server Mode for this build.
      await prefs.setBool('server_enabled', false);
    }

    setState(() {
      _serverEnabled = AppMode.resolveServerEnabled(prefs.getBool('server_enabled'));
      _serverBaseUrlController.text =
          prefs.getString('server_base_url') ?? BackendConfig.defaultApiBaseUrl;
      _schoolSchemaController.text =
          prefs.getString('server_school_schema') ?? BackendConfig.defaultSchoolSchema;
    });
  }

  Future<void> _loadSmsSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _smsEnabled = prefs.getBool(_kSmsEnabledKey) ?? false;
      _smsUsernameController.text = prefs.getString(_kSmsUsernameKey) ?? '';
      _smsApiKeyController.text = prefs.getString(_kSmsApiKeyKey) ?? '';
      _smsSenderIdController.text = prefs.getString(_kSmsSenderIdKey) ?? '';
    });
  }

  Future<void> _loadEmailSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _emailEnabled = prefs.getBool(_kEmailEnabledKey) ?? false;
      _emailUseSsl = prefs.getBool(_kEmailUseSslKey) ?? false;
      _emailSmtpHostController.text = prefs.getString(_kEmailSmtpHostKey) ?? '';
      _emailSmtpPortController.text = (prefs.getInt(_kEmailSmtpPortKey) ?? 587).toString();
      _emailSmtpUsernameController.text = prefs.getString(_kEmailSmtpUsernameKey) ?? '';
      _emailSmtpPasswordController.text = prefs.getString(_kEmailSmtpPasswordKey) ?? '';
      _emailFromAddressController.text = prefs.getString(_kEmailFromAddressKey) ?? '';
      _emailFromNameController.text = prefs.getString(_kEmailFromNameKey) ?? '';
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _headController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _phoneNumberController.dispose();
    _mottoController.dispose();
    _yearController.dispose();
    _serverBaseUrlController.dispose();
    _schoolSchemaController.dispose();
    _smsUsernameController.dispose();
    _smsApiKeyController.dispose();
    _smsSenderIdController.dispose();
    _emailSmtpHostController.dispose();
    _emailSmtpPortController.dispose();
    _emailSmtpUsernameController.dispose();
    _emailSmtpPasswordController.dispose();
    _emailFromAddressController.dispose();
    _emailFromNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identityAsync = ref.watch(institutionalIdentityProvider);
    final systemSettingsAsync = ref.watch(systemSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Institutional Settings'),
      ),
      body: identityAsync.when(
        data: (identity) {
          if (identity == null) return const Center(child: Text('Settings not found.'));
          
          // Pre-fill controllers if empty
          if (_nameController.text.isEmpty) {
            _nameController.text = identity.schoolName;
            _headController.text = identity.headOfInstitution;
            _emailController.text = identity.officialEmail;
            _addressController.text = identity.address ?? '';
            _phoneNumberController.text = identity.phoneNumber ?? '';
            _mottoController.text = identity.motto ?? '';
          }

          systemSettingsAsync.whenData((settings) {
            if (_didSeedSystemSettings) {
              return;
            }
            _didSeedSystemSettings = true;
            _yearController.text = settings.activeAcademicYear.toString();
            _selectedTerm = settings.activeTerm;
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildLogoBox(identity),
                          const SizedBox(width: 24),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'School Configuration',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'Update your school branding and contact details.',
                                  style: TextStyle(color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: (_isSaving || _isResetting) ? null : () => _pickLogo(identity),
                            icon: const Icon(LucideIcons.imagePlus, size: 18),
                            label: const Text('Upload School Logo'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: (_isSaving || _isResetting || (!_hasAnyLogo(identity)))
                                ? null
                                : () {
                                    setState(() {
                                      _pendingLogoBytes = null;
                                      _clearLogo = true;
                                    });
                                  },
                            icon: const Icon(LucideIcons.trash2, size: 18),
                            label: const Text('Remove Logo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Used on ID cards and other school documents.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      
                      const Text('General Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildTextField(_nameController, 'School Name', LucideIcons.building),
                      const SizedBox(height: 16),
                      _buildTextField(_mottoController, 'School Motto', LucideIcons.quote),
                      
                      const SizedBox(height: 32),
                      const Text('Contact & Administration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      _buildTextField(_headController, 'Head of Institution', LucideIcons.user),
                      const SizedBox(height: 16),
                      _buildTextField(_emailController, 'Official Email', LucideIcons.mail, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _buildTextField(_phoneNumberController, 'Phone Number', LucideIcons.phone, keyboardType: TextInputType.phone),
                      const SizedBox(height: 16),
                      _buildTextField(_addressController, 'Physical Address', LucideIcons.mapPin, maxLines: 2),
                      
                      const SizedBox(height: 32),
                      const Text('Academic Cycle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(_yearController, 'Active Academic Year', LucideIcons.calendar, keyboardType: TextInputType.number),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              key: ValueKey(_selectedTerm),
                              initialValue: _selectedTerm,
                              decoration: const InputDecoration(
                                labelText: 'Active Term',
                                prefixIcon: Icon(LucideIcons.clock, size: 20),
                              ),
                              items: const [
                                DropdownMenuItem(value: 1, child: Text('Term 1')),
                                DropdownMenuItem(value: 2, child: Text('Term 2')),
                                DropdownMenuItem(value: 3, child: Text('Term 3')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedTerm = val);
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                      const Text('Cloud Backend (PostgreSQL / Supabase)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'This build is configured for cloud-backed login and synchronization. Configure the backend endpoint and tenant identifier below.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 16),

                      SwitchListTile.adaptive(
                        value: _serverEnabled,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable Cloud Mode'),
                        subtitle: const Text('Use backend auth and sync for all sign-in and data synchronization.'),
                        onChanged: (AppMode.forceServerModeOff || AppMode.forceServerModeOn) ? null : (v) => setState(() => _serverEnabled = v),
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _serverBaseUrlController,
                        'Backend Base URL',
                        LucideIcons.server,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        _schoolSchemaController,
                        'Tenant Schema (${BackendConfig.tenantHeaderName})',
                        LucideIcons.database,
                      ),

                      const SizedBox(height: 32),
                      const Text('Local Data (Backup & Restore)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text(
                        'Export your local database to a backup file, or restore from a previous backup. Restore replaces ALL local data on this device.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: (_isSaving || _isResetting || _isBackingUp || _isRestoring)
                                    ? null
                                    : _exportDatabaseBackup,
                                icon: _isBackingUp
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(LucideIcons.download, size: 18),
                                label: Text(_isBackingUp ? 'EXPORTING...' : 'Export Backup'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: (_isSaving || _isResetting || _isBackingUp || _isRestoring)
                                    ? null
                                    : _showRestoreBackupDialog,
                                icon: _isRestoring
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(LucideIcons.upload, size: 18),
                                label: Text(_isRestoring ? 'RESTORING...' : 'Restore Backup'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orangeAccent,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),
                      const Text('Danger Zone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                      const SizedBox(height: 8),
                      const Text(
                        'Factory reset will erase this device\'s local database and preferences. You will need to register the institution again.',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: (_isSaving || _isResetting) ? null : _showFactoryResetDialog,
                          icon: _isResetting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(LucideIcons.alertTriangle),
                          label: Text(_isResetting ? 'RESETTING...' : 'FACTORY RESET'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: (_isSaving || _isResetting) ? null : () => _confirmAndSaveSettings(identity),
                          icon: _isSaving 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(LucideIcons.save),
                          label: Text(_isSaving ? 'SAVING...' : 'SAVE CHANGES'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.actionIndigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  bool _hasAnyLogo(InstitutionalIdentityData identity) {
    if (_clearLogo) return false;
    if (_pendingLogoBytes != null) return true;
    return identity.logoBytes != null || (identity.logoPath?.trim().isNotEmpty ?? false);
  }

  Widget _buildLogoBox(InstitutionalIdentityData identity) {
    final bytes = _clearLogo ? null : (_pendingLogoBytes ?? identity.logoBytes);
    final path = identity.logoPath;

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppTheme.primarySlate,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.antiAlias,
        child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.cover)
          : ((path != null && path.trim().isNotEmpty)
            ? Image.file(File(path), fit: BoxFit.cover)
            : const Icon(LucideIcons.school, size: 48, color: AppTheme.textMuted)),
    );
  }

  Future<void> _pickLogo(InstitutionalIdentityData identity) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read image bytes. Please try a smaller file.'), backgroundColor: Colors.red),
        );
        return;
      }

      setState(() {
        _pendingLogoBytes = bytes;
        _clearLogo = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo selected. Click SAVE CHANGES to apply.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logo upload failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  String _suggestBackupFileName() {
    final now = DateTime.now();
    final stamp = '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';
    return 'school_backup_$stamp.db';
  }

  Future<void> _exportDatabaseBackup() async {
    if (!mounted) return;
    setState(() => _isBackingUp = true);
    try {
      final dbFile = await getDatabaseFile();
      final exists = await dbFile.exists();
      if (!exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Database file not found yet.'), backgroundColor: Colors.red),
        );
        return;
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: _suggestBackupFileName(),
        type: FileType.custom,
        allowedExtensions: const ['db', 'sqlite'],
      );

      if (savePath == null || savePath.trim().isEmpty) return;

      final targetPath = savePath.toLowerCase().endsWith('.db') || savePath.toLowerCase().endsWith('.sqlite')
          ? savePath
          : '$savePath.db';

      final target = File(targetPath);
      if (await target.exists()) {
        await target.delete();
      }
      await dbFile.copy(targetPath);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup exported: $targetPath'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  void _showRestoreBackupDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'Restoring will REPLACE the current local database on this device.\n\n'
          'Tip: Export a backup first if you are not sure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _restoreDatabaseBackup();
            },
            child: const Text('Choose Backup File'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreDatabaseBackup() async {
    if (!mounted) return;
    setState(() => _isRestoring = true);

    try {
      final pick = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Backup',
        type: FileType.custom,
        allowedExtensions: const ['db', 'sqlite'],
        withData: false,
      );
      if (pick == null || pick.files.isEmpty) return;

      final selectedPath = pick.files.single.path;
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read selected file path.'), backgroundColor: Colors.red),
        );
        return;
      }

      final source = File(selectedPath);
      if (!await source.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected backup file does not exist.'), backgroundColor: Colors.red),
        );
        return;
      }

      // Close DB before replacing the file (Windows keeps file locks).
      final db = ref.read(databaseProvider);
      await db.close();
      ref.invalidate(databaseProvider);

      final dbFile = await getDatabaseFile();
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      await source.copy(dbFile.path);

      // Clear cached session state so routing can re-evaluate cleanly.
      ref.read(currentUserProvider.notifier).setUser(null);
      ref.read(sessionTokenProvider.notifier).setToken(null);
      ref.read(lastUsedEmailProvider.notifier).setEmail(null);
      ref.invalidate(institutionRegisteredProvider);
      ref.invalidate(institutionalIdentityProvider);
      ref.invalidate(systemSettingsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored. Returning to login...'), backgroundColor: Colors.green),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: (val) => val?.isEmpty ?? true ? 'Required field' : null,
    );
  }

  Future<void> _confirmAndSaveSettings(InstitutionalIdentityData identity) async {
    if (!_formKey.currentState!.validate()) return;

    final year = int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm Settings Changes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Save these changes now?'),
            const SizedBox(height: 12),
            Text('School: ${_nameController.text.trim()}'),
            Text('Academic Year: $year'),
            Text('Active Term: $_selectedTerm'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await _saveSettings(identity);
  }

  Future<void> _saveSettings(InstitutionalIdentityData identity) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Save Institutional Identity
      await ref.read(authServiceProvider).updateInstitutionalIdentity(
        InstitutionalIdentityCompanion(
          id: drift.Value(identity.id),
          schoolName: drift.Value(_nameController.text.trim()),
          headOfInstitution: drift.Value(_headController.text.trim()),
          officialEmail: drift.Value(_emailController.text.toLowerCase().trim()),
          address: drift.Value(_addressController.text.trim()),
          phoneNumber: drift.Value(_phoneNumberController.text.trim()),
          motto: drift.Value(_mottoController.text.trim()),
          // Required NOT NULL column in SQLite; keep existing hash unchanged.
          masterPasswordHash: drift.Value(identity.masterPasswordHash),
          logoBytes: _clearLogo
              ? const drift.Value(null)
              : (_pendingLogoBytes == null ? const drift.Value.absent() : drift.Value(_pendingLogoBytes)),
          // Prefer stored bytes; clear legacy path when updating branding.
          logoPath: (_clearLogo || _pendingLogoBytes != null) ? const drift.Value(null) : const drift.Value.absent(),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      // 2. Save System Settings
      final year = int.tryParse(_yearController.text) ?? DateTime.now().year;
      await ref.read(systemSettingsServiceProvider).updateSettings(
        SystemSettingsCompanion(
          activeAcademicYear: drift.Value(year),
          activeTerm: drift.Value(_selectedTerm),
          updatedAt: drift.Value(DateTime.now()),
        ),
      );

      // 3. Save Server Settings
      final effectiveServerEnabled = AppMode.resolveServerEnabled(_serverEnabled);
      await prefs.setBool('server_enabled', effectiveServerEnabled);
      await prefs.setString('server_base_url', _serverBaseUrlController.text.trim());
      await prefs.setString('server_school_schema', _schoolSchemaController.text.trim());

      if (AppMode.forceServerModeOff) {
        await prefs.remove('server_token');
        await prefs.remove('server_school_id');
        await prefs.remove('server_school_schema');
        await prefs.remove('server_user_id');
        await prefs.remove('server_user_email');
        await prefs.remove('server_user_full_name');
        await prefs.remove('server_user_role');
        await prefs.setBool('institution_registered', true);
      } else if (AppMode.forceServerModeOn) {
        await prefs.setBool('server_enabled', true);
      }

      // 4. Save SMS Settings
      await prefs.setBool(_kSmsEnabledKey, _smsEnabled);
      await prefs.setString(_kSmsUsernameKey, _smsUsernameController.text.trim());
      await prefs.setString(_kSmsApiKeyKey, _smsApiKeyController.text.trim());
      await prefs.setString(_kSmsSenderIdKey, _smsSenderIdController.text.trim());

      // 5. Save Email Settings
      await prefs.setBool(_kEmailEnabledKey, _emailEnabled);
      await prefs.setBool(_kEmailUseSslKey, _emailUseSsl);
      await prefs.setString(_kEmailFromAddressKey, _emailFromAddressController.text.trim());
      await prefs.setString(_kEmailFromNameKey, _emailFromNameController.text.trim());
      await prefs.setString(_kEmailSmtpHostKey, _emailSmtpHostController.text.trim());
      await prefs.setInt(_kEmailSmtpPortKey, int.tryParse(_emailSmtpPortController.text.trim()) ?? 587);
      await prefs.setString(_kEmailSmtpUsernameKey, _emailSmtpUsernameController.text.trim());
      await prefs.setString(_kEmailSmtpPasswordKey, _emailSmtpPasswordController.text);

      ref.invalidate(institutionalIdentityProvider);
      ref.invalidate(systemSettingsProvider);
      ref.invalidate(activeYearProvider);
      ref.invalidate(activeTermProvider);
      final updatedSettings = await ref.refresh(systemSettingsProvider.future);
      ref.invalidate(directorKpisProvider);
      ref.invalidate(adminKpisProvider);
      ref.invalidate(smsServiceProvider);
      ref.invalidate(emailServiceProvider);

      setState(() {
        _pendingLogoBytes = null;
        _clearLogo = false;
        _didSeedSystemSettings = true;
        _yearController.text = updatedSettings.activeAcademicYear.toString();
        _selectedTerm = updatedSettings.activeTerm;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Settings updated. Academic Year ${updatedSettings.activeAcademicYear} and Term ${updatedSettings.activeTerm} are now active.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is drift.InvalidDataException
            ? 'Could not save settings. Please try again (or re-register/restore a valid backup if the database is corrupted).'
            : 'Error saving: $e';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showFactoryResetDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Factory Reset'),
        content: const Text(
          'This will delete all local data on this device, including the institution identity, users, and sessions.\n\n'
          'Continue only if you want to register a new institution from scratch.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _performFactoryReset();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  Future<void> _performFactoryReset() async {
    if (!mounted) return;
    setState(() => _isResetting = true);
    Timer? watchdog;
    try {
      watchdog = Timer(const Duration(seconds: 45), () {
        if (!mounted) return;
        if (!_isResetting) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Still resetting... If it stays stuck, close the app completely and try again. '
              'Also ensure no other GhanaClass window is running.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 8),
          ),
        );
      });

      await ref.read(authServiceProvider).performEmergencyReset();

      // Recreate DB-backed services after deleting/clearing the database.
      ref.invalidate(databaseProvider);
      ref.invalidate(authServiceProvider);

      ref.read(currentUserProvider.notifier).setUser(null);
      ref.read(sessionTokenProvider.notifier).setToken(null);
      ref.read(lastUsedEmailProvider.notifier).setEmail(null);
      ref.invalidate(institutionRegisteredProvider);
      ref.invalidate(institutionalIdentityProvider);
      ref.invalidate(systemSettingsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Factory reset complete. Starting setup...')),
      );
      context.go('/register');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Factory reset failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      watchdog?.cancel();
      if (mounted) setState(() => _isResetting = false);
    }
  }
}
