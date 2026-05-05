import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart' as appdb;
import 'package:ghanaclass_school_management/core/providers/communication_providers.dart';
import 'package:ghanaclass_school_management/core/services/email_service.dart';
import 'package:ghanaclass_school_management/core/services/sms_service.dart';
import 'package:ghanaclass_school_management/core/services/staff_messaging_service.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

enum CommunicationAudience { parents, staff }

enum CommunicationChannel { sms, email, phone, inApp }

final _schoolClassesProvider = FutureProvider<List<appdb.SchoolClassesData>>((ref) async {
  final database = ref.watch(databaseProvider);
  final rows = await (database.select(database.schoolClasses)
        ..orderBy([
          (t) => drift.OrderingTerm(expression: t.className),
        ]))
      .get();
  return rows;
});

class CommunicationScreen extends ConsumerWidget {
  const CommunicationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Communication'),
          backgroundColor: AppColors.primary,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Parents'),
              Tab(text: 'Staff'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CommunicationAudienceTab(audience: CommunicationAudience.parents),
            _CommunicationAudienceTab(audience: CommunicationAudience.staff),
          ],
        ),
      ),
    );
  }
}

class _CommunicationAudienceTab extends ConsumerStatefulWidget {
  const _CommunicationAudienceTab({required this.audience});

  final CommunicationAudience audience;

  @override
  ConsumerState<_CommunicationAudienceTab> createState() => _CommunicationAudienceTabState();
}

class _CommunicationAudienceTabState extends ConsumerState<_CommunicationAudienceTab> {
  final _messageController = TextEditingController();
  final _emailSubjectController = TextEditingController();
  final _contactSearchController = TextEditingController();

  Future<List<_PhoneContact>>? _phoneContactsFuture;

  CommunicationChannel _channel = CommunicationChannel.sms;
  String _selectedTemplate = 'custom';
  String _recipientFilter = 'all';
  int? _selectedClassId;
  int? _selectedParentAccountId;
  int? _selectedStaffUserId;
  bool _isSending = false;

  final Set<String> _selectedStaffRoles = <String>{};

  static const Map<String, String> _staffRoleLabels = {
    'admin': 'Admins',
    'secretary': 'Secretaries',
    'teacher': 'Teachers',
    'accountant': 'Accountants',
    'security': 'Security',
    'ictlab': 'ICT Lab',
    'sciencelab': 'Science Lab',
    'library': 'Library',
    'shop': 'Shop',
    'infirmary': 'Infirmary',
  };

  /// Best combinations (recommended):
  /// - Management: Admin + Secretary
  /// - Teaching: Teachers
  /// - Finance: Accountants
  /// - Operations: Security + Labs + Library + Shop + Infirmary
  /// - Non-Teaching: Finance + Operations + Secretaries
  List<String>? _staffRolesForFilter() {
    if (widget.audience != CommunicationAudience.staff) return null;

    return switch (_recipientFilter) {
      'management' => const ['admin', 'secretary'],
      'teaching' => const ['teacher'],
      'finance' => const ['accountant'],
      'operations' => const ['security', 'ictlab', 'sciencelab', 'library', 'shop', 'infirmary'],
      'non_teaching' => const [
          'accountant',
          'secretary',
          'security',
          'ictlab',
          'sciencelab',
          'library',
          'shop',
          'infirmary',
        ],
      'custom_roles' => _selectedStaffRoles.toList(growable: false),
      _ => null,
    };
  }

  Map<String, String> get _templates {
    if (widget.audience == CommunicationAudience.staff) {
      return const {
        'custom': 'Custom Message',
        'staff_notice': 'Staff Notice',
        'meeting': 'Meeting Reminder',
        'general_announcement': 'General Announcement',
      };
    }
    return const {
      'custom': 'Custom Message',
      'fee_reminder': 'Fee Reminder',
      'exam_notice': 'Exam Notice',
      'attendance_alert': 'Attendance Alert',
      'general_announcement': 'General Announcement',
    };
  }

  String _schoolNameFallback() {
    final identityAsync = ref.read(institutionalIdentityProvider);
    final name = identityAsync.maybeWhen(
      data: (identity) => identity?.schoolName.trim(),
      orElse: () => null,
    );
    if (name == null || name.isEmpty) return 'School';
    return name;
  }

