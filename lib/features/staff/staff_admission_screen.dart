import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'staff_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';

class StaffAdmissionScreen extends ConsumerStatefulWidget {
  const StaffAdmissionScreen({super.key});

  @override
  ConsumerState<StaffAdmissionScreen> createState() => _StaffAdmissionScreenState();
}

class _StaffAdmissionScreenState extends ConsumerState<StaffAdmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _staffIdController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _positionController = TextEditingController();
  final _salaryController = TextEditingController();

  final _loginIdController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _obscurePortalPassword = true;
  UserRole _portalRole = UserRole.teacher;
  
  String _selectedGender = 'male';
  DateTime _dob = DateTime.now().subtract(const Duration(days: 365 * 25));
  DateTime _hireDate = DateTime.now();
    // Contract Details
    final _contractTypeController = TextEditingController();
    DateTime? _contractStartDate;
    DateTime? _contractEndDate;

    // Qualifications
    final _qualificationsController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _staffIdController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _positionController.dispose();
    _salaryController.dispose();
    _loginIdController.dispose();
    _loginPasswordController.dispose();
      _contractTypeController.dispose();
      _qualificationsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final directorExists = ref.watch(directorAccountExistsProvider(null)).maybeWhen(
          data: (value) => value,
          orElse: () => false,
        );
    final availableRoles = directorExists
        ? supportedStaffPortalRoles.where((role) => role != UserRole.director).toList(growable: false)
        : supportedStaffPortalRoles;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Admission'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Personal Details'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_firstNameController, 'First Name', LucideIcons.user)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField(_lastNameController, 'Last Name', LucideIcons.user)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildGenderSelector()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDatePicker('Date of Birth', _dob, (date) => setState(() => _dob = date))),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Employment Details'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_staffIdController, 'Staff ID Code', LucideIcons.hash)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField(_positionController, 'Position (e.g. Teacher, Admin)', LucideIcons.briefcase)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_salaryController, 'Base Salary', LucideIcons.banknote, keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildDatePicker('Hire Date', _hireDate, (date) => setState(() => _hireDate = date))),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Portal Login (Staff Credentials)'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _loginIdController,
                          decoration: const InputDecoration(
                            labelText: 'Username / Email',
                            prefixIcon: Icon(LucideIcons.atSign, size: 20),
                          ),
                          validator: (val) => val == null || val.trim().isEmpty ? 'Required field' : null,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _loginPasswordController,
                          obscureText: _obscurePortalPassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(LucideIcons.lock, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePortalPassword ? LucideIcons.eyeOff : LucideIcons.eye, size: 18),
                              onPressed: () => setState(() => _obscurePortalPassword = !_obscurePortalPassword),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Required field';
                            if (val.length < 4) return 'Password too short';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<UserRole>(
                    initialValue: availableRoles.contains(_portalRole) ? _portalRole : availableRoles.first,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Portal Role',
                      prefixIcon: Icon(LucideIcons.layoutDashboard, size: 20),
                    ),
                    items: availableRoles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.displayName),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _portalRole = val);
                    },
                  ),
                  if (directorExists)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'A Director account already exists for this school.',
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                      ),
                    ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Contact Information'),
                  const SizedBox(height: 16),
                  _buildTextField(_phoneController, 'Phone Number', LucideIcons.phone),
                  const SizedBox(height: 16),
                  _buildTextField(_addressController, 'Residential Address', LucideIcons.mapPin),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.actionIndigo,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Complete Admissions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      ),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Required field';
        if (controller == _salaryController) {
          final parsed = double.tryParse(val.trim());
          if (parsed == null) return 'Enter a valid number';
          if (parsed < 0) return 'Invalid salary';
        }
        return null;
      },
    );
  }

  Widget _buildGenderSelector() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      decoration: const InputDecoration(labelText: 'Gender', prefixIcon: Icon(LucideIcons.users, size: 20)),
      items: const [
        DropdownMenuItem(value: 'male', child: Text('Male')),
        DropdownMenuItem(value: 'female', child: Text('Female')),
      ],
      onChanged: (val) => setState(() => _selectedGender = val!),
    );
  }

  Widget _buildDatePicker(String label, DateTime date, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(1900),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) onSelect(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: const Icon(LucideIcons.calendar, size: 20)),
        child: Text('${date.day}/${date.month}/${date.year}'),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final firstName = _firstNameController.text.trim();
        final lastName = _lastNameController.text.trim();
        final staffId = _staffIdController.text.trim();

        // 1. Staff credentials (entered by admin)
        final loginId = _loginIdController.text.trim();
        final password = _loginPasswordController.text;

        // 2. Create OR update user account so the credentials work immediately.
        final userId = await ref.read(authServiceProvider).createOrUpdateStaffUser(
          fullName: '$firstName $lastName',
          email: loginId,
          password: password,
          role: _portalRole,
          phoneNumber: _phoneController.text.trim(),
        );

        // 3. Create or update Staff record linked to user
        final staffService = ref.read(staffServiceProvider);
        final existingByUser = await staffService.getStaffByUserId(userId);
        final existingByStaffId = await staffService.getStaffByStaffId(staffId);
        final existing = existingByUser ?? existingByStaffId;

        final salary = double.parse(_salaryController.text.trim());
          final contractType = _contractTypeController.text.trim();
          final contractStartDate = _contractStartDate;
          final contractEndDate = _contractEndDate;
          final qualifications = _qualificationsController.text.trim();

        if (existing == null) {
          await staffService.createStaff(
            StaffCompanion.insert(
              userId: userId,
              staffId: staffId,
              firstName: firstName,
              lastName: lastName,
              gender: _selectedGender,
              dateOfBirth: _dob,
              phoneNumber: _phoneController.text.trim(),
              address: drift.Value(_addressController.text.trim()),
              position: _positionController.text.trim(),
              hireDate: _hireDate,
              baseSalary: salary,
                contractType: drift.Value(contractType.isNotEmpty ? contractType : null),
                contractStartDate: drift.Value(contractStartDate),
                contractEndDate: drift.Value(contractEndDate),
                qualifications: drift.Value(qualifications.isNotEmpty ? qualifications : null),
            ),
          );
        } else {
          await staffService.updateStaff(
            StaffCompanion(
              id: drift.Value(existing.id),
              userId: drift.Value(userId),
              staffId: drift.Value(staffId),
              firstName: drift.Value(firstName),
              lastName: drift.Value(lastName),
              gender: drift.Value(_selectedGender),
              dateOfBirth: drift.Value(_dob),
              phoneNumber: drift.Value(_phoneController.text.trim()),
              address: drift.Value(_addressController.text.trim()),
              position: drift.Value(_positionController.text.trim()),
              hireDate: drift.Value(_hireDate),
              baseSalary: drift.Value(salary),
                contractType: drift.Value(contractType.isNotEmpty ? contractType : null),
                contractStartDate: drift.Value(contractStartDate),
                contractEndDate: drift.Value(contractEndDate),
                qualifications: drift.Value(qualifications.isNotEmpty ? qualifications : null),
              updatedAt: drift.Value(DateTime.now()),
            ),
          );
        }

        // 4. Log Activity
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null) {
          await ref.read(activityServiceProvider).logActivity(
                actorUserId: currentUser.id,
                actorName: currentUser.fullName,
                actorRole: UserRole.values
                    .firstWhere(
                      (r) => r.name == currentUser.role,
                      orElse: () => UserRole.admin,
                    ),
                module: 'staff',
                actionType: 'staff_admitted',
                description:
                  'Admin admitted staff $firstName $lastName (ID: $staffId). Portal role: ${_portalRole.name}. Login: $loginId',
                isImportant: true,
              );
        }

        ref.invalidate(staffListProvider);
        
        if (mounted) {
          // Show credentials dialog
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(children: [Icon(LucideIcons.checkCircle, color: Colors.green), SizedBox(width: 8), Text('Staff Admitted')]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Staff member and User account created successfully.'),
                  const SizedBox(height: 16),
                  const Text('Login Credentials:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText('Username/Email: $loginId'),
                  const SizedBox(height: 4),
                  SelectableText('Password: $password'),
                  const SizedBox(height: 4),
                  SelectableText('Portal: ${_portalRole.displayName}'),
                  const SizedBox(height: 16),
                  const Text('Please share these with the staff member.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
              ],
            ),
          );
          if (mounted) context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }
}
