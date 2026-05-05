import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';
import 'package:ghanaclass_school_management/features/students/student_providers.dart';

class StudentAdmissionScreen extends ConsumerStatefulWidget {
  const StudentAdmissionScreen({super.key});

  @override
  ConsumerState<StudentAdmissionScreen> createState() => _StudentAdmissionScreenState();
}

class _StudentAdmissionScreenState extends ConsumerState<StudentAdmissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  
  // Personal Info
  final _studentIdController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _otherNamesController = TextEditingController();
  String _gender = 'male';
  DateTime? _dob;
  String? _photoPath;
  
  // Academic Info
  String _selectedClass = 'JHS 1';
  final _feesController = TextEditingController();
  final _academicRecordsController = TextEditingController();
  final List<String> _academicCertificates = <String>[];
  
  // Health records
  final _bloodGroupController = TextEditingController();
  final _allergiesController = TextEditingController();
  final _medicalHistoryController = TextEditingController();
  
  // Guardian Info
  final _guardianNameController = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _guardianEmailController = TextEditingController();
  final _guardianOccupationController = TextEditingController();
  final _guardianRelationshipController = TextEditingController();
  final _guardianAddressController = TextEditingController();

  // Student services
  bool _eatsCanteen = false;
  bool _takesSchoolBus = false;
  
  bool _isLoading = false;

  final List<String> _classes = [
    'Creche', 'Nursery 1', 'Nursery 2', 'KG 1', 'KG 2',
    'Class 1', 'Class 2', 'Class 3', 'Class 4', 'Class 5', 'Class 6',
    'JHS 1', 'JHS 2', 'JHS 3',
  ];

  @override
  void dispose() {
    _studentIdController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _otherNamesController.dispose();
    _feesController.dispose();
    _academicRecordsController.dispose();
    _bloodGroupController.dispose();
    _allergiesController.dispose();
    _medicalHistoryController.dispose();
    _guardianNameController.dispose();
    _guardianPhoneController.dispose();
    _guardianEmailController.dispose();
    _guardianOccupationController.dispose();
    _guardianRelationshipController.dispose();
    _guardianAddressController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickAcademicCertificates() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );

    if (result == null) return;

    final pickedPaths = result.files.map((f) => f.path).whereType<String>().where((p) => p.trim().isNotEmpty);
    if (pickedPaths.isEmpty) return;

    setState(() {
      for (final path in pickedPaths) {
        if (!_academicCertificates.contains(path)) {
          _academicCertificates.add(path);
        }
      }
    });
  }

  Future<void> _pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() => _photoPath = result.files.single.path);
    }
  }

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      return;
    }

    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Date of Birth'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final studentId = _studentIdController.text.trim();
      final admissionNo = 'ADM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      final studentService = ref.read(studentServiceProvider);

      if (await studentService.studentIdExists(studentId)) {
        throw Exception('Student ID "$studentId" already exists. Please enter a unique student ID.');
      }

      // Ensure the selected class exists and store its id.
      final classId = await studentService.ensureClassIdForName(
        _selectedClass,
        academicYear: DateTime.now().year,
      );
      
      final studentEntry = StudentsCompanion(
        studentId: drift.Value(studentId),
        admissionNumber: drift.Value(admissionNo),
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
        classId: drift.Value<int?>(classId),
        admissionDate: drift.Value(DateTime.now()),
        enrolledFees: drift.Value(double.tryParse(_feesController.text) ?? 0.0),
        status: const drift.Value('active'),
      );

      final healthEntry = HealthRecordsCompanion(
        bloodGroup: drift.Value(_bloodGroupController.text.trim()),
        allergies: drift.Value(_allergiesController.text.trim()),
        medications: drift.Value(_medicalHistoryController.text.trim()),
      );

      final academicSummary = _academicRecordsController.text.trim();
      final academicCertificates = _academicCertificates.join(';');
      final academicHistory = (academicSummary.isNotEmpty || _academicCertificates.isNotEmpty)
          ? <AcademicHistoryCompanion>[
              AcademicHistoryCompanion(
                formerSchool: const drift.Value('Not specified'),
                assessmentScores: drift.Value(academicSummary.isNotEmpty ? academicSummary : null),
                certificatesPath: drift.Value(academicCertificates.isNotEmpty ? academicCertificates : null),
              ),
            ]
          : null;

      await studentService.admitStudent(
        student: studentEntry,
        health: healthEntry,
        history: academicHistory,
      );

      ref.invalidate(studentsListProvider);

      // Log activity for admin dashboard / notifications
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
              module: 'students',
              actionType: 'student_admitted',
              description:
                  '${currentUser.role} admitted ${studentEntry.firstName.value} ${studentEntry.lastName.value} (ID: $studentId) into $_selectedClass',
              isImportant: true,
            );
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(LucideIcons.checkCircle, color: Colors.green),
                SizedBox(width: 10),
                Text('Admission Successful'),
              ],
            ),
            content: Text('Student ${studentEntry.firstName.value} ${studentEntry.lastName.value} has been enrolled.\nStudent ID: $studentId'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  context.go('/students'); // Go to registry
                },
                child: const Text('Go to Student Registry'),
              ),
            ],
          ),
        );
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Admission Form'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionHeader('Personal Information', LucideIcons.user),
                        const SizedBox(height: 24),
                        _buildPersonalInfoSection(),
                        const SizedBox(height: 40),
                        
                        _buildSectionHeader('Academic Details', LucideIcons.graduationCap),
                        const SizedBox(height: 24),
                        _buildAcademicSection(),
                        const SizedBox(height: 40),

                        _buildSectionHeader('Guardian Information', LucideIcons.users),
                        const SizedBox(height: 24),
                        _buildGuardianSection(),
                        const SizedBox(height: 40),

                        _buildSectionHeader('Health Records', LucideIcons.heartPulse),
                        const SizedBox(height: 24),
                        _buildHealthSection(),
                        const SizedBox(height: 48),

                        ElevatedButton.icon(
                          onPressed: _handleSubmit,
                          icon: const Icon(LucideIcons.userPlus),
                          label: const Text('Enroll Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.actionIndigo,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 40),
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
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.actionIndigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.actionIndigo, size: 20),
        ),
        const SizedBox(width: 12),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textMain)),
        const SizedBox(width: 16),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Photo Upload
        GestureDetector(
          onTap: _pickPhoto,
          child: Container(
            width: 150,
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.border),
            ),
            child: _photoPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_photoPath!), fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.camera, size: 40, color: AppTheme.textMuted),
                      SizedBox(height: 8),
                      Text('Upload Photo', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
          ),
        ),
        const SizedBox(width: 32),
        // Personal Fields
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _studentIdController,
                      decoration: const InputDecoration(
                        labelText: 'Student ID *',
                        hintText: 'Enter student ID',
                      ),
                      textCapitalization: TextCapitalization.characters,
                      validator: (value) {
                        final normalized = value?.trim() ?? '';
                        if (normalized.isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name *'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name *'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _otherNamesController,
                decoration: const InputDecoration(labelText: 'Other Names'),
              ),
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
                          initialDate: DateTime.now().subtract(const Duration(days: 365 * 6)),
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Age'),
                      child: Text(_dob == null ? '--' : _calculateAge(_dob!).toString()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAcademicSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedClass,
                decoration: const InputDecoration(labelText: 'Admission Class *'),
                items: _classes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedClass = v!),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _feesController,
                decoration: const InputDecoration(
                  labelText: 'School Fees *',
                  prefixText: 'GH₵ ',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _academicRecordsController,
          decoration: const InputDecoration(
            labelText: 'Former School Assessments/Academic Records',
            hintText: 'Enter a short summary and attach certificates (optional)',
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _pickAcademicCertificates,
              icon: const Icon(LucideIcons.upload, size: 18),
              label: const Text('Upload certificates'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _academicCertificates.isEmpty
                    ? 'No certificates selected'
                    : '${_academicCertificates.length} file(s) selected',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (_academicCertificates.isNotEmpty) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _academicCertificates.map((path) {
                final name = File(path).uri.pathSegments.isNotEmpty
                    ? File(path).uri.pathSegments.last
                    : path;
                return InputChip(
                  label: Text(name, overflow: TextOverflow.ellipsis),
                  onDeleted: () => setState(() => _academicCertificates.remove(path)),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 10),
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
    );
  }

  Widget _buildGuardianSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _guardianNameController,
                decoration: const InputDecoration(labelText: 'Guardian Full Name *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _guardianPhoneController,
                decoration: const InputDecoration(labelText: 'Guardian Phone *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _guardianEmailController,
                decoration: const InputDecoration(labelText: 'Guardian Email'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _guardianOccupationController,
                decoration: const InputDecoration(labelText: 'Guardian Occupation *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _guardianRelationshipController,
                decoration: const InputDecoration(labelText: 'Relationship * (e.g., Father, Mother)'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _guardianAddressController,
                decoration: const InputDecoration(labelText: 'Guardian Residential Address *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHealthSection() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _bloodGroupController,
            decoration: const InputDecoration(labelText: 'Blood Group'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _allergiesController,
            decoration: const InputDecoration(labelText: 'Allergies'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: TextFormField(
            controller: _medicalHistoryController,
            decoration: const InputDecoration(labelText: 'Medical History / Chronic Conditions'),
          ),
        ),
      ],
    );
  }
}