  @override
  void initState() {
    super.initState();
    _phoneContactsFuture = _resolvePhoneContacts();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _emailSubjectController.dispose();
    _contactSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final smsServiceAsync = ref.watch(smsServiceProvider);
    final emailServiceAsync = ref.watch(emailServiceProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChannelSelector(),
          const SizedBox(height: 12),
          Expanded(
            child: switch (_channel) {
              CommunicationChannel.sms => smsServiceAsync.when(
                  data: (service) => _buildSmsComposer(service),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, stackTrace) => Center(child: Text('Error loading SMS settings: $e')),
                ),
              CommunicationChannel.email => emailServiceAsync.when(
                  data: (service) => _buildEmailComposer(service),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, stackTrace) => Center(child: Text('Error loading email settings: $e')),
                ),
              CommunicationChannel.phone => _buildPhoneContacts(),
              CommunicationChannel.inApp => _buildInAppComposer(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSelector() {
    Widget chip(CommunicationChannel c, String label, IconData icon) {
      final selected = _channel == c;
      return ChoiceChip(
        selected: selected,
        onSelected: (_) => setState(() => _channel = c),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        chip(CommunicationChannel.sms, 'SMS', LucideIcons.messageSquare),
        chip(CommunicationChannel.email, 'Email', LucideIcons.mail),
        chip(CommunicationChannel.phone, 'Phone', LucideIcons.phoneCall),
        if (widget.audience == CommunicationAudience.staff)
          chip(CommunicationChannel.inApp, 'In-App', LucideIcons.inbox),
      ],
    );
  }

  Widget _buildInAppComposer() {
    if (widget.audience != CommunicationAudience.staff) {
      return const Center(child: Text('In-app messaging is only available for Staff.'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTemplateSelector(),
        const SizedBox(height: 12),
        _buildRecipientControls(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailSubjectController,
          decoration: const InputDecoration(
            labelText: 'Subject (optional)',
            border: OutlineInputBorder(),
            prefixIcon: Icon(LucideIcons.tag, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildMessageComposer()),
        const SizedBox(height: 16),
        _buildSendInAppButton(),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Expanded(child: _buildHistory(channel: 'in-app')),
      ],
    );
  }

  void _refreshPhoneContacts() {
    _phoneContactsFuture = _resolvePhoneContacts();
  }

  Widget _buildSmsComposer(SmsGateway? service) {
    if (service == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.sms_failed, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'SMS Not Configured',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Go to Settings and enter Africa\'s Talking credentials to enable SMS.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTemplateSelector(),
        const SizedBox(height: 12),
        _buildRecipientControls(),
        const SizedBox(height: 12),
        Expanded(child: _buildMessageComposer()),
        const SizedBox(height: 16),
        _buildSendButton(service),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Expanded(child: _buildHistory(channel: 'sms')),
      ],
    );
  }

  Widget _buildEmailComposer(EmailGateway? service) {
    if (service == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.email_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Email Not Configured',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Go to Settings and configure SMTP to enable in-app email sending.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/settings'),
                icon: const Icon(Icons.settings),
                label: const Text('Open Settings'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTemplateSelector(),
        const SizedBox(height: 12),
        _buildRecipientControls(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _emailSubjectController,
          decoration: const InputDecoration(
            labelText: 'Subject',
            border: OutlineInputBorder(),
            prefixIcon: Icon(LucideIcons.mail, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: _buildMessageComposer()),
        const SizedBox(height: 16),
        _buildSendEmailButton(service),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),
        Expanded(child: _buildHistory(channel: 'email')),
      ],
    );
  }

  Widget _buildTemplateSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Message Template', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _selectedTemplate,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: _templates.entries
              .map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)))
              .toList(growable: false),
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _selectedTemplate = value;
              _loadTemplate(value);
            });
          },
        ),
      ],
    );
  }

  Widget _buildRecipientControls() {
    if (widget.audience == CommunicationAudience.staff) {
      final isCustomRoles = _recipientFilter == 'custom_roles';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recipients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _recipientFilter,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Staff')),
              DropdownMenuItem(value: 'management', child: Text('Management (Admins + Secretaries)')),
              DropdownMenuItem(value: 'teaching', child: Text('Teaching Staff (Teachers)')),
              DropdownMenuItem(value: 'finance', child: Text('Finance (Accountants)')),
              DropdownMenuItem(
                value: 'operations',
                child: Text('Operations (Security + Labs + Library + Shop + Infirmary)'),
              ),
              DropdownMenuItem(value: 'non_teaching', child: Text('All Non-Teaching (Finance + Ops + Secretaries)')),
              DropdownMenuItem(value: 'custom_roles', child: Text('Custom Roles (multi-select)')),
              DropdownMenuItem(value: 'individual', child: Text('Specific Staff')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _recipientFilter = value;
                if (_recipientFilter != 'individual') _selectedStaffUserId = null;
                if (_recipientFilter != 'custom_roles') _selectedStaffRoles.clear();
                _refreshPhoneContacts();
              });
            },
          ),
          if (isCustomRoles) ...[
            const SizedBox(height: 10),
            const Text('Select Roles', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _staffRoleLabels.entries
                  .map((e) {
                    final selected = _selectedStaffRoles.contains(e.key);
                    return FilterChip(
                      selected: selected,
                      label: Text(e.value),
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedStaffRoles.add(e.key);
                          } else {
                            _selectedStaffRoles.remove(e.key);
                          }
                          _refreshPhoneContacts();
                        });
                      },
                    );
                  })
                  .toList(growable: false),
            ),
          ],
          if (_recipientFilter == 'individual') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Selected Staff',
                    ),
                    child: Text(
                      _selectedStaffUserId == null ? 'None selected' : 'Selected',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () async {
                    final userId = await _pickStaffUserId();
                    if (!mounted) return;
                    if (userId == null) return;
                    setState(() {
                      _selectedStaffUserId = userId;
                      _refreshPhoneContacts();
                    });
                  },
                  icon: const Icon(LucideIcons.user, size: 16),
                  label: const Text('Select'),
                ),
              ],
            ),
          ],
        ],
      );
    }

    final classesAsync = ref.watch(_schoolClassesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recipients', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _recipientFilter,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(value: 'all', child: Text('All Parents')),
            DropdownMenuItem(value: 'class', child: Text('Specific Class')),
            DropdownMenuItem(value: 'individual', child: Text('Specific Student/Parent')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _recipientFilter = value;
              if (_recipientFilter != 'class') _selectedClassId = null;
              if (_recipientFilter != 'individual') _selectedParentAccountId = null;
              _refreshPhoneContacts();
            });
          },
        ),
        if (_recipientFilter == 'individual') ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Selected Parent',
                  ),
                  child: Text(
                    _selectedParentAccountId == null ? 'None selected' : 'Selected',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final parentId = await _pickParentAccountId();
                  if (!mounted) return;
                  if (parentId == null) return;
                  setState(() {
                    _selectedParentAccountId = parentId;
                    _refreshPhoneContacts();
                  });
                },
                icon: const Icon(LucideIcons.userCheck, size: 16),
                label: const Text('Select'),
              ),
            ],
          ),
        ],
        if (_recipientFilter == 'class') ...[
          const SizedBox(height: 12),
          classesAsync.when(
            data: (classes) {
              return DropdownButtonFormField<int>(
                initialValue: _selectedClassId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Select Class',
                ),
                items: classes
                    .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.className)))
                    .toList(growable: false),
                onChanged: (v) => setState(() {
                  _selectedClassId = v;
                  _refreshPhoneContacts();
                }),
                validator: (v) => v == null ? 'Please select a class' : null,
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (e, stackTrace) => Text('Could not load classes: $e'),
          ),
        ]
      ],
    );
  }

  Widget _buildMessageComposer() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Expanded(
          child: TextField(
            controller: _messageController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Type your message here...',
            ),
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _messageController,
          builder: (context, v, child) {
            return Text(
              '${v.text.length}/160 characters',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            );
          },
        )
      ],
    );
  }

  Widget _buildSendButton(SmsGateway service) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : () => _sendSms(service),
        icon: _isSending
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(_isSending ? 'Sending...' : 'Send SMS'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSendEmailButton(EmailGateway service) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : () => _sendEmail(service),
        icon: _isSending
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(_isSending ? 'Sending...' : 'Send Email'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSendInAppButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSending ? null : _sendInApp,
        icon: _isSending
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.send),
        label: Text(_isSending ? 'Sending...' : 'Send In-App'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          backgroundColor: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildHistory({required String channel}) {
    final db = ref.watch(databaseProvider);
    final query = (db.select(db.notifications)
          ..where((n) => n.channel.equals(channel))
          ..where((n) => n.recipientType.equals(widget.audience == CommunicationAudience.parents ? 'parent' : 'staff'))
          ..orderBy([
            (n) => drift.OrderingTerm(expression: n.createdAt, mode: drift.OrderingMode.desc),
          ])
          ..limit(20))
        .watch();

    return StreamBuilder<List<appdb.Notification>>(
      stream: query,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <appdb.Notification>[];
        if (snapshot.connectionState == ConnectionState.waiting && items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (items.isEmpty) {
          return const Center(child: Text('No recent messages yet.'));
        }
        return ListView.separated(
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final n = items[i];
            final statusColor = switch (n.status) {
              'sent' => Colors.green,
              'read' => Colors.blueGrey,
              'failed' => Colors.red,
              'pending' => Colors.orange,
              _ => Colors.grey,
            };
            final fallbackTitle = channel == 'email'
                ? 'Email'
                : (channel == 'phone' ? 'Phone' : (channel == 'in-app' ? 'In-App' : 'SMS'));
            final title = (n.subject?.trim().isNotEmpty == true) ? n.subject!.trim() : fallbackTitle;
            return ListTile(
              dense: true,
              title: Text(title),
              subtitle: Text(
                n.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                n.status,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendInApp() async {
    if (widget.audience != CommunicationAudience.staff) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    if (_recipientFilter == 'individual' && _selectedStaffUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a staff member'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_recipientFilter == 'custom_roles' && _selectedStaffRoles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one role'), backgroundColor: Colors.red),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to send messages'), backgroundColor: Colors.red),
      );
      return;
    }

    final subjectFromField = _emailSubjectController.text.trim();
    final subject = subjectFromField.isEmpty ? (_templates[_selectedTemplate] ?? 'Message') : subjectFromField;

    final db = ref.read(databaseProvider);
    final svc = StaffMessagingService(db);

    final roles = _staffRolesForFilter();
    final bool isBroadcastAll = _recipientFilter == 'all';
    final int? singleToUserId = _recipientFilter == 'individual' ? _selectedStaffUserId : null;

    List<int> toUserIds = const [];
    if (!isBroadcastAll && singleToUserId == null) {
      if (_recipientFilter == 'custom_roles' && (roles == null || roles.isEmpty)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select at least one role'), backgroundColor: Colors.red),
        );
        return;
      }

      // In-app recipients are users (not necessarily staff rows).
      final q = db.select(db.users)..where((u) => u.isActive.equals(true));
      if (roles != null && roles.isNotEmpty) {
        q.where((u) => u.role.isIn(roles));
      }

      final rows = await q.get();
      toUserIds = rows.map((u) => u.id).toSet().toList(growable: false);
      if (toUserIds.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No recipients found for the selected filter'), backgroundColor: Colors.red),
        );
        return;
      }
    }

    String confirmText;
    if (isBroadcastAll) {
      confirmText = 'Send In-App message to all staff?';
    } else if (singleToUserId != null) {
      confirmText = 'Send In-App message to selected staff?';
    } else {
      final label = switch (_recipientFilter) {
        'management' => 'management',
        'teaching' => 'teaching staff',
        'finance' => 'finance',
        'operations' => 'operations',
        'non_teaching' => 'non-teaching staff',
        'custom_roles' => 'selected role(s)',
        _ => 'staff',
      };
      confirmText = 'Send In-App message to ${toUserIds.length} $label recipient(s)?';
    }

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Send'),
        content: Text(confirmText),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isSending = true);
    try {
      if (isBroadcastAll) {
        await svc.sendInAppMessage(
          fromUserId: currentUser.id,
          subject: subject,
          message: message,
          toUserId: null,
        );
      } else if (singleToUserId != null) {
        await svc.sendInAppMessage(
          fromUserId: currentUser.id,
          subject: subject,
          message: message,
          toUserId: singleToUserId,
        );
      } else {
        for (final id in toUserIds) {
          await svc.sendInAppMessage(
            fromUserId: currentUser.id,
            subject: subject,
            message: message,
            toUserId: id,
          );
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('In-app message sent'), backgroundColor: Colors.green),
      );
      _messageController.clear();
      _emailSubjectController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send in-app message: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildPhoneContacts() {
    final future = _phoneContactsFuture ??= _resolvePhoneContacts();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.audience == CommunicationAudience.parents) ...[
          _buildRecipientControls(),
          const SizedBox(height: 12),
        ] else ...[
          _buildRecipientControls(),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _contactSearchController,
          decoration: const InputDecoration(
            labelText: 'Search contacts',
            border: OutlineInputBorder(),
            prefixIcon: Icon(LucideIcons.search, size: 20),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<_PhoneContact>>(
            future: future,
            builder: (context, snapshot) {
              final contacts = snapshot.data ?? const <_PhoneContact>[];
              if (snapshot.connectionState == ConnectionState.waiting && contacts.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final q = _contactSearchController.text.trim().toLowerCase();
              final filtered = q.isEmpty
                  ? contacts
                  : contacts
                      .where((c) => c.displayName.toLowerCase().contains(q) || c.phoneNumber.toLowerCase().contains(q))
                      .toList(growable: false);

              if (filtered.isEmpty) {
                return const Center(child: Text('No contacts found.'));
              }

              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final c = filtered[index];
                  return ListTile(
                    dense: true,
                    title: Text(c.displayName),
                    subtitle: Text(c.phoneNumber),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: 'Copy number',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: c.phoneNumber));
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(content: Text('Number copied')));
                          },
                          icon: const Icon(LucideIcons.copy, size: 18),
                        ),
                        IconButton(
                          tooltip: 'Call',
                          onPressed: () => _startPhoneCall(c.phoneNumber),
                          icon: const Icon(LucideIcons.phoneCall, size: 18),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _loadTemplate(String template) {
    final signature = _schoolNameFallback();

    if (widget.audience == CommunicationAudience.staff) {
      switch (template) {
        case 'staff_notice':
          _messageController.text = 'Dear Staff, please take note. - $signature';
          break;
        case 'meeting':
          _messageController.text = 'Dear Staff, reminder: meeting scheduled. Please be punctual. - $signature';
          break;
        case 'general_announcement':
          _messageController.text = 'Dear Staff, ';
          break;
        default:
          _messageController.clear();
      }
      return;
    }

    switch (template) {
      case 'fee_reminder':
        _messageController.text =
            'Dear Parent, this is a reminder about your child\'s outstanding fee balance. Please make payment at your earliest convenience. - $signature';
        break;
      case 'exam_notice':
        _messageController.text =
            'Dear Parent, this is to inform you about upcoming examinations. Please ensure your child is well prepared. - $signature';
        break;
      case 'attendance_alert':
        _messageController.text =
            'Dear Parent, your child was marked absent today. Please contact the school if this is incorrect. - $signature';
        break;
      case 'general_announcement':
        _messageController.text = 'Dear Parent, ';
        break;
      default:
        _messageController.clear();
    }
  }

  Future<List<String>> _resolvePhoneNumbers() async {
    final db = ref.read(databaseProvider);

    if (widget.audience == CommunicationAudience.staff) {
      final roles = _staffRolesForFilter();
      if (_recipientFilter == 'individual') {
        final userId = _selectedStaffUserId;
        if (userId == null) return const [];
        final staffRow = await (db.select(db.staff)..where((s) => s.userId.equals(userId))).getSingleOrNull();
        final phone = staffRow?.phoneNumber.trim() ?? '';
        return phone.isEmpty ? const [] : [phone];
      }

      if (_recipientFilter == 'custom_roles' && (roles == null || roles.isEmpty)) {
        return const [];
      }

      final joinQuery = db.select(db.staff).join([
        drift.innerJoin(db.users, db.users.id.equalsExp(db.staff.userId)),
      ]);

      if (roles != null && roles.isNotEmpty) {
        joinQuery.where(db.users.role.isIn(roles));
      }

      final rows = await joinQuery.get();
      return rows
          .map((r) => r.readTable(db.staff).phoneNumber.trim())
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    if (_recipientFilter == 'individual') {
      final parentId = _selectedParentAccountId;
      if (parentId == null) return const [];
      final parent = await (db.select(db.parentAccounts)..where((p) => p.id.equals(parentId))).getSingleOrNull();
      final phone = parent?.phoneNumber.trim() ?? '';
      return phone.isEmpty ? const [] : [phone];
    }

    if (_recipientFilter == 'class') {
      final classId = _selectedClassId;
      if (classId == null) return const [];

      final students = await (db.select(db.students)..where((s) => s.classId.equals(classId))).get();
      final studentIds = students.map((s) => s.id).toList(growable: false);
      if (studentIds.isEmpty) return const [];

      final parents = await (db.select(db.parentAccounts)..where((p) => p.studentId.isIn(studentIds))).get();
      return parents
          .map((p) => p.phoneNumber.trim())
          .where((p) => p.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    final parents = await db.select(db.parentAccounts).get();
    return parents
        .map((p) => p.phoneNumber.trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<List<_PhoneContact>> _resolvePhoneContacts() async {
    final db = ref.read(databaseProvider);

    if (widget.audience == CommunicationAudience.staff) {
      final roles = _staffRolesForFilter();
      if (_recipientFilter == 'individual') {
        final userId = _selectedStaffUserId;
        if (userId == null) return const [];

        final staffRow = await (db.select(db.staff)..where((s) => s.userId.equals(userId))).getSingleOrNull();
        if (staffRow == null) return const [];
        final phone = staffRow.phoneNumber.trim();
        if (phone.isEmpty) return const [];
        return [
          _PhoneContact(
            displayName: '${staffRow.firstName} ${staffRow.lastName}'.trim(),
            phoneNumber: phone,
          ),
        ];
      }

      if (_recipientFilter == 'custom_roles' && (roles == null || roles.isEmpty)) {
        return const [];
      }

      final joinQuery = db.select(db.staff).join([
        drift.innerJoin(db.users, db.users.id.equalsExp(db.staff.userId)),
      ]);

      if (roles != null && roles.isNotEmpty) {
        joinQuery.where(db.users.role.isIn(roles));
      }

      final rows = await joinQuery.get();
      return rows
          .map((r) {
            final s = r.readTable(db.staff);
            return _PhoneContact(
              displayName: '${s.firstName} ${s.lastName}'.trim(),
              phoneNumber: s.phoneNumber.trim(),
            );
          })
          .where((c) => c.phoneNumber.isNotEmpty)
          .toList(growable: false);
    }

    if (_recipientFilter == 'individual') {
      final parentId = _selectedParentAccountId;
      if (parentId == null) return const [];
      final parent = await (db.select(db.parentAccounts)..where((p) => p.id.equals(parentId))).getSingleOrNull();
      if (parent == null) return const [];

      final phone = parent.phoneNumber.trim();
      if (phone.isEmpty) return const [];
      return [
        _PhoneContact(
          displayName: parent.parentName.trim(),
          phoneNumber: phone,
        ),
      ];
    }

    if (_recipientFilter == 'class') {
      final classId = _selectedClassId;
      if (classId == null) return const [];

      final students = await (db.select(db.students)..where((s) => s.classId.equals(classId))).get();
      final studentIds = students.map((s) => s.id).toList(growable: false);
      if (studentIds.isEmpty) return const [];

      final parents = await (db.select(db.parentAccounts)..where((p) => p.studentId.isIn(studentIds))).get();
      return parents
          .map(
            (p) => _PhoneContact(
              displayName: p.parentName.trim(),
              phoneNumber: p.phoneNumber.trim(),
            ),
          )
          .where((c) => c.phoneNumber.isNotEmpty)
          .toList(growable: false);
    }

    final parents = await db.select(db.parentAccounts).get();
    return parents
        .map(
          (p) => _PhoneContact(
            displayName: p.parentName.trim(),
            phoneNumber: p.phoneNumber.trim(),
          ),
        )
        .where((c) => c.phoneNumber.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _startPhoneCall(String phoneNumber) async {
    final raw = phoneNumber.trim();
    if (raw.isEmpty) return;

    final normalized = raw.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: normalized);

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start a phone call on this device.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<List<String>> _resolveEmailAddresses() async {
    final db = ref.read(databaseProvider);

    if (widget.audience == CommunicationAudience.staff) {
      final roles = _staffRolesForFilter();
      if (_recipientFilter == 'individual') {
        final userId = _selectedStaffUserId;
        if (userId == null) return const [];
        final user = await (db.select(db.users)..where((u) => u.id.equals(userId))).getSingleOrNull();
        final email = user?.email.trim() ?? '';
        return email.isEmpty ? const [] : [email];
      }

      if (_recipientFilter == 'custom_roles' && (roles == null || roles.isEmpty)) {
        return const [];
      }
      final joinQuery = db.select(db.staff).join([
        drift.innerJoin(db.users, db.users.id.equalsExp(db.staff.userId)),
      ]);

      if (roles != null && roles.isNotEmpty) {
        joinQuery.where(db.users.role.isIn(roles));
      }

      final rows = await joinQuery.get();
      final emails = <String>{};
      for (final row in rows) {
        final user = row.readTable(db.users);
        final email = user.email.trim();
        if (email.isNotEmpty) emails.add(email);
      }
      return emails.toList(growable: false);
    }

    if (_recipientFilter == 'individual') {
      final parentId = _selectedParentAccountId;
      if (parentId == null) return const [];
      final parent = await (db.select(db.parentAccounts)..where((p) => p.id.equals(parentId))).getSingleOrNull();
      final email = parent?.email.trim() ?? '';
      return email.isEmpty ? const [] : [email];
    }

    if (_recipientFilter == 'class') {
      final classId = _selectedClassId;
      if (classId == null) return const [];

      final students = await (db.select(db.students)..where((s) => s.classId.equals(classId))).get();
      final studentIds = students.map((s) => s.id).toList(growable: false);
      if (studentIds.isEmpty) return const [];

      final parents = await (db.select(db.parentAccounts)..where((p) => p.studentId.isIn(studentIds))).get();
      return parents
          .map((p) => p.email.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }

    final parents = await db.select(db.parentAccounts).get();
    return parents
        .map((p) => p.email.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Future<void> _sendSms(SmsGateway smsService) async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    final phones = await _resolvePhoneNumbers();
    if (!mounted) return;
    if (phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recipients found for the selected filter'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Send'),
        content: Text('Send SMS to ${phones.length} recipient(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;

    if (!mounted) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to send messages'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSending = true);
    final db = ref.read(databaseProvider);
    final subject = _templates[_selectedTemplate];

    int notificationId;
    try {
      final recipientIdValue = widget.audience == CommunicationAudience.parents
          ? _selectedParentAccountId
          : (widget.audience == CommunicationAudience.staff ? _selectedStaffUserId : null);

      notificationId = await db.into(db.notifications).insert(
            appdb.NotificationsCompanion.insert(
              recipientId: drift.Value(recipientIdValue),
              recipientType: widget.audience == CommunicationAudience.parents ? 'parent' : 'staff',
              channel: 'sms',
              subject: drift.Value(subject),
              message: message,
              status: 'pending',
              createdBy: currentUser.id,
            ),
          );
    } catch (_) {
      // If audit insert fails, still attempt sending.
      notificationId = -1;
    }

    final result = await smsService.sendBulkAnnouncement(phoneNumbers: phones, announcement: message);

    if (!mounted) return;

    if (notificationId != -1) {
      await (db.update(db.notifications)..where((n) => n.id.equals(notificationId))).write(
        appdb.NotificationsCompanion(
          status: drift.Value(result.success ? 'sent' : 'failed'),
          externalId: drift.Value(result.messageId),
          sentAt: drift.Value(DateTime.now()),
        ),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    if (result.success) _messageController.clear();
    if (mounted) setState(() => _isSending = false);
  }

  Future<void> _sendEmail(EmailGateway emailService) async {
    final body = _messageController.text.trim();
    if (body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a message')));
      return;
    }

    final subjectFromField = _emailSubjectController.text.trim();
    final subject = subjectFromField.isEmpty ? (_templates[_selectedTemplate] ?? 'Announcement') : subjectFromField;

    final emails = await _resolveEmailAddresses();
    if (!mounted) return;
    if (emails.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No recipients found for the selected filter'), backgroundColor: Colors.red),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Send'),
        content: Text('Send Email to ${emails.length} recipient(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to send messages'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSending = true);
    final db = ref.read(databaseProvider);

    int notificationId;
    try {
      final recipientIdValue = widget.audience == CommunicationAudience.parents
          ? _selectedParentAccountId
          : (widget.audience == CommunicationAudience.staff ? _selectedStaffUserId : null);

      notificationId = await db.into(db.notifications).insert(
            appdb.NotificationsCompanion.insert(
              recipientId: drift.Value(recipientIdValue),
              recipientType: widget.audience == CommunicationAudience.parents ? 'parent' : 'staff',
              channel: 'email',
              subject: drift.Value(subject),
              message: body,
              status: 'pending',
              createdBy: currentUser.id,
            ),
          );
    } catch (_) {
      notificationId = -1;
    }

    final EmailSendResult result = await emailService.sendBulkAnnouncement(
      recipients: emails,
      subject: subject,
      body: body,
    );

    if (!mounted) return;

    if (notificationId != -1) {
      await (db.update(db.notifications)..where((n) => n.id.equals(notificationId))).write(
        appdb.NotificationsCompanion(
          status: drift.Value(result.success ? 'sent' : 'failed'),
          sentAt: drift.Value(DateTime.now()),
        ),
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
    if (result.success) {
      _messageController.clear();
      _emailSubjectController.clear();
    }
    if (mounted) setState(() => _isSending = false);
  }

  Future<int?> _pickParentAccountId() async {
    final db = ref.read(databaseProvider);

    final joinQuery = db.select(db.parentAccounts).join([
      drift.innerJoin(db.students, db.students.id.equalsExp(db.parentAccounts.studentId)),
      drift.leftOuterJoin(db.schoolClasses, db.schoolClasses.id.equalsExp(db.students.classId)),
    ]);

    final rows = await joinQuery.get();
    if (!mounted) return null;

    final items = rows
        .map((r) {
          final parent = r.readTable(db.parentAccounts);
          final student = r.readTable(db.students);
          final klass = r.readTableOrNull(db.schoolClasses);
          final studentName = '${student.firstName} ${student.lastName}'.trim();
          final className = klass?.className;
          return _SelectItem(
            id: parent.id,
            title: parent.parentName.trim(),
            subtitle: '$studentName${className == null ? '' : ' • $className'} • ${parent.relationship}',
            meta: '${parent.phoneNumber} • ${parent.email}',
            searchText: '${parent.parentName} ${student.firstName} ${student.lastName} ${parent.phoneNumber} ${parent.email} ${className ?? ''}'.toLowerCase(),
          );
        })
        .toList(growable: false);

    return _showSelectDialog(
      title: 'Select Student/Parent',
      hintText: 'Search by student, parent, phone or email',
      items: items,
    );
  }

  Future<int?> _pickStaffUserId() async {
    final db = ref.read(databaseProvider);

    final joinQuery = db.select(db.staff).join([
      drift.innerJoin(db.users, db.users.id.equalsExp(db.staff.userId)),
    ]);

    final rows = await joinQuery.get();
    if (!mounted) return null;

    final items = rows
        .map((r) {
          final staff = r.readTable(db.staff);
          final user = r.readTable(db.users);
          final name = '${staff.firstName} ${staff.lastName}'.trim();
          return _SelectItem(
            id: staff.userId,
            title: name,
            subtitle: '${staff.position} • ${staff.staffId}',
            meta: '${staff.phoneNumber} • ${user.email}',
            searchText: '$name ${staff.position} ${staff.staffId} ${staff.phoneNumber} ${user.email}'.toLowerCase(),
          );
        })
        .toList(growable: false);

    return _showSelectDialog(
      title: 'Select Staff',
      hintText: 'Search by name, phone, email, staff id',
      items: items,
    );
  }

  Future<int?> _showSelectDialog({
    required String title,
    required String hintText,
    required List<_SelectItem> items,
  }) async {
    String q = '';

    return showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final query = q.trim().toLowerCase();
            final filtered = query.isEmpty
                ? items
                : items.where((i) => i.searchText.contains(query)).toList(growable: false);

            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: hintText,
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (v) => setLocalState(() => q = v),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No matches.'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final item = filtered[index];
                                return ListTile(
                                  dense: true,
                                  title: Text(item.title),
                                  subtitle: Text('${item.subtitle}\n${item.meta}', maxLines: 2, overflow: TextOverflow.ellipsis),
                                  onTap: () => Navigator.pop(context, item.id),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );
  }
}

class _PhoneContact {
  const _PhoneContact({required this.displayName, required this.phoneNumber});

  final String displayName;
  final String phoneNumber;
}

class _SelectItem {
  const _SelectItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.searchText,
  });

  final int id;
  final String title;
  final String subtitle;
  final String meta;
  final String searchText;
}
