import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/features/parents/parent_providers.dart';
import 'package:ghanaclass_school_management/features/students/student_providers.dart';

class StudentEditScreen extends ConsumerStatefulWidget {
  final Student student;
  final HealthRecord? healthRecord;

  const StudentEditScreen({
    super.key,
    required this.student,
    this.healthRecord,
  });

  @override
  ConsumerState<StudentEditScreen> createState() => _StudentEditScreenState();
}

class _StudentEditScreenState extends ConsumerState<StudentEditScreen> {
    // Leadership/position
    late TextEditingController _positionController;
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  // Personal Info
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _otherNamesController;
  late String _gender;
  DateTime? _dob;
  String? _photoPath;
  
  // Guardian Info
  late TextEditingController _guardianNameController;
  late TextEditingController _guardianPhoneController;
  late TextEditingController _guardianEmailController;
  late TextEditingController _guardianOccupationController;
  late TextEditingController _guardianRelationshipController;
  late TextEditingController _guardianAddressController;

  // Health records
  late TextEditingController _bloodGroupController;
  late TextEditingController _allergiesController;
  late TextEditingController _medicalHistoryController;

  // Student services
  late bool _eatsCanteen;
  late bool _takesSchoolBus;
  
  bool _isLoading = false;
  int _parentReloadTick = 0;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    
    _firstNameController = TextEditingController(text: s.firstName);
    _lastNameController = TextEditingController(text: s.lastName);
    _otherNamesController = TextEditingController(text: s.otherNames);
    _gender = s.gender;
    _dob = s.dateOfBirth;
    _photoPath = s.photoPath;

    _eatsCanteen = s.eatsCanteen;
    _takesSchoolBus = s.takesSchoolBus;

    _guardianNameController = TextEditingController(text: s.guardianName);
    _guardianPhoneController = TextEditingController(text: s.guardianPhone);
    _guardianEmailController = TextEditingController(text: s.guardianEmail);
    _guardianOccupationController = TextEditingController(text: s.guardianOccupation);
    _guardianRelationshipController = TextEditingController(text: s.guardianRelationship);
    _guardianAddressController = TextEditingController(text: s.guardianAddress);

    _positionController = TextEditingController(text: s.position ?? '');

