import 'dart:convert';

import 'package:drift/drift.dart' as drift;
import 'package:ghanaclass_school_management/core/database/app_database.dart';

class ApprovalRequestRow {
  final ApprovalRequest request;
  final User requestedBy;
  final User? decidedBy;

  const ApprovalRequestRow({
    required this.request,
    required this.requestedBy,
    required this.decidedBy,
  });
}

class DelegationTaskRow {
  final DelegationTask task;
  final User createdBy;
  final User assignedTo;

  const DelegationTaskRow({
    required this.task,
    required this.createdBy,
    required this.assignedTo,
  });
}

class StaffAppraisalRow {
  final StaffAppraisal appraisal;
  final StaffData staff;
  final User user;

  const StaffAppraisalRow({
    required this.appraisal,
    required this.staff,
    required this.user,
  });
}

class ComplianceProgress {
  final int totalItems;
  final int completedItems;

  const ComplianceProgress({required this.totalItems, required this.completedItems});

  double get percent => totalItems == 0 ? 0.0 : (completedItems / totalItems) * 100.0;
}

class DirectorWorkflowService {
  DirectorWorkflowService(this._db);

  final AppDatabase _db;

  // -------------------- Approvals --------------------

  Stream<List<ApprovalRequestRow>> watchApprovalRequests({
    String? status,
    int limit = 20,
  }) {
    final uReq = _db.alias(_db.users, 'approval_requested_by');
    final uDec = _db.alias(_db.users, 'approval_decided_by');

    final q = _db.select(_db.approvalRequests);
    if (status != null) {
      q.where((t) => t.status.equals(status));
    }

    final joined = q.join([
      drift.innerJoin(uReq, uReq.id.equalsExp(_db.approvalRequests.requestedByUserId)),
      drift.leftOuterJoin(uDec, uDec.id.equalsExp(_db.approvalRequests.decidedByUserId)),
    ])
      ..orderBy([
        drift.OrderingTerm(expression: _db.approvalRequests.requestedAt, mode: drift.OrderingMode.desc),
      ])
      ..limit(limit);

    return joined.watch().map((rows) {
      return rows.map((r) {
        return ApprovalRequestRow(
          request: r.readTable(_db.approvalRequests),
          requestedBy: r.readTable(uReq),
          decidedBy: r.readTableOrNull(uDec),
        );
      }).toList(growable: false);
    });
  }

  Future<int> createApprovalRequest({
    required String title,
    String category = 'general',
    String? description,
    double? amount,
    Map<String, Object?>? metadata,
    required int requestedByUserId,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const FormatException('Title is required');
    }

    return _db.into(_db.approvalRequests).insert(
          ApprovalRequestsCompanion.insert(
            title: trimmedTitle,
            category: category.trim().isEmpty ? const drift.Value('general') : drift.Value(category.trim()),
            description: drift.Value(description?.trim().isEmpty == true ? null : description?.trim()),
            requestedByUserId: requestedByUserId,
            amount: drift.Value(amount),
            metadataJson: drift.Value(metadata == null ? null : jsonEncode(metadata)),
          ),
        );
  }

  Future<void> decideApprovalRequest({
    required int requestId,
    required String status,
    required int decidedByUserId,
    String? note,
  }) async {
    if (status != 'approved' && status != 'rejected') {
      throw const FormatException('Invalid status');
    }

    await (_db.update(_db.approvalRequests)..where((t) => t.id.equals(requestId))).write(
      ApprovalRequestsCompanion(
        status: drift.Value(status),
        decidedByUserId: drift.Value(decidedByUserId),
        decidedAt: drift.Value(DateTime.now()),
        decisionNote: drift.Value(note?.trim().isEmpty == true ? null : note?.trim()),
        isDirty: const drift.Value(true),
      ),
    );
  }

  // -------------------- Delegation --------------------

  Stream<List<DelegationTaskRow>> watchDelegationTasks({
    String? status,
    int limit = 50,
  }) {
    final uCreator = _db.alias(_db.users, 'task_created_by');
    final uAssignee = _db.alias(_db.users, 'task_assigned_to');

    final q = _db.select(_db.delegationTasks);
    if (status != null) {
      q.where((t) => t.status.equals(status));
    }

    final joined = q.join([
      drift.innerJoin(uCreator, uCreator.id.equalsExp(_db.delegationTasks.createdByUserId)),
      drift.innerJoin(uAssignee, uAssignee.id.equalsExp(_db.delegationTasks.assignedToUserId)),
    ])
      ..orderBy([
        drift.OrderingTerm(expression: _db.delegationTasks.createdAt, mode: drift.OrderingMode.desc),
      ])
      ..limit(limit);

    return joined.watch().map((rows) {
      return rows
          .map((r) => DelegationTaskRow(
                task: r.readTable(_db.delegationTasks),
                createdBy: r.readTable(uCreator),
                assignedTo: r.readTable(uAssignee),
              ))
          .toList(growable: false);
    });
  }

