import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/features/id_cards/id_cards_providers.dart';
import 'package:ghanaclass_school_management/features/staff/staff_providers.dart';
import 'package:go_router/go_router.dart';

class StaffProfileScreen extends ConsumerStatefulWidget {
  final int staffTableId;

  const StaffProfileScreen({super.key, required int staffId}) : staffTableId = staffId;

  @override
  ConsumerState<StaffProfileScreen> createState() => _StaffProfileScreenState();
}

class _StaffProfileScreenState extends ConsumerState<StaffProfileScreen> {
  bool _isEditing = false;
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _staffId = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _position = TextEditingController();
  final _department = TextEditingController();
  final _emergencyContact = TextEditingController();
  final _salary = TextEditingController();

  DateTime? _dob;
  DateTime? _hireDate;
  String _gender = 'male';
  UserRole _portalRole = UserRole.teacher;
  bool _isActive = true;

  int? _seededFromStaffId;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _staffId.dispose();
    _phone.dispose();
    _address.dispose();
    _position.dispose();
    _department.dispose();
    _emergencyContact.dispose();
    _salary.dispose();
    super.dispose();
  }

  bool _seedControllersIfNeeded({required int staffId, required String firstName, required String lastName}) {
    if (_seededFromStaffId == staffId) return false;
    _seededFromStaffId = staffId;

    _firstName.text = firstName;
    _lastName.text = lastName;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffWithUserProvider(widget.staffTableId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Profile'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        actions: [
          staffAsync.when(
            data: (data) {
              if (data == null) return const SizedBox.shrink();
              return Row(
                children: [
                  TextButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () => setState(() {
                              _isEditing = !_isEditing;
                            }),
                    icon: Icon(_isEditing ? LucideIcons.eye : LucideIcons.pencil),
                    label: Text(_isEditing ? 'VIEW' : 'EDIT'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _isSaving
                        ? null
                        : () async {
                            await ref.read(idCardPdfServiceProvider).printStaffIdCards(staffIds: [data.staff.id]);
                          },
                    icon: const Icon(LucideIcons.contact, size: 18),
                    label: const Text('ID CARD'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _resetPasswordFlow(data.user?.email),
                    icon: const Icon(LucideIcons.keyRound, size: 18),
                    label: const Text('RESET PASSWORD'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.actionIndigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: staffAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Staff record not found.'));
          }

          final staff = data.staff;
          final user = data.user;

          final seededNow = _seedControllersIfNeeded(
            staffId: staff.id,
            firstName: staff.firstName,
            lastName: staff.lastName,
          );

          if (seededNow) {
            _staffId.text = staff.staffId;
            _phone.text = staff.phoneNumber;
            _address.text = (staff.address ?? '').toString();
            _position.text = staff.position;
            _department.text = (staff.department ?? '').toString();
            _emergencyContact.text = (staff.emergencyContact ?? '').toString();
            _salary.text = staff.baseSalary.toStringAsFixed(2);
            _dob ??= staff.dateOfBirth;
            _hireDate ??= staff.hireDate;
            _gender = staff.gender;
            _isActive = staff.isActive;
            final roleFromUser = user?.role;
            _portalRole = supportedStaffPortalRoles.firstWhere(
              (r) => r.name == roleFromUser,
              orElse: () => UserRole.teacher,
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _headerCard(staff, user),
                    const SizedBox(height: 16),
                    _detailsCard(staff, user),
                    if (_isEditing) ...[
                      const SizedBox(height: 16),
                      _actionsCard(staffId: staff.id),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _headerCard(dynamic staff, dynamic user) {
    final initials = (staff.firstName.isNotEmpty ? staff.firstName[0] : 'S') + (staff.lastName.isNotEmpty ? staff.lastName[0] : 'T');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.12),
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.actionIndigo, fontSize: 18),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${staff.firstName} ${staff.lastName}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _pill(LucideIcons.briefcase, staff.position),
                      _pill(LucideIcons.hash, staff.staffId),
                      _pill(LucideIcons.phone, staff.phoneNumber),
                      if (user != null) _pill(LucideIcons.atSign, user.email),
                      _pill(
                        staff.isActive ? LucideIcons.checkCircle : LucideIcons.xCircle,
                        staff.isActive ? 'ACTIVE' : 'INACTIVE',
                        color: staff.isActive ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard(dynamic staff, dynamic user) {
    final directorExists = ref.watch(directorAccountExistsProvider(user?.id as int?)).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );
    final availableRoles = directorExists
        ? supportedStaffPortalRoles.where((role) => role != UserRole.director).toList(growable: false)
        : supportedStaffPortalRoles;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              _sectionTitle('Personal'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _textField(_firstName, 'First Name', enabled: _isEditing)),
                  const SizedBox(width: 12),
                  Expanded(child: _textField(_lastName, 'Last Name', enabled: _isEditing)),
                  const SizedBox(width: 12),
                  Expanded(child: _textField(_staffId, 'Staff ID', enabled: false)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _genderField()),
                  const SizedBox(width: 12),
                  Expanded(child: _dateField('Date of Birth', _dob, enabled: _isEditing, onChanged: (d) => setState(() => _dob = d))),
                  const SizedBox(width: 12),
                  Expanded(child: _dateField('Hire Date', _hireDate, enabled: _isEditing, onChanged: (d) => setState(() => _hireDate = d))),
                ],
              ),

              const SizedBox(height: 18),
              _sectionTitle('Employment'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _textField(_position, 'Position', enabled: _isEditing)),
                  const SizedBox(width: 12),
                  Expanded(child: _textField(_department, 'Department', enabled: _isEditing, required: false)),
                  const SizedBox(width: 12),
                  Expanded(child: _textField(_salary, 'Base Salary', enabled: _isEditing, keyboardType: TextInputType.number)),
                ],
              ),

              const SizedBox(height: 18),
              _sectionTitle('Contact'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _textField(_phone, 'Phone', enabled: _isEditing)),
                  const SizedBox(width: 12),
                  Expanded(child: _textField(_emergencyContact, 'Emergency Contact', enabled: _isEditing, required: false)),
                ],
              ),
              const SizedBox(height: 12),
              _textField(_address, 'Address', enabled: _isEditing, required: false),

              const SizedBox(height: 18),
              _sectionTitle('Portal Access'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Login Email / Username'),
                      child: Text(user?.email ?? '—'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _roleField(user != null, availableRoles)),
                  const SizedBox(width: 12),
                  Expanded(child: _activeField()),
                ],
              ),
              if (directorExists)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Another Director account already exists for this school.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionsCard({required int staffId}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: _isSaving
                  ? null
                  : () => setState(() {
                        _isEditing = false;
                      }),
              child: const Text('CANCEL'),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _saveChanges(staffId),
              icon: _isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.save, size: 18),
              label: Text(_isSaving ? 'SAVING...' : 'SAVE CHANGES'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.actionIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveChanges(int staffTableId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dob == null || _hireDate == null) return;

    final salary = double.tryParse(_salary.text.trim());
    if (salary == null || salary < 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid salary.')));
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      final data = await ref.read(staffWithUserProvider(staffTableId).future);
      final linkedUser = data?.user;
      final fullName = '${_firstName.text.trim()} ${_lastName.text.trim()}';

      if (linkedUser != null) {
        await ref.read(authServiceProvider).updateStaffPortalAccount(
              email: linkedUser.email,
              fullName: fullName,
              role: _portalRole,
              isActive: _isActive,
            );
      }

      await ref.read(staffServiceProvider).updateStaffAndUser(
            staffTableId: staffTableId,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            phoneNumber: _phone.text.trim(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            emergencyContact: _emergencyContact.text.trim().isEmpty ? null : _emergencyContact.text.trim(),
            position: _position.text.trim(),
            department: _department.text.trim().isEmpty ? null : _department.text.trim(),
            hireDate: _hireDate!,
            dateOfBirth: _dob!,
            gender: _gender,
            baseSalary: salary,
            isActive: _isActive,
            portalRole: _portalRole.name,
          );

      ref.invalidate(staffListProvider);
      ref.invalidate(staffWithUserProvider(staffTableId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff profile updated.')));
      }
      setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _resetPasswordFlow(String? email) async {
    if (email == null || email.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No portal account linked to this staff record.')),
        );
      }
      return;
    }

    final controller = TextEditingController();
    var obscure = true;
    try {
      final newPassword = await showDialog<String>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setLocalState) {
              return AlertDialog(
                title: const Text('Reset Staff Password'),
                content: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                      onPressed: () => setLocalState(() => obscure = !obscure),
                    ),
                  ),
                  obscureText: obscure,
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                  ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('RESET')),
                ],
              );
            },
          );
        },
      );

      if (!mounted) return;

      if (newPassword == null) return;
      if (newPassword.length < 4) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password too short (min 4).')));
        }
        return;
      }

      final data = await ref.read(staffWithUserProvider(widget.staffTableId).future);
      if (data == null || data.user == null) return;

      await ref.read(authServiceProvider).createOrUpdateStaffUser(
            fullName: '${data.staff.firstName} ${data.staff.lastName}',
            email: data.user!.email,
            password: newPassword,
            role: UserRole.values.firstWhere((r) => r.name == data.user!.role, orElse: () => UserRole.teacher),
            phoneNumber: data.staff.phoneNumber,
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successfully.')),
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted));
  }

  Widget _pill(IconData icon, String text, {Color? color}) {
    final c = color ?? AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    required bool enabled,
    bool required = true,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
      validator: (val) {
        if (!required) return null;
        if (val == null || val.trim().isEmpty) return 'Required';
        if (label == 'Base Salary') {
          final parsed = double.tryParse(val.trim());
          if (parsed == null) return 'Invalid number';
        }
        return null;
      },
    );
  }

  Widget _genderField() {
    return DropdownButtonFormField<String>(
      initialValue: _gender,
      decoration: const InputDecoration(labelText: 'Gender'),
      items: const [
        DropdownMenuItem(value: 'male', child: Text('Male')),
        DropdownMenuItem(value: 'female', child: Text('Female')),
      ],
      onChanged: _isEditing ? (v) => setState(() => _gender = v ?? 'male') : null,
    );
  }

  Widget _roleField(bool hasUser, List<UserRole> roles) {
    return DropdownButtonFormField<UserRole>(
      initialValue: roles.contains(_portalRole) ? _portalRole : roles.first,
      decoration: const InputDecoration(labelText: 'Portal Role'),
      isExpanded: true,
      items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r.displayName))).toList(),
      onChanged: (!hasUser || !_isEditing) ? null : (v) => setState(() => _portalRole = v ?? _portalRole),
    );
  }

  Widget _activeField() {
    return DropdownButtonFormField<bool>(
      initialValue: _isActive,
      decoration: const InputDecoration(labelText: 'Status'),
      items: const [
        DropdownMenuItem(value: true, child: Text('Active')),
        DropdownMenuItem(value: false, child: Text('Inactive')),
      ],
      onChanged: !_isEditing ? null : (v) => setState(() => _isActive = v ?? true),
    );
  }

  Widget _dateField(
    String label,
    DateTime? value, {
    required bool enabled,
    required void Function(DateTime) onChanged,
  }) {
    final display = value == null ? '—' : '${value.day}/${value.month}/${value.year}';
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: DateTime(1900),
                lastDate: now.add(const Duration(days: 365 * 2)),
              );
              if (picked != null) onChanged(picked);
            },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(display),
      ),
    );
  }
}
