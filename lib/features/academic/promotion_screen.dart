import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:ghanaclass_school_management/core/constants/theme.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/academic/academic_providers.dart';
import 'promotion_providers.dart';
import 'package:ghanaclass_school_management/core/providers/activity_providers.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/constants/user_roles.dart';

class PromotionScreen extends ConsumerStatefulWidget {
  const PromotionScreen({super.key});

  @override
  ConsumerState<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends ConsumerState<PromotionScreen> {
  int? _sourceClassId;
  int? _targetClassId;
  final Set<int> _selectedStudentIds = {};
  bool _isPromoting = false;

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Class Promotion Tool'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildSelectionHeader(classesAsync),
            const SizedBox(height: 24),
            Expanded(child: _buildStudentList()),
            const SizedBox(height: 24),
            _buildActionFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(AsyncValue<List<SchoolClassesData>> classesAsync) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: classesAsync.when(
              data: (list) => DropdownButtonFormField<int>(
                initialValue: _sourceClassId,
                decoration: const InputDecoration(labelText: 'From Class (Source)', prefixIcon: Icon(LucideIcons.logOut)),
                items: list.map((c) => DropdownMenuItem(value: c.id, child: Text(c.className))).toList(),
                onChanged: (val) {
                  setState(() {
                    _sourceClassId = val;
                    _selectedStudentIds.clear();
                  });
                },
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => const Text('Error'),
            ),
          ),
          const SizedBox(width: 32),
          const Icon(LucideIcons.arrowRight, color: AppTheme.textMuted),
          const SizedBox(width: 32),
          Expanded(
            child: classesAsync.when(
              data: (list) => DropdownButtonFormField<int>(
                initialValue: _targetClassId,
                decoration: const InputDecoration(labelText: 'To Class (Destination)', prefixIcon: Icon(LucideIcons.logIn)),
                items: list.map((c) => DropdownMenuItem(value: c.id, child: Text(c.className))).toList(),
                onChanged: (val) => setState(() => _targetClassId = val),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (error, stackTrace) => const Text('Error'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    if (_sourceClassId == null) {
      return const Center(child: Text('Select a source class to see students.'));
    }

    return Consumer(
      builder: (context, ref, _) {
        final studentsFuture = ref.watch(promotionServiceProvider).getPromotableStudents(_sourceClassId!);
        
        return FutureBuilder<List<Student>>(
          future: studentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
            
            final students = snapshot.data ?? [];
            if (students.isEmpty) return const Center(child: Text('No active students found in this class.'));

            return Column(
              children: [
                CheckboxListTile(
                  title: const Text('Select All Students', style: TextStyle(fontWeight: FontWeight.bold)),
                  value: _selectedStudentIds.length == students.length,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedStudentIds.addAll(students.map((s) => s.id));
                      } else {
                        _selectedStudentIds.clear();
                      }
                    });
                  },
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final s = students[index];
                      return CheckboxListTile(
                        title: Text('${s.firstName} ${s.lastName}'),
                        subtitle: Text('ID: ${s.studentId}'),
                        value: _selectedStudentIds.contains(s.id),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedStudentIds.add(s.id);
                            } else {
                              _selectedStudentIds.remove(s.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionFooter() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('${_selectedStudentIds.length} students selected for promotion.', style: const TextStyle(fontWeight: FontWeight.w600)),
          ElevatedButton.icon(
            onPressed: (_sourceClassId == null || _targetClassId == null || _selectedStudentIds.isEmpty || _isPromoting) 
              ? null 
              : _processPromotion,
            icon: _isPromoting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(LucideIcons.checkCircle),
            label: Text(_isPromoting ? 'PROMOTING...' : 'CONFIRM PROMOTION'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processPromotion() async {
    if (_sourceClassId == _targetClassId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Source and Target classes cannot be the same.')));
      return;
    }

    setState(() => _isPromoting = true);

    try {
      final count = await ref.read(promotionServiceProvider).promoteStudents(
        fromClassId: _sourceClassId!,
        toClassId: _targetClassId!,
        studentIds: _selectedStudentIds.toList(),
      );

      final currentUser = ref.read(currentUserProvider);
      if (currentUser != null) {
        await ref.read(activityServiceProvider).logActivity(
          actorUserId: currentUser.id,
          actorName: currentUser.fullName,
          actorRole: UserRole.admin,
          module: 'academic',
          actionType: 'bulk_promotion',
          description: 'Promoted $count students from class ID $_sourceClassId to $_targetClassId',
          isImportant: true,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Successfully promoted $count students!'), backgroundColor: Colors.green));
        setState(() {
          _selectedStudentIds.clear();
          _sourceClassId = null;
          _targetClassId = null;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isPromoting = false);
    }
  }
}
