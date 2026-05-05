import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'academic_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:drift/drift.dart' as drift;

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subjects Management'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => _showAddSubjectDialog(context, ref),
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('Add Subject'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.actionIndigo,
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
      body: subjectsAsync.when(
        data: (subjects) => subjects.isEmpty 
          ? _buildEmptyState(context, ref)
          : _buildSubjectsList(context, subjects, ref),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.bookOpen, size: 64, color: AppTheme.textMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No subjects defined yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.textMuted),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showAddSubjectDialog(context, ref),
            child: const Text('Create First Subject'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList(BuildContext context, List<SchoolSubject> subjects, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ListView.builder(
        itemCount: subjects.length,
        itemBuilder: (context, index) {
          final subj = subjects[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (subj.isCore ? AppTheme.actionIndigo : AppTheme.primarySlate).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  subj.isCore ? LucideIcons.star : LucideIcons.book, 
                  color: subj.isCore ? AppTheme.actionIndigo : AppTheme.textMuted,
                  size: 20
                ),
              ),
              title: Text(subj.subjectName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Code: ${subj.subjectCode} • ${subj.isCore ? "Core" : "Elective"}'),
              trailing: IconButton(
                icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                onPressed: () async {
                  await ref.read(academicServiceProvider).deleteSubject(subj.id);
                  ref.invalidate(subjectsProvider);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAddSubjectDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    bool isCore = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('New Subject'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Subject Name')),
              TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Subject Code')),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Core Subject'),
                value: isCore,
                onChanged: (val) => setState(() => isCore = val),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || codeController.text.isEmpty) return;
                
                await ref.read(academicServiceProvider).createSubject(
                  SchoolSubjectsCompanion.insert(
                    subjectName: nameController.text,
                    subjectCode: codeController.text,
                    isCore: drift.Value(isCore),
                  ),
                );
                ref.invalidate(subjectsProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}