  Future<int> createDelegationTask({
    required String title,
    String? description,
    required int createdByUserId,
    required int assignedToUserId,
    DateTime? dueAt,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw const FormatException('Title is required');

    return _db.into(_db.delegationTasks).insert(
          DelegationTasksCompanion.insert(
            title: trimmed,
            description: drift.Value(description?.trim().isEmpty == true ? null : description?.trim()),
            createdByUserId: createdByUserId,
            assignedToUserId: assignedToUserId,
            dueAt: drift.Value(dueAt),
          ),
        );
  }

  Future<void> setDelegationTaskStatus({
    required int taskId,
    required String status,
  }) async {
    if (status != 'open' && status != 'done' && status != 'cancelled') {
      throw const FormatException('Invalid status');
    }

    await (_db.update(_db.delegationTasks)..where((t) => t.id.equals(taskId))).write(
      DelegationTasksCompanion(
        status: drift.Value(status),
        completedAt: drift.Value(status == 'done' ? DateTime.now() : null),
        isDirty: const drift.Value(true),
      ),
    );
  }

  // -------------------- Staff appraisals --------------------

  Stream<List<StaffAppraisalRow>> watchStaffAppraisals({int limit = 50}) {
    final q = _db.select(_db.staffAppraisals)
      ..orderBy([
        (t) => drift.OrderingTerm(expression: t.updatedAt, mode: drift.OrderingMode.desc),
      ])
      ..limit(limit);

    final joined = q.join([
      drift.innerJoin(_db.staff, _db.staff.id.equalsExp(_db.staffAppraisals.staffId)),
      drift.innerJoin(_db.users, _db.users.id.equalsExp(_db.staff.userId)),
    ]);

    return joined.watch().map((rows) {
      return rows
          .map((r) => StaffAppraisalRow(
                appraisal: r.readTable(_db.staffAppraisals),
                staff: r.readTable(_db.staff),
                user: r.readTable(_db.users),
              ))
          .toList(growable: false);
    });
  }

  Future<int> createStaffAppraisal({
    required int staffId,
    required int periodYear,
    int? periodTerm,
    double? score,
    String? notes,
    required int createdByUserId,
  }) async {
    if (periodYear < 2000 || periodYear > 3000) {
      throw const FormatException('Invalid year');
    }

    if (score != null && (score.isNaN || score.isInfinite || score < 0)) {
      throw const FormatException('Invalid score');
    }

    return _db.into(_db.staffAppraisals).insert(
          StaffAppraisalsCompanion.insert(
            staffId: staffId,
            periodYear: periodYear,
            periodTerm: drift.Value(periodTerm),
            score: drift.Value(score),
            notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
            createdByUserId: createdByUserId,
          ),
        );
  }

  // -------------------- Compliance checklist --------------------

  Stream<List<ComplianceChecklistItem>> watchChecklistItems({bool activeOnly = true}) {
    final q = _db.select(_db.complianceChecklistItems);
    if (activeOnly) {
      q.where((t) => t.isActive.equals(true));
    }
    q.orderBy([(t) => drift.OrderingTerm(expression: t.createdAt, mode: drift.OrderingMode.desc)]);
    return q.watch();
  }

  Future<int> addChecklistItem({required String title, String category = 'general'}) async {
    final t = title.trim();
    if (t.isEmpty) throw const FormatException('Title is required');

    return _db.into(_db.complianceChecklistItems).insert(
          ComplianceChecklistItemsCompanion.insert(
            title: t,
            category: category.trim().isEmpty ? const drift.Value('general') : drift.Value(category.trim()),
          ),
        );
  }

  Stream<ComplianceProgress> watchComplianceProgress({
    required int academicYear,
    required int term,
  }) {
    final itemsCountExp = _db.complianceChecklistItems.id.count(filter: _db.complianceChecklistItems.isActive.equals(true));
    final doneCountExp = _db.complianceChecklistCompletions.id.count(
      filter: _db.complianceChecklistCompletions.academicYear.equals(academicYear) &
          _db.complianceChecklistCompletions.term.equals(term),
    );

    final q = _db.selectOnly(_db.complianceChecklistItems)
      ..addColumns([itemsCountExp, doneCountExp]);

    return q.watchSingle().map((row) {
      final total = row.read(itemsCountExp) ?? 0;
      final done = row.read(doneCountExp) ?? 0;
      return ComplianceProgress(totalItems: total, completedItems: done);
    });
  }

  Stream<Set<int>> watchCompletedChecklistItemIds({
    required int academicYear,
    required int term,
  }) {
    final q = _db.select(_db.complianceChecklistCompletions)
      ..where((t) => t.academicYear.equals(academicYear) & t.term.equals(term));

    return q.watch().map((rows) => rows.map((r) => r.checklistItemId).toSet());
  }

  Future<void> setChecklistItemCompleted({
    required int checklistItemId,
    required bool completed,
    required int academicYear,
    required int term,
    required int completedByUserId,
    String? notes,
  }) async {
    final existing = await (_db.select(_db.complianceChecklistCompletions)
          ..where((t) => t.checklistItemId.equals(checklistItemId) & t.academicYear.equals(academicYear) & t.term.equals(term))
          ..limit(1))
        .getSingleOrNull();

    if (completed) {
      if (existing != null) return;
      await _db.into(_db.complianceChecklistCompletions).insert(
            ComplianceChecklistCompletionsCompanion.insert(
              checklistItemId: checklistItemId,
              completedByUserId: completedByUserId,
              academicYear: drift.Value(academicYear),
              term: drift.Value(term),
              notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
            ),
          );
    } else {
      if (existing == null) return;
      await (_db.delete(_db.complianceChecklistCompletions)..where((t) => t.id.equals(existing.id))).go();
    }
  }
}
