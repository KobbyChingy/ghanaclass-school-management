import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/features/id_cards/id_card_design.dart';
import 'package:ghanaclass_school_management/features/id_cards/id_cards_providers.dart';
import 'package:ghanaclass_school_management/features/students/student_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'student_pdf_service.dart';
import 'package:ghanaclass_school_management/shared/printing/pdf_preview_screen.dart';
import 'package:ghanaclass_school_management/features/finance/finance_providers.dart';
import 'package:ghanaclass_school_management/features/assessments/assessment_providers.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'package:ghanaclass_school_management/features/academic/timetable_model.dart';
import 'package:ghanaclass_school_management/features/academic/student_timetable_widget.dart';
import 'student_edit_screen.dart';
import 'package:ghanaclass_school_management/features/assessments/student_report_screen.dart';

class StudentProfileScreen extends ConsumerWidget {
  final int studentId;

  const StudentProfileScreen({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(studentProfileProvider(studentId));
    final data = profileAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        actions: data == null ? [] : [
          IconButton(
            icon: const Icon(LucideIcons.edit),
            onPressed: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => StudentEditScreen(
                  student: data['student'] as Student,
                  healthRecord: data['health'] as HealthRecord?,
                ))
              ).then((_) => ref.refresh(studentProfileProvider(studentId)));
            },
            tooltip: 'Edit Profile',
          ),
          IconButton(
            icon: const Icon(LucideIcons.printer),
            onPressed: () async {
              final student = data['student'] as Student;
              final health = data['health'] as HealthRecord?;
              final history = data['history'] as List<AcademicHistoryData>;

              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfPreviewScreen(
                    title: 'Student Profile',
                    pdfFileName: 'student-profile-${student.studentId}.pdf',
                    buildPdf: (format) async {
                      final schoolInfo = await ref.read(institutionalIdentityProvider.future);
                      return StudentPdfService().buildProfilePdf(
                        student,
                        health,
                        history,
                        schoolInfo: schoolInfo,
                        pageFormat: format,
                      );
                    },
                  ),
                ),
              );
            },
            tooltip: 'Print Profile',
          ),
          IconButton(
            icon: const Icon(LucideIcons.contact),
            onPressed: () async {
              final student = data['student'] as Student;
              const style = IdCardStyle();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfPreviewScreen(
                    title: 'Student ID Card',
                    pdfFileName: 'student-id-card-${student.studentId}.pdf',
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    buildPdf: (_) => ref.read(idCardPdfServiceProvider).buildStudentIdCardsPdf(studentIds: [student.id], style: style),
                  ),
                ),
              );
            },
            tooltip: 'Generate ID Card',
          ),
          IconButton(
            icon: const Icon(LucideIcons.fileText),
            onPressed: () => _generateTerminalReport(context, ref, data['student'] as Student),
            tooltip: 'Terminal Report',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: profileAsync.when(
        data: (data) => _ProfileContent(data: data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _generateTerminalReport(BuildContext context, WidgetRef ref, Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentReportScreen(studentId: student.id),
      ),
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;

  const _ProfileContent({required this.data});

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
     _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openFirstCertificateInExplorer(String? certificatesPath) async {
    final paths = (certificatesPath ?? '')
        .split(';')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paths.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No certificates attached.')),
      );
      return;
    }

    final first = paths.first;
    try {
      final file = File(first);
      final directory = Directory(first);

      if (await file.exists()) {
        await Process.run('explorer.exe', ['/select,', first]);
        return;
      }

      if (await directory.exists()) {
        await Process.run('explorer.exe', [first]);
        return;
      }

      // Fallback: try opening the parent folder.
      final parent = file.parent;
      if (await parent.exists()) {
        await Process.run('explorer.exe', [parent.path]);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certificate file not found on this computer.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open certificates in Explorer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = widget.data['student'] as Student;
    final health = widget.data['health'] as HealthRecord?;
    final history = widget.data['history'] as List<AcademicHistoryData>;

    return Column(
      children: [
        // Header Profile Card
        _buildProfileHeader(student),
        // Tabs
        Container(
          color: AppTheme.surface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AppTheme.actionIndigo,
            labelColor: AppTheme.actionIndigo,
            unselectedLabelColor: AppTheme.textMuted,
            tabs: const [
              Tab(text: 'Personal Details'),
              Tab(text: 'Academics'),
              Tab(text: 'Health Records'),
              Tab(text: 'Performance'),
              Tab(text: 'Timetable'),
            ],
          ),
        ),
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildPersonalTab(student),
              _buildAcademicTab(student.id, history),
              _buildHealthTab(health),
              _buildPerformanceTab(student.id),
              _buildTimetableTab(student),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimetableTab(Student student) {
    // Show all subjects for the student's class in the timetable grid
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Consumer(
        builder: (context, ref, _) {
          final offeredAsync = ref.watch(studentOfferedSubjectsProvider(student.id));
          return offeredAsync.when(
            data: (subjects) {
              if (subjects.isEmpty) {
                return const Center(child: Text('No timetable available.'));
              }
              // For demo: distribute subjects across days/periods with placeholders
              final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];
              final periods = [
                const TimeOfDay(hour: 8, minute: 0),
                const TimeOfDay(hour: 10, minute: 0),
                const TimeOfDay(hour: 12, minute: 0),
              ];
              List<TimetableEntry> entries = [];
              int i = 0;
              for (final subject in subjects) {
                final day = days[i % days.length];
                final period = periods[(i ~/ days.length) % periods.length];
                entries.add(TimetableEntry(
                  subject: subject.subjectName,
                  teacher: 'TBD',
                  className: student.classId?.toString() ?? '',
                  startTime: period,
                  endTime: TimeOfDay(hour: period.hour + 1, minute: period.minute),
                  day: day,
                ));
                i++;
              }
              final timetable = WeeklyTimetable(entries: entries);
              return StudentTimetableWidget(timetable: timetable);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error loading timetable: $e')),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(Student student) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppTheme.surfaceMuted,
            backgroundImage: student.photoPath != null ? NetworkImage(student.photoPath!) : null,
            child: student.photoPath == null 
                ? const Icon(LucideIcons.user, size: 40, color: AppTheme.textMuted)
                : null,
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${student.firstName} ${student.lastName}',
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    _buildStatusChip(student.status),
                  ],
                ),
                if (student.position != null && student.position!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    student.position!,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.actionIndigo),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Student ID: ${student.studentId} | Adm No: ${student.admissionNumber}',
                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Resident Address: ${student.address ?? "Not Provided"}',
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 32),
          // Financial Summary Card
          Consumer(
            builder: (context, ref, _) {
              final balanceAsync = ref.watch(studentBalanceProvider(student.id));
              return balanceAsync.when(
                data: (balance) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('BALANCE DUE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                      Text(
                        'GH₵ ${balance['balance']?.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24, 
                          fontWeight: FontWeight.bold, 
                          color: (balance['balance'] ?? 0) > 0 ? AppTheme.error : AppTheme.success
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Paid: GH₵ ${balance['totalPaid']?.toStringAsFixed(2)} / GH₵ ${balance['totalFees']?.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 2)),
                error: (err, _) => const Icon(LucideIcons.alertTriangle, color: AppTheme.error),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isSuccess = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: (isSuccess ? AppTheme.success : AppTheme.textMuted).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: isSuccess ? AppTheme.success : AppTheme.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPersonalTab(Student student) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        _buildInfoGrid('Basic Information', [
          _InfoItem('Full Name', '${student.firstName} ${student.lastName} ${student.otherNames ?? ""}'),
          _InfoItem('Gender', student.gender.toUpperCase()),
          _InfoItem('Date of Birth', DateFormat('dd MMM yyyy').format(student.dateOfBirth)),
          _InfoItem('Admission Date', DateFormat('dd MMM yyyy').format(student.admissionDate)),
          _InfoItem('Current Class', 'JHS 1'), // Placeholder
          _InfoItem('School Fees', 'GH₵ ${student.enrolledFees.toStringAsFixed(2)}'),
        ]),
        const SizedBox(height: 32),
        _buildInfoGrid('Guardian Information', [
          _InfoItem('Guardian Name', student.guardianName),
          _InfoItem('Relationship', student.guardianRelationship),
          _InfoItem('Phone Number', student.guardianPhone),
          _InfoItem('Email Address', student.guardianEmail ?? 'N/A'),
          _InfoItem('Occupation', student.guardianOccupation ?? 'N/A'),
          _InfoItem('Residential Address', student.guardianAddress ?? 'N/A'),
        ]),
      ],
    );
  }

  Widget _buildAcademicTab(int studentId, List<AcademicHistoryData> history) {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        _buildSubjectsCard(studentId),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Previous Academic Records',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => _showAddAcademicHistoryDialog(studentId),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (history.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('No previous school records found.'),
            ),
          )
        else
          ...history.map((record) => Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  leading: const Icon(LucideIcons.school),
                  title: Text(record.formerSchool),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Last Class: ${record.highestClassReached ?? "N/A"}'),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final certCount = (record.certificatesPath ?? '')
                              .split(';')
                              .map((p) => p.trim())
                              .where((p) => p.isNotEmpty)
                              .length;

                          final label = certCount == 0 ? 'Certificates: None' : 'Certificates: $certCount file(s)';

                          if (certCount == 0) {
                            return Text(
                              label,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            );
                          }

                          return InkWell(
                            onTap: () => _openFirstCertificateInExplorer(record.certificatesPath),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.actionIndigo,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') {
                        _showEditAcademicHistoryDialog(studentId, record);
                      } else if (v == 'delete') {
                        _confirmDeleteAcademicHistory(studentId, record);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  Widget _buildSubjectsCard(int studentId) {
    final offeredAsync = ref.watch(studentOfferedSubjectsProvider(studentId));
    final enrolledAsync = ref.watch(studentEnrolledSubjectsProvider(studentId));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Subjects',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showEditSubjectsDialog(studentId),
                  icon: const Icon(LucideIcons.slidersHorizontal, size: 18),
                  label: const Text('Edit Subjects'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Students are automatically enrolled into all subjects offered by their class. You can remove/add subjects here.',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            offeredAsync.when(
              data: (offered) {
                if (offered.isEmpty) {
                  return const Text('No subjects offered for this class yet.');
                }

                final enrolledIds = enrolledAsync.asData?.value.map((s) => s.id).toSet() ?? <int>{};

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: offered.map((s) {
                    final isOn = enrolledIds.contains(s.id);
                    return Chip(
                      label: Text(s.subjectName),
                      backgroundColor: (isOn ? AppTheme.success : AppTheme.surfaceMuted).withValues(alpha: 0.12),
                      side: BorderSide(color: isOn ? AppTheme.success.withValues(alpha: 0.5) : AppTheme.border),
                    );
                  }).toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => Text('Error loading subjects: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSubjectsDialog(int studentId) async {
    final offered = await ref.read(studentOfferedSubjectsProvider(studentId).future);
    if (offered.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No subjects offered for this class yet.')),
      );
      return;
    }

    final enrolled = await ref.read(studentEnrolledSubjectsProvider(studentId).future);
    final selectedIds = enrolled.map((s) => s.id).toSet();

    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit Subjects'),
          content: SizedBox(
            width: 520,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: offered.length,
              itemBuilder: (context, idx) {
                final s = offered[idx];
                final checked = selectedIds.contains(s.id);
                return CheckboxListTile(
                  value: checked,
                  title: Text(s.subjectName),
                  subtitle: Text(s.subjectCode),
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        selectedIds.add(s.id);
                      } else {
                        selectedIds.remove(s.id);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    await ref.read(studentServiceProvider).updateStudentSubjectSelections(
          studentId: studentId,
          activeSubjectIds: selectedIds,
        );

    ref.invalidate(studentEnrolledSubjectsProvider(studentId));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subjects updated.')),
      );
    }
  }

  Future<void> _showAddAcademicHistoryDialog(int studentId) async {
    final formerSchoolController = TextEditingController();
    final highestClassController = TextEditingController();
    final reasonController = TextEditingController();
    final scoresController = TextEditingController();
    final selectedCertificates = <String>[];

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickCertificates() async {
            final result = await FilePicker.platform.pickFiles(
              allowMultiple: true,
              type: FileType.custom,
              allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
            );
            if (result == null) return;

            final pickedPaths = result.files.map((f) => f.path).whereType<String>().where((p) => p.trim().isNotEmpty);
            if (pickedPaths.isEmpty) return;

            setState(() {
              for (final p in pickedPaths) {
                if (!selectedCertificates.contains(p)) {
                  selectedCertificates.add(p);
                }
              }
            });
          }

          return AlertDialog(
            title: const Text('Add Academic Record'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: formerSchoolController,
                    decoration: const InputDecoration(labelText: 'Former School *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: highestClassController,
                    decoration: const InputDecoration(labelText: 'Highest Class Reached'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Reason For Leaving'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scoresController,
                    decoration: const InputDecoration(labelText: 'Assessment Scores (optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: pickCertificates,
                        icon: const Icon(LucideIcons.upload, size: 18),
                        label: const Text('Upload certificates'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedCertificates.isEmpty
                              ? 'No certificates selected'
                              : '${selectedCertificates.length} file(s) selected',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (selectedCertificates.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedCertificates.map((path) {
                          final name = File(path).uri.pathSegments.isNotEmpty ? File(path).uri.pathSegments.last : path;
                          return InputChip(
                            label: Text(name, overflow: TextOverflow.ellipsis),
                            onDeleted: () => setState(() => selectedCertificates.remove(path)),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          );
        },
      ),
    );

    if (saved != true) return;
    final formerSchool = formerSchoolController.text.trim();
    if (formerSchool.isEmpty) return;

    try {
      final service = ref.read(studentServiceProvider);
      await service.addAcademicHistoryForStudent(
        studentLocalId: studentId,
        formerSchool: formerSchool,
        highestClassReached: highestClassController.text,
        reasonForLeaving: reasonController.text,
        assessmentScores: scoresController.text,
        certificatesPath: selectedCertificates.isEmpty ? null : selectedCertificates.join(';'),
      );
      ref.invalidate(studentProfileProvider(studentId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Academic record added'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEditAcademicHistoryDialog(int studentId, AcademicHistoryData record) async {
    final formerSchoolController = TextEditingController(text: record.formerSchool);
    final highestClassController = TextEditingController(text: record.highestClassReached);
    final reasonController = TextEditingController(text: record.reasonForLeaving);
    final scoresController = TextEditingController(text: record.assessmentScores);
    final selectedCertificates = (record.certificatesPath ?? '')
        .split(';')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickCertificates() async {
            final result = await FilePicker.platform.pickFiles(
              allowMultiple: true,
              type: FileType.custom,
              allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
            );
            if (result == null) return;

            final pickedPaths = result.files.map((f) => f.path).whereType<String>().where((p) => p.trim().isNotEmpty);
            if (pickedPaths.isEmpty) return;

            setState(() {
              for (final p in pickedPaths) {
                if (!selectedCertificates.contains(p)) {
                  selectedCertificates.add(p);
                }
              }
            });
          }

          return AlertDialog(
            title: const Text('Edit Academic Record'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: formerSchoolController,
                    decoration: const InputDecoration(labelText: 'Former School *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: highestClassController,
                    decoration: const InputDecoration(labelText: 'Highest Class Reached'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(labelText: 'Reason For Leaving'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: scoresController,
                    decoration: const InputDecoration(labelText: 'Assessment Scores (optional)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: pickCertificates,
                        icon: const Icon(LucideIcons.upload, size: 18),
                        label: const Text('Upload certificates'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedCertificates.isEmpty
                              ? 'No certificates selected'
                              : '${selectedCertificates.length} file(s) selected',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (selectedCertificates.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedCertificates.map((path) {
                          final name = File(path).uri.pathSegments.isNotEmpty ? File(path).uri.pathSegments.last : path;
                          return InputChip(
                            label: Text(name, overflow: TextOverflow.ellipsis),
                            onDeleted: () => setState(() => selectedCertificates.remove(path)),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
            ],
          );
        },
      ),
    );

    if (saved != true) return;
    final formerSchool = formerSchoolController.text.trim();
    if (formerSchool.isEmpty) return;

    try {
      final service = ref.read(studentServiceProvider);
      await service.updateAcademicHistory(
        existing: record,
        formerSchool: formerSchool,
        highestClassReached: highestClassController.text,
        reasonForLeaving: reasonController.text,
        assessmentScores: scoresController.text,
        certificatesPath: selectedCertificates.isEmpty ? null : selectedCertificates.join(';'),
      );
      ref.invalidate(studentProfileProvider(studentId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Academic record updated'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteAcademicHistory(int studentId, AcademicHistoryData record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete academic record?'),
        content: Text('Remove ${record.formerSchool}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ref.read(studentServiceProvider);
      await service.deleteAcademicHistory(record);
      ref.invalidate(studentProfileProvider(studentId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Academic record deleted'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildHealthTab(HealthRecord? health) {
    if (health == null) {
      return const Center(child: Text('No health records on file.'));
    }
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        _buildInfoGrid('Vitals & Risks', [
          _InfoItem('Blood Group', health.bloodGroup ?? 'Unknown'),
          _InfoItem('Allergies', health.allergies ?? 'None Reported'),
          _InfoItem('Medications', health.medications ?? 'None'),
          _InfoItem('Vaccinations', health.vaccinations ?? 'Up to date'),
          _InfoItem('Physical Disability', health.physicalDisability ?? 'None'),
        ]),
        const SizedBox(height: 32),
        const Text('Emergency Instructions', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: Text(health.emergencyInstructions ?? 'No specific instructions provided.'),
        ),
      ],
    );
  }


  Widget _buildPerformanceTab(int studentId) {
    return Consumer(
      builder: (context, ref, _) {
        final resultsAsync = ref.watch(studentTermResultsProvider(studentId));
        final subjectsAsync = ref.watch(subjectsProvider);

        return resultsAsync.when(
          data: (results) {
            if (results.isEmpty) {
              return const Center(child: Text('No performance records available yet.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(32),
              itemCount: results.length,
              itemBuilder: (context, index) {
                final res = results[index];
                final subjectName = subjectsAsync.maybeWhen(
                      data: (list) {
                        for (final s in list) {
                          if (s.id == res.subjectId) return s.subjectName;
                        }
                        return null;
                      },
                      orElse: () => null,
                    ) ??
                    'Subject ${res.subjectId}';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(subjectName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.actionIndigo.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('Grade: ${res.grade ?? "N/A"}', style: const TextStyle(color: AppTheme.actionIndigo, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildScoreInfo('CA Score', res.totalCaScore.toStringAsFixed(1)),
                            const SizedBox(width: 32),
                            _buildScoreInfo('Exam Score', res.examScore.toStringAsFixed(1)),
                            const SizedBox(width: 32),
                            _buildScoreInfo('Total (100)', res.totalScore.toStringAsFixed(1)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
        );
      },
    );
  }

  Widget _buildScoreInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildInfoGrid(String title, List<_InfoItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.actionIndigo)),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 3,
            crossAxisSpacing: 24,
            mainAxisSpacing: 16,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(items[index].label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(items[index].value, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  _InfoItem(this.label, this.value);
}
