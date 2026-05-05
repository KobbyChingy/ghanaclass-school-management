import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:drift/drift.dart' show Value;

import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/communication_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/parents/parent_providers.dart';
import 'package:ghanaclass_school_management/features/teachers/teacher_providers.dart';

class TeacherMessagesScreen extends ConsumerStatefulWidget {
  const TeacherMessagesScreen({super.key});

  @override
  ConsumerState<TeacherMessagesScreen> createState() => _TeacherMessagesScreenState();
}

class _TeacherMessagesScreenState extends ConsumerState<TeacherMessagesScreen> {
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  int? _selectedStudentId;
  bool _sendInApp = true;
  bool _sendSms = false;
  bool _sendEmail = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teacher = ref.watch(currentUserProvider);
    if (teacher == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final studentsAsync = ref.watch(teacherAccessibleStudentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.inbox, size: 56, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                  const SizedBox(height: 14),
                  const Text('No students found.'),
                  const SizedBox(height: 6),
                  const Text('Your assignments determine which students you can message.', style: TextStyle(color: AppTheme.textMuted)),
                ],
              ),
            );
          }

          _selectedStudentId ??= students.first.id;
          final selectedStudent = students.firstWhere((s) => s.id == _selectedStudentId, orElse: () => students.first);

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(LucideIcons.user, color: AppTheme.actionIndigo),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            key: ValueKey<int?>(_selectedStudentId),
                            initialValue: _selectedStudentId,
                            decoration: const InputDecoration(
                              labelText: 'Student',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              for (final s in students)
                                DropdownMenuItem(
                                  value: s.id,
                                  child: Text('${s.firstName} ${s.lastName}'.trim(), overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: (id) {
                              if (id == null) return;
                              setState(() {
                                _selectedStudentId = id;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: _ThreadPanel(
                    teacherId: teacher.id,
                    student: selectedStudent,
                    subjectController: _subjectController,
                    messageController: _messageController,
                    sendInApp: _sendInApp,
                    sendSms: _sendSms,
                    sendEmail: _sendEmail,
                    onSendPrefsChanged: (inApp, sms, email) {
                      setState(() {
                        _sendInApp = inApp;
                        _sendSms = sms;
                        _sendEmail = email;
                      });
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _ThreadPanel extends ConsumerStatefulWidget {
  const _ThreadPanel({
    required this.teacherId,
    required this.student,
    required this.subjectController,
    required this.messageController,
    required this.sendInApp,
    required this.sendSms,
    required this.sendEmail,
    required this.onSendPrefsChanged,
  });

  final int teacherId;
  final Student student;
  final TextEditingController subjectController;
  final TextEditingController messageController;
  final bool sendInApp;
  final bool sendSms;
  final bool sendEmail;
  final void Function(bool inApp, bool sms, bool email) onSendPrefsChanged;

  @override
  ConsumerState<_ThreadPanel> createState() => _ThreadPanelState();
}

class _ThreadPanelState extends ConsumerState<_ThreadPanel> {
  int _reloadTick = 0;

  Future<void> _send() async {
    final parentService = ref.read(parentServiceProvider);
    final db = ref.read(databaseProvider);

    final subject = widget.subjectController.text.trim().isEmpty ? 'Message' : widget.subjectController.text.trim();
    final body = widget.messageController.text.trim();

    if (body.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is empty.'), backgroundColor: Colors.red),
      );
      return;
    }

    final parent = await parentService.getParentForStudent(widget.student.id);

    final guardianEmail = (widget.student.guardianEmail ?? '').trim();
    final guardianPhone = widget.student.guardianPhone.trim();

    final email = (parent?.email.trim().isNotEmpty == true) ? parent!.email.trim() : guardianEmail;
    final phone = (parent?.phoneNumber.trim().isNotEmpty == true) ? parent!.phoneNumber.trim() : guardianPhone;

    final wantInApp = widget.sendInApp;
    final wantSms = widget.sendSms;
    final wantEmail = widget.sendEmail;

    if (!wantInApp && !wantSms && !wantEmail) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select SMS, Email, or In-app.'), backgroundColor: Colors.red),
      );
      return;
    }

    // In-app message (requires ParentAccount)
    if (wantInApp) {
      if (parent == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No parent account found for this student. Use SMS/Email instead.'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        await parentService.sendMessageToParent(
          parentId: parent.id,
          studentId: widget.student.id,
          teacherId: widget.teacherId,
          subject: subject,
          message: body,
        );
      }
    }

    // SMS
    if (wantSms) {
      final smsGateway = await ref.read(smsServiceProvider.future);
      if (smsGateway == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS is not configured. Enable it in Settings.'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (phone.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number found for this parent/guardian.'), backgroundColor: Colors.red),
        );
      } else {
        final result = await smsGateway.sendSms(phoneNumber: phone, message: body);

        final notificationId = await db.into(db.notifications).insert(
              NotificationsCompanion.insert(
                recipientId: Value(parent?.id),
                recipientType: 'parent',
                channel: 'sms',
                subject: Value(subject),
                message: body,
                status: result.success ? 'sent' : 'failed',
                externalId: Value(result.messageId),
                sentAt: Value(result.success ? DateTime.now() : null),
                createdBy: widget.teacherId,
              ),
            );
        // Keep notificationId for audit; no further action required.
        // ignore: unused_local_variable
        final _ = notificationId;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    }

    // Email
    if (wantEmail) {
      final emailGateway = await ref.read(emailServiceProvider.future);
      if (emailGateway == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email is not configured. Enable it in Settings.'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (email.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No email address found for this parent/guardian.'), backgroundColor: Colors.red),
        );
      } else {
        final result = await emailGateway.sendBulkAnnouncement(
          recipients: [email],
          subject: subject,
          body: body,
        );

        final notificationId = await db.into(db.notifications).insert(
              NotificationsCompanion.insert(
                recipientId: Value(parent?.id),
                recipientType: 'parent',
                channel: 'email',
                subject: Value(subject),
                message: body,
                status: result.success ? 'sent' : 'failed',
                sentAt: Value(result.success ? DateTime.now() : null),
                createdBy: widget.teacherId,
              ),
            );
        // ignore: unused_local_variable
        final _ = notificationId;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );
      }
    }

    widget.messageController.clear();

    setState(() {
      _reloadTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final parentService = ref.watch(parentServiceProvider);

    return FutureBuilder<ParentAccount?>(
      future: parentService.getParentForStudent(widget.student.id),
      builder: (context, parentSnap) {
        final parent = parentSnap.data;

        final email = (parent?.email.trim().isNotEmpty == true)
            ? parent!.email.trim()
            : (widget.student.guardianEmail ?? '').trim();
        final phone = (parent?.phoneNumber.trim().isNotEmpty == true)
            ? parent!.phoneNumber.trim()
            : widget.student.guardianPhone.trim();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.user, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            parent != null ? parent.parentName : widget.student.guardianName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (parent == null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.authorityYellow.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.authorityYellow.withValues(alpha: 0.25)),
                            ),
                            child: const Text('Guardian', style: TextStyle(color: AppTheme.authorityYellow, fontSize: 12, fontWeight: FontWeight.w600)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
                            ),
                            child: const Text('Parent Account', style: TextStyle(color: AppTheme.success, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _pill(LucideIcons.phone, phone.isEmpty ? '—' : phone),
                        _pill(LucideIcons.atSign, email.isEmpty ? '—' : email),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('In-app'),
                            subtitle: Text(parent == null ? 'Requires parent account' : 'Stores in inbox'),
                            value: widget.sendInApp,
                            onChanged: (v) => widget.onSendPrefsChanged(v ?? false, widget.sendSms, widget.sendEmail),
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('SMS'),
                            value: widget.sendSms,
                            onChanged: (v) => widget.onSendPrefsChanged(widget.sendInApp, v ?? false, widget.sendEmail),
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Email'),
                            value: widget.sendEmail,
                            onChanged: (v) => widget.onSendPrefsChanged(widget.sendInApp, widget.sendSms, v ?? false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: parent == null
                  ? _EmptyThreadHint(student: widget.student)
                  : _ThreadList(
                      teacherId: widget.teacherId,
                      parentId: parent.id,
                      studentId: widget.student.id,
                      reloadTick: _reloadTick,
                    ),
            ),

            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      controller: widget.subjectController,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: widget.messageController,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        border: OutlineInputBorder(),
                      ),
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(LucideIcons.send, size: 18),
                        label: const Text('Send'),
                        onPressed: _send,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(text, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _EmptyThreadHint extends StatelessWidget {
  const _EmptyThreadHint({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.messageSquare, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                const Text('No parent account found'),
                const SizedBox(height: 6),
                Text(
                  'You can still contact the guardian via SMS/Email using the checkboxes above.\n\nStudent: ${student.firstName} ${student.lastName}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadList extends ConsumerWidget {
  const _ThreadList({
    required this.teacherId,
    required this.parentId,
    required this.studentId,
    required this.reloadTick,
  });

  final int teacherId;
  final int parentId;
  final int studentId;
  final int reloadTick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentService = ref.watch(parentServiceProvider);

    return FutureBuilder<List<ParentMessage>>(
      future: parentService.getTeacherParentThread(parentId: parentId, studentId: studentId, teacherId: teacherId),
      builder: (context, snap) {
        // tie to reloadTick
        // ignore: unused_local_variable
        final _ = reloadTick;

        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }

        final messages = snap.data ?? const [];
        if (messages.isEmpty) {
          return const Center(
            child: Text('No messages yet.', style: TextStyle(color: AppTheme.textMuted)),
          );
        }

        // Mark unread parent messages as read (best-effort)
        parentService.markThreadAsReadForTeacher(parentId: parentId, studentId: studentId, teacherId: teacherId);

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final m = messages[index];
            final fromTeacher = m.senderType == 'teacher';

            return Align(
              alignment: fromTeacher ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: fromTeacher ? AppTheme.actionIndigo.withValues(alpha: 0.10) : AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: fromTeacher ? AppTheme.actionIndigo.withValues(alpha: 0.20) : AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(m.message),
                    const SizedBox(height: 8),
                    Text(
                      _fmt(m.sentAt),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _fmt(DateTime value) {
    final local = value.toLocal();
    final yyyy = local.year.toString().padLeft(4, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mi = local.minute.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd $hh:$mi';
  }
}