    final h = widget.healthRecord;
    _bloodGroupController = TextEditingController(text: h?.bloodGroup);
    _allergiesController = TextEditingController(text: h?.allergies);
    _medicalHistoryController = TextEditingController(text: h?.medications);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _otherNamesController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianEmailController.dispose();
    _guardianOccupationController.dispose();
    _guardianRelationshipController.dispose();
    _guardianAddressController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _medicalHistoryController.dispose();
    _scrollController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      setState(() => _photoPath = result.files.single.path);
    }
  }

  Future<void> _handleUpdate() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final s = widget.student;
      final studentService = ref.read(studentServiceProvider);

      // Update Student
      final updatedStudent = StudentsCompanion(
        id: drift.Value(s.id),
        studentId: drift.Value(s.studentId),
        admissionNumber: drift.Value(s.admissionNumber),
        firstName: drift.Value(_firstNameController.text.trim()),
        lastName: drift.Value(_lastNameController.text.trim()),
        otherNames: drift.Value(_otherNamesController.text.isNotEmpty ? _otherNamesController.text.trim() : null),
        gender: drift.Value(_gender),
        dateOfBirth: drift.Value(_dob!),
        photoPath: drift.Value(_photoPath),
        eatsCanteen: drift.Value(_eatsCanteen),
        takesSchoolBus: drift.Value(_takesSchoolBus),
        guardianName: drift.Value(_guardianNameController.text.trim()),
        guardianPhone: drift.Value(_guardianPhoneController.text.trim()),
        guardianEmail: drift.Value(_guardianEmailController.text.isNotEmpty ? _guardianEmailController.text.trim() : null),
        guardianOccupation: drift.Value(_guardianOccupationController.text.trim()),
        guardianRelationship: drift.Value(_guardianRelationshipController.text.trim()),
        guardianAddress: drift.Value(_guardianAddressController.text.trim()),
        position: _positionController.text.trim().isNotEmpty ? drift.Value(_positionController.text.trim()) : const drift.Value.absent(),
        admissionDate: drift.Value(s.admissionDate),
        enrolledFees: drift.Value(s.enrolledFees),
        status: drift.Value(s.status),
        createdAt: drift.Value(s.createdAt),
      );

      await studentService.updateStudent(updatedStudent);

      // Update Health (best-effort, but keep local consistent)
      await studentService.upsertHealthRecordForStudent(
        studentLocalId: s.id,
        bloodGroup: _bloodGroupController.text,
        allergies: _allergiesController.text,
        medications: _medicalHistoryController.text,
      );

      // Log Activity
      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        await ref.read(activityServiceProvider).logActivity(
          actorUserId: currentUser.id,
          actorName: currentUser.fullName,
          actorRole: UserRole.values.firstWhere((r) => r.name == currentUser.role, orElse: () => UserRole.secretary),
          module: 'students',
          actionType: 'student_updated',
          description: 'Updated profile for ${s.firstName} ${s.lastName}',
          isImportant: false,
        );
      }
      
      ref.invalidate(studentProfileProvider(s.id));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated Successfully'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Student Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader('Personal Information', LucideIcons.user),
                        const SizedBox(height: 16),
                        _buildPersonalInfoSection(),
                        const SizedBox(height: 32),
                        _buildSectionHeader('Guardian Information', LucideIcons.users),
                        const SizedBox(height: 16),
                        _buildGuardianSection(),
                        const SizedBox(height: 16),
                        _buildParentPortalAccessSection(),
                        const SizedBox(height: 32),
                        _buildSectionHeader('Health Records', LucideIcons.heartPulse),
                        const SizedBox(height: 16),
                        _buildHealthSection(),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _handleUpdate,
                          icon: const Icon(LucideIcons.save),
                          label: const Text('Save Changes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.actionIndigo,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.actionIndigo, size: 20),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(width: 16),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            width: 120,
            height: 150,
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: _photoPath != null
                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_photoPath!), fit: BoxFit.cover))
                : const Icon(LucideIcons.camera, color: AppTheme.textMuted),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'First Name *'))),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Last Name *'))),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _otherNamesController, decoration: const InputDecoration(labelText: 'Other Names')),
              const SizedBox(height: 16),
              TextFormField(controller: _positionController, decoration: const InputDecoration(labelText: 'Position / Leadership Role (e.g. School Prefect, Class Prefect)')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Sex *'),
                      items: const [
                        DropdownMenuItem(value: 'male', child: Text('Male')),
                        DropdownMenuItem(value: 'female', child: Text('Female')),
                      ],
                      onChanged: (v) => setState(() => _gender = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dob ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) setState(() => _dob = picked);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Date of Birth *'),
                        child: Text(_dob == null ? 'Select Date' : DateFormat('dd/MM/yyyy').format(_dob!)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Eats at Canteen'),
                value: _eatsCanteen,
                onChanged: (v) => setState(() => _eatsCanteen = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Takes School Bus'),
                value: _takesSchoolBus,
                onChanged: (v) => setState(() => _takesSchoolBus = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuardianSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: TextFormField(controller: _guardianNameController, decoration: const InputDecoration(labelText: 'Guardian Name *'))),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _guardianPhoneController, decoration: const InputDecoration(labelText: 'Phone *'))),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: TextFormField(controller: _guardianRelationshipController, decoration: const InputDecoration(labelText: 'Relationship *'))),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _guardianEmailController, decoration: const InputDecoration(labelText: 'Email'))),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(controller: _guardianOccupationController, decoration: const InputDecoration(labelText: 'Occupation')),
        const SizedBox(height: 16),
        TextFormField(controller: _guardianAddressController, decoration: const InputDecoration(labelText: 'Address')),
      ],
    );
  }

  Widget _buildParentPortalAccessSection() {
    final parentService = ref.read(parentServiceProvider);
    final studentId = widget.student.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<ParentAccount?>(
          key: ValueKey('parent_portal_${studentId}_$_parentReloadTick'),
          future: parentService.getParentForStudent(studentId),
          builder: (context, snap) {
            final parent = snap.data;
            final isLoading = snap.connectionState == ConnectionState.waiting;

            final title = Row(
              children: [
                const Icon(LucideIcons.lock, size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Parent Portal Account',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isLoading) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            );

            Widget status;
            if (parent == null) {
              status = const Text(
                'No parent portal login created for this student yet.',
                style: TextStyle(color: AppTheme.textMuted),
              );
            } else {
              final lastLogin = parent.lastLoginAt;
              status = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    parent.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: parent.isActive ? AppTheme.success : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Email: ${parent.email}', style: const TextStyle(color: AppTheme.textMuted)),
                  Text('Phone: ${parent.phoneNumber}', style: const TextStyle(color: AppTheme.textMuted)),
                  if (lastLogin != null)
                    Text(
                      'Last login: ${DateFormat('dd/MM/yyyy, HH:mm').format(lastLogin)}',
                      style: const TextStyle(color: AppTheme.textMuted),
                    ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                title,
                const SizedBox(height: 10),
                status,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () => _showCreateOrResetParentAccountDialog(existing: parent),
                        icon: Icon(parent == null ? LucideIcons.userPlus : LucideIcons.keyRound),
                        label: Text(parent == null ? 'Create Parent Login' : 'Reset Parent Login'),
                      ),
                    ),
                    if (parent != null) ...[
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Copy parent email',
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          await Clipboard.setData(ClipboardData(text: parent.email));
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Parent email copied'), backgroundColor: Colors.green),
                          );
                        },
                        icon: const Icon(LucideIcons.copy),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Parents log in from the main Login screen by selecting PORTAL ACCESS ROLE = PARENT, then using the email + password set here.',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _generateParentPassword() {
    // Simple numeric PIN-like password to match existing login UI expectations.
    // Not cryptographically strong; intended for school-issued credentials.
    final ms = DateTime.now().millisecondsSinceEpoch;
    final pin = (ms % 100000000).toString().padLeft(8, '0');
    return pin;
  }

  Future<void> _showCreateOrResetParentAccountDialog({required ParentAccount? existing}) async {
    final student = widget.student;
    final parentService = ref.read(parentServiceProvider);
    final rootContext = context;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: _guardianNameController.text.trim());
    final phoneController = TextEditingController(text: _guardianPhoneController.text.trim());
    final emailController = TextEditingController(text: (_guardianEmailController.text).trim());
    final relationshipController = TextEditingController(
      text: _guardianRelationshipController.text.trim().isEmpty ? 'parent' : _guardianRelationshipController.text.trim(),
    );
    final passwordController = TextEditingController(text: _generateParentPassword());
    var obscure = true;
    var isSaving = false;
    String? createdEmail;
    String? createdPassword;
    String? resultMessage;

    String friendlyError(Object e) {
      final raw = e.toString();
      final msg = raw.replaceFirst('Exception: ', '').trim();
      final lower = msg.toLowerCase();
      if (lower.contains('unique constraint failed') && lower.contains('parent_accounts.email')) {
        return 'This email is already used by another parent account.';
      }
      return msg;
    }

    await showDialog<void>(
      context: rootContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isResultMode = createdEmail != null && createdPassword != null;
            return AlertDialog(
              title: Text(
                isResultMode
                    ? (existing == null ? 'Parent Login Created' : 'Parent Login Reset')
                    : (existing == null ? 'Create Parent Login' : 'Reset Parent Login'),
              ),
              content: isResultMode
                  ? SizedBox(
                      width: 520,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (resultMessage != null) ...[
                            Text(
                              resultMessage!,
                              style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),
                          ],
                          SelectableText(
                            'Give these credentials to the parent:\n\n'
                            'Email: $createdEmail\n'
                            'Password: $createdPassword\n\n'
                            'Login path: Login screen → PORTAL ACCESS ROLE = PARENT',
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Student: ${student.firstName} ${student.lastName}',
                            style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : Form(
                      key: formKey,
                      child: SizedBox(
                        width: 520,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: nameController,
                              decoration: const InputDecoration(labelText: 'Parent/Guardian Name *'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: relationshipController,
                              decoration: const InputDecoration(labelText: 'Relationship *'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: phoneController,
                              decoration: const InputDecoration(labelText: 'Phone *'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: emailController,
                              decoration: const InputDecoration(labelText: 'Email *'),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password / PIN *',
                                suffixIcon: IconButton(
                                  icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setDialogState(() => obscure = !obscure),
                                ),
                              ),
                              obscureText: obscure,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Student: ${student.firstName} ${student.lastName}',
                              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: Text(isResultMode ? 'Close' : 'Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: (isSaving || isResultMode)
                      ? null
                      : () async {
                    final state = formKey.currentState;
                    if (state == null) return;
                    if (!state.validate()) return;

                    setDialogState(() => isSaving = true);
                    try {
                      final saved = await parentService
                          .upsertParentAccountForStudent(
                            studentId: student.id,
                            parentName: nameController.text.trim(),
                            email: emailController.text.trim(),
                            password: passwordController.text,
                            phoneNumber: phoneController.text.trim(),
                            relationship: relationshipController.text.trim(),
                          )
                          .timeout(const Duration(seconds: 20));

                      // Sanity check: confirm credentials are immediately usable (no DB side-effects).
                      final canLogin = await parentService
                          .canParentLogin(saved.email, passwordController.text)
                          .timeout(const Duration(seconds: 10));
                      if (!canLogin) {
                        throw Exception('Parent login was saved, but the credentials could not be verified. Please try again.');
                      }

                      if (mounted) {
                        setState(() => _parentReloadTick++);
                      }

                      if (dialogContext.mounted) {
                        setDialogState(() {
                          createdEmail = saved.email;
                          createdPassword = passwordController.text;
                          resultMessage = existing == null
                              ? 'Parent login created successfully.'
                              : 'Parent login reset successfully.';
                        });
                      }
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(content: Text(friendlyError(e)), backgroundColor: Colors.red),
                      );
                    } finally {
                      if (dialogContext.mounted) {
                        setDialogState(() => isSaving = false);
                      }
                    }
                  },
                  icon: Icon(existing == null ? LucideIcons.userPlus : LucideIcons.keyRound),
                  label: Text(isSaving ? 'Please wait...' : (existing == null ? 'Create' : 'Reset')),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo),
                ),
                if (isResultMode)
                  TextButton(
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(dialogContext);
                      final email = createdEmail;
                      final password = createdPassword;
                      if (email == null || password == null) return;
                      await Clipboard.setData(ClipboardData(text: 'Email: $email\nPassword: $password'));
                      if (!dialogContext.mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Credentials copied'), backgroundColor: Colors.green),
                      );
                    },
                    child: const Text('Copy'),
                  ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    relationshipController.dispose();
    passwordController.dispose();
  }

  Widget _buildHealthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _bloodGroupController,
                decoration: const InputDecoration(labelText: 'Blood Group'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _allergiesController,
                decoration: const InputDecoration(labelText: 'Allergies'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _medicalHistoryController,
          decoration: const InputDecoration(labelText: 'Medications / Medical History'),
          maxLines: 3,
        ),
        if (widget.healthRecord != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Remove health record?'),
                  content: const Text('This will delete the health record for this student.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (confirmed != true) return;

              setState(() => _isLoading = true);
              try {
                final studentService = ref.read(studentServiceProvider);
                await studentService.deleteHealthRecordForStudent(widget.student.id);
                ref.invalidate(studentProfileProvider(widget.student.id));
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Health record removed'), backgroundColor: Colors.green),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            icon: const Icon(LucideIcons.trash2),
            label: const Text('Remove Health Record'),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ],
    );
  }
}
