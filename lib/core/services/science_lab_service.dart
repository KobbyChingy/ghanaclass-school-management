import 'package:drift/drift.dart' as drift;

import 'package:ghanaclass_school_management/core/database/app_database.dart';

class ScienceBookingConflict {
  final ScienceLabBooking conflicting;

  const ScienceBookingConflict(this.conflicting);
}

class ScienceLabBookingWithMeta {
  final ScienceLabBooking booking;
  final SchoolClassesData? schoolClass;
  final SchoolSubject? subject;
  final User? requestedBy;
  final User? teacher;
  final User? approvedBy;

  const ScienceLabBookingWithMeta({
    required this.booking,
    required this.schoolClass,
    required this.subject,
    required this.requestedBy,
    required this.teacher,
    required this.approvedBy,
  });
}

class ScienceLabItemSummary {
  final ScienceLabItem item;

  const ScienceLabItemSummary(this.item);

  bool get isLowStock => item.quantity <= item.minQuantity;

  bool get isExpired => item.expiryDate != null && item.expiryDate!.isBefore(DateTime.now());
}

class ScienceLabExperimentRequestWithMeta {
  final ScienceLabExperimentRequest request;
  final ScienceLabExperimentTemplate? template;
  final SchoolClassesData? schoolClass;
  final SchoolSubject? subject;
  final User? teacher;
  final User? requestedBy;
  final User? approvedBy;

  const ScienceLabExperimentRequestWithMeta({
    required this.request,
    required this.template,
    required this.schoolClass,
    required this.subject,
    required this.teacher,
    required this.requestedBy,
    required this.approvedBy,
  });
}

class ScienceLabSafetyCheckWithMeta {
  final ScienceLabSafetyCheck check;
  final User? performedBy;

  const ScienceLabSafetyCheckWithMeta({
    required this.check,
    required this.performedBy,
  });
}

class ScienceLabIncidentWithMeta {
  final ScienceLabIncident incident;
  final User? reportedBy;
  final ScienceLabItem? relatedItem;
  final ScienceLabBooking? relatedBooking;

  const ScienceLabIncidentWithMeta({
    required this.incident,
    required this.reportedBy,
    required this.relatedItem,
    required this.relatedBooking,
  });
}

class ScienceLabUsageSessionWithMeta {
  final ScienceLabUsageSession session;
  final SchoolClassesData? schoolClass;
  final SchoolSubject? subject;
  final User? conductedBy;
  final int participants;

  const ScienceLabUsageSessionWithMeta({
    required this.session,
    required this.schoolClass,
    required this.subject,
    required this.conductedBy,
    required this.participants,
  });

  Duration get duration {
    final end = session.endedAt ?? DateTime.now();
    return end.difference(session.startedAt);
  }
}

class ScienceLabUsageParticipantWithMeta {
  final ScienceLabUsageParticipant participant;
  final Student student;

  const ScienceLabUsageParticipantWithMeta({
    required this.participant,
    required this.student,
  });
}

class ScienceLabService {
  final AppDatabase _db;

  ScienceLabService(this._db);

  // ----- Reference data -----

  Stream<List<SchoolClassesData>> watchActiveClasses() {
    return (_db.select(_db.schoolClasses)
          ..where((c) => c.isActive.equals(true))
          ..orderBy([(c) => drift.OrderingTerm.asc(c.className)]))
        .watch();
  }

  Stream<List<SchoolSubject>> watchActiveSubjects() {
    return (_db.select(_db.schoolSubjects)
          ..where((s) => s.isActive.equals(true))
          ..orderBy([(s) => drift.OrderingTerm.asc(s.subjectName)]))
        .watch();
  }

  Stream<List<User>> watchActiveTeachers() {
    return (_db.select(_db.users)
          ..where((u) => u.isActive.equals(true))
          ..where((u) => u.role.equals('teacher'))
          ..orderBy([(u) => drift.OrderingTerm.asc(u.fullName)]))
        .watch();
  }

  Stream<List<Student>> watchStudentsForClass(int classId) {
    return (_db.select(_db.students)
          ..where((s) => s.isActive.equals(true))
          ..where((s) => s.classId.equals(classId))
          ..orderBy([(s) => drift.OrderingTerm.asc(s.lastName), (s) => drift.OrderingTerm.asc(s.firstName)]))
        .watch();
  }

  // ----- Inventory -----

  Stream<List<ScienceLabItemSummary>> watchItems({String? itemType}) {
    final q = _db.select(_db.scienceLabItems);
    if (itemType != null && itemType.trim().isNotEmpty) {
      q.where((i) => i.itemType.equals(itemType.trim()));
    }
    q.orderBy([(i) => drift.OrderingTerm.asc(i.name)]);

    return q.watch().map((rows) => rows.map(ScienceLabItemSummary.new).toList(growable: false));
  }

  Stream<List<ScienceLabItemSummary>> watchLowStockItems() {
    final q = _db.select(_db.scienceLabItems)
      ..where((i) => i.quantity.isSmallerOrEqual(i.minQuantity))
      ..orderBy([(i) => drift.OrderingTerm.asc(i.name)]);
    return q.watch().map((rows) => rows.map(ScienceLabItemSummary.new).toList(growable: false));
  }

  Stream<List<ScienceLabItemSummary>> watchExpiredItems() {
    final now = DateTime.now();
    final q = _db.select(_db.scienceLabItems)
      ..where((i) => i.expiryDate.isSmallerThanValue(now))
      ..orderBy([(i) => drift.OrderingTerm.asc(i.name)]);
    return q.watch().map((rows) => rows.map(ScienceLabItemSummary.new).toList(growable: false));
  }

  Future<int> upsertItem({
    int? id,
    required String name,
    required String itemType,
    required String unit,
    required double quantity,
    required double minQuantity,
    required String condition,
    String? location,
    DateTime? expiryDate,
    String? hazardNotes,
    String? supplierName,
    String? notes,
  }) async {
    final now = DateTime.now();
    final companion = ScienceLabItemsCompanion(
      name: drift.Value(name.trim()),
      itemType: drift.Value(itemType.trim()),
      unit: drift.Value(unit.trim()),
      quantity: drift.Value(quantity),
      minQuantity: drift.Value(minQuantity),
      condition: drift.Value(condition.trim()),
      location: drift.Value(location?.trim().isEmpty == true ? null : location?.trim()),
      expiryDate: drift.Value(expiryDate),
      hazardNotes: drift.Value(hazardNotes?.trim().isEmpty == true ? null : hazardNotes?.trim()),
      supplierName: drift.Value(supplierName?.trim().isEmpty == true ? null : supplierName?.trim()),
      notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
      updatedAt: drift.Value(now),
    );

    if (id == null) {
      return _db.into(_db.scienceLabItems).insert(
            companion.copyWith(createdAt: drift.Value(now)),
          );
    }

    await (_db.update(_db.scienceLabItems)..where((i) => i.id.equals(id))).write(companion);
    return id;
  }

  Future<void> deleteItem(int id) async {
    await (_db.delete(_db.scienceLabItems)..where((i) => i.id.equals(id))).go();
  }

  // ----- Bookings -----

  Stream<List<ScienceLabBookingWithMeta>> watchBookings({DateTime? from}) {
    final start = from ?? DateTime.now().subtract(const Duration(days: 7));

    final booking = _db.scienceLabBookings;
    final cls = _db.schoolClasses;
    final subj = _db.schoolSubjects;
    final uReq = _db.alias(_db.users, 'sci_booking_requested_by');
    final uTeach = _db.alias(_db.users, 'sci_booking_teacher');
    final uAppr = _db.alias(_db.users, 'sci_booking_approved_by');

    final q = _db.select(booking).join([
      drift.leftOuterJoin(cls, cls.id.equalsExp(booking.classId)),
      drift.leftOuterJoin(subj, subj.id.equalsExp(booking.subjectId)),
      drift.leftOuterJoin(uReq, uReq.id.equalsExp(booking.requestedByUserId)),
      drift.leftOuterJoin(uTeach, uTeach.id.equalsExp(booking.teacherUserId)),
      drift.leftOuterJoin(uAppr, uAppr.id.equalsExp(booking.approvedByUserId)),
    ])
      ..where(booking.endAt.isBiggerOrEqualValue(start))
      ..orderBy([drift.OrderingTerm.desc(booking.startAt)]);

    return q.watch().map((rows) {
      return rows
          .map(
            (r) => ScienceLabBookingWithMeta(
              booking: r.readTable(booking),
              schoolClass: r.readTableOrNull(cls),
              subject: r.readTableOrNull(subj),
              requestedBy: r.readTableOrNull(uReq),
              teacher: r.readTableOrNull(uTeach),
              approvedBy: r.readTableOrNull(uAppr),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<ScienceBookingConflict?> checkBookingConflict({
    required DateTime startAt,
    required DateTime endAt,
    int? excludeBookingId,
  }) async {
    final q = _db.select(_db.scienceLabBookings)
      ..where((b) => b.status.equals('approved'))
      ..where((b) => b.startAt.isSmallerThanValue(endAt))
      ..where((b) => b.endAt.isBiggerThanValue(startAt));

    if (excludeBookingId != null) {
      q.where((b) => b.id.isNotValue(excludeBookingId));
    }

    final conflict = await q.getSingleOrNull();
    if (conflict == null) return null;
    return ScienceBookingConflict(conflict);
  }

  Future<int> createBooking({
    required DateTime startAt,
    required DateTime endAt,
    required int requestedByUserId,
    int? classId,
    int? subjectId,
    int? teacherUserId,
    required String title,
    String? notes,
  }) async {
    final conflict = await checkBookingConflict(startAt: startAt, endAt: endAt);
    if (conflict != null) {
      throw Exception('Booking conflicts with an existing approved booking.');
    }

    return _db.into(_db.scienceLabBookings).insert(
          ScienceLabBookingsCompanion.insert(
            startAt: startAt,
            endAt: endAt,
            requestedByUserId: requestedByUserId,
            classId: drift.Value(classId),
            subjectId: drift.Value(subjectId),
            teacherUserId: drift.Value(teacherUserId),
            title: title.trim(),
            notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
          ),
        );
  }

  Future<void> setBookingStatus({
    required int bookingId,
    required String status,
    required int actedByUserId,
  }) async {
    final now = DateTime.now();

    await (_db.update(_db.scienceLabBookings)..where((b) => b.id.equals(bookingId))).write(
      ScienceLabBookingsCompanion(
        status: drift.Value(status),
        approvedByUserId: drift.Value(status == 'approved' ? actedByUserId : null),
        approvedAt: drift.Value(status == 'approved' ? now : null),
      ),
    );
  }

  // ----- Experiments -----

  Stream<List<ScienceLabExperimentTemplate>> watchExperimentTemplates() {
    final q = _db.select(_db.scienceLabExperimentTemplates)
      ..orderBy([(t) => drift.OrderingTerm.asc(t.title)]);
    return q.watch();
  }

  Future<int> upsertExperimentTemplate({
    int? id,
    required String title,
    String? description,
    String? materials,
    String? steps,
    required int estimatedMinutes,
  }) async {
    final now = DateTime.now();
    final writes = ScienceLabExperimentTemplatesCompanion(
      title: drift.Value(title.trim()),
      description: drift.Value(description?.trim().isEmpty == true ? null : description?.trim()),
      materials: drift.Value(materials?.trim().isEmpty == true ? null : materials?.trim()),
      steps: drift.Value(steps?.trim().isEmpty == true ? null : steps?.trim()),
      estimatedMinutes: drift.Value(estimatedMinutes),
      updatedAt: drift.Value(now),
    );

    if (id == null) {
      return _db.into(_db.scienceLabExperimentTemplates).insert(
            writes.copyWith(createdAt: drift.Value(now)),
          );
    }

    await (_db.update(_db.scienceLabExperimentTemplates)..where((t) => t.id.equals(id))).write(writes);
    return id;
  }

  Future<void> deleteExperimentTemplate(int id) async {
    await (_db.delete(_db.scienceLabExperimentTemplates)..where((t) => t.id.equals(id))).go();
  }

  Stream<List<ScienceLabExperimentRequestWithMeta>> watchExperimentRequests({DateTime? from}) {
    final start = from ?? DateTime.now().subtract(const Duration(days: 60));

    final r = _db.scienceLabExperimentRequests;
    final t = _db.scienceLabExperimentTemplates;
    final cls = _db.schoolClasses;
    final subj = _db.schoolSubjects;
    final uTeach = _db.alias(_db.users, 'sci_request_teacher');
    final uReq = _db.alias(_db.users, 'sci_request_requested_by');
    final uAppr = _db.alias(_db.users, 'sci_request_approved_by');

    final q = _db.select(r).join([
      drift.leftOuterJoin(t, t.id.equalsExp(r.templateId)),
      drift.leftOuterJoin(cls, cls.id.equalsExp(r.classId)),
      drift.leftOuterJoin(subj, subj.id.equalsExp(r.subjectId)),
      drift.leftOuterJoin(uTeach, uTeach.id.equalsExp(r.teacherUserId)),
      drift.leftOuterJoin(uReq, uReq.id.equalsExp(r.requestedByUserId)),
      drift.leftOuterJoin(uAppr, uAppr.id.equalsExp(r.approvedByUserId)),
    ])
      ..where(r.createdAt.isBiggerOrEqualValue(start))
      ..orderBy([drift.OrderingTerm.desc(r.createdAt)]);

    return q.watch().map((rows) {
      return rows
          .map(
            (row) => ScienceLabExperimentRequestWithMeta(
              request: row.readTable(r),
              template: row.readTableOrNull(t),
              schoolClass: row.readTableOrNull(cls),
              subject: row.readTableOrNull(subj),
              teacher: row.readTableOrNull(uTeach),
              requestedBy: row.readTableOrNull(uReq),
              approvedBy: row.readTableOrNull(uAppr),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<int> createExperimentRequest({
    int? templateId,
    required String title,
    required int requestedByUserId,
    int? teacherUserId,
    int? classId,
    int? subjectId,
    DateTime? scheduledAt,
    String? prepChecklist,
    String? notes,
  }) async {
    return _db.into(_db.scienceLabExperimentRequests).insert(
          ScienceLabExperimentRequestsCompanion.insert(
            templateId: drift.Value(templateId),
            title: title.trim(),
            classId: drift.Value(classId),
            subjectId: drift.Value(subjectId),
            teacherUserId: drift.Value(teacherUserId),
            requestedByUserId: requestedByUserId,
            scheduledAt: drift.Value(scheduledAt),
            prepChecklist: drift.Value(prepChecklist?.trim().isEmpty == true ? null : prepChecklist?.trim()),
            notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
          ),
        );
  }

  Future<void> setExperimentRequestStatus({
    required int requestId,
    required String status,
    required int actedByUserId,
  }) async {
    final now = DateTime.now();

    await (_db.update(_db.scienceLabExperimentRequests)..where((r) => r.id.equals(requestId))).write(
      ScienceLabExperimentRequestsCompanion(
        status: drift.Value(status),
        approvedByUserId: drift.Value(status == 'approved' ? actedByUserId : null),
        approvedAt: drift.Value(status == 'approved' ? now : null),
      ),
    );
  }

  // ----- Safety checks -----

  Stream<List<ScienceLabSafetyCheckWithMeta>> watchSafetyChecks({DateTime? from}) {
    final start = from ?? DateTime.now().subtract(const Duration(days: 90));

    final c = _db.scienceLabSafetyChecks;
    final u = _db.users;

    final q = _db.select(c).join([
      drift.leftOuterJoin(u, u.id.equalsExp(c.performedByUserId)),
    ])
      ..where(c.checkDate.isBiggerOrEqualValue(start))
      ..orderBy([drift.OrderingTerm.desc(c.checkDate), drift.OrderingTerm.desc(c.createdAt)]);

    return q.watch().map((rows) {
      return rows
          .map(
            (r) => ScienceLabSafetyCheckWithMeta(
              check: r.readTable(c),
              performedBy: r.readTableOrNull(u),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<int> upsertSafetyCheck({
    int? id,
    required DateTime checkDate,
    required int performedByUserId,
    required bool fireExtinguisherOk,
    required bool firstAidOk,
    required bool ventilationOk,
    required bool waterOk,
    required bool gasOk,
    required bool electricityOk,
    required bool wasteDisposalOk,
    String? notes,
  }) async {
    final normalizedDate = DateTime(checkDate.year, checkDate.month, checkDate.day);

    final writes = ScienceLabSafetyChecksCompanion(
      checkDate: drift.Value(normalizedDate),
      performedByUserId: drift.Value(performedByUserId),
      fireExtinguisherOk: drift.Value(fireExtinguisherOk),
      firstAidOk: drift.Value(firstAidOk),
      ventilationOk: drift.Value(ventilationOk),
      waterOk: drift.Value(waterOk),
      gasOk: drift.Value(gasOk),
      electricityOk: drift.Value(electricityOk),
      wasteDisposalOk: drift.Value(wasteDisposalOk),
      notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
    );

    if (id == null) {
      // If a row for this date exists (unique key), update it.
      final existing = await (_db.select(_db.scienceLabSafetyChecks)..where((c) => c.checkDate.equals(normalizedDate))).getSingleOrNull();
      if (existing != null) {
        await (_db.update(_db.scienceLabSafetyChecks)..where((c) => c.id.equals(existing.id))).write(writes);
        return existing.id;
      }

      return _db.into(_db.scienceLabSafetyChecks).insert(
            ScienceLabSafetyChecksCompanion.insert(
              checkDate: normalizedDate,
              performedByUserId: performedByUserId,
              fireExtinguisherOk: drift.Value(fireExtinguisherOk),
              firstAidOk: drift.Value(firstAidOk),
              ventilationOk: drift.Value(ventilationOk),
              waterOk: drift.Value(waterOk),
              gasOk: drift.Value(gasOk),
              electricityOk: drift.Value(electricityOk),
              wasteDisposalOk: drift.Value(wasteDisposalOk),
              notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
            ),
          );
    }

    await (_db.update(_db.scienceLabSafetyChecks)..where((c) => c.id.equals(id))).write(writes);
    return id;
  }

  // ----- Incidents -----

  Stream<List<ScienceLabIncidentWithMeta>> watchIncidents({DateTime? from}) {
    final start = from ?? DateTime.now().subtract(const Duration(days: 180));

    final i = _db.scienceLabIncidents;
    final u = _db.users;
    final item = _db.scienceLabItems;
    final b = _db.scienceLabBookings;

    final q = _db.select(i).join([
      drift.leftOuterJoin(u, u.id.equalsExp(i.reportedByUserId)),
      drift.leftOuterJoin(item, item.id.equalsExp(i.relatedItemId)),
      drift.leftOuterJoin(b, b.id.equalsExp(i.relatedBookingId)),
    ])
      ..where(i.occurredAt.isBiggerOrEqualValue(start))
      ..orderBy([drift.OrderingTerm.desc(i.occurredAt)]);

    return q.watch().map((rows) {
      return rows
          .map(
            (r) => ScienceLabIncidentWithMeta(
              incident: r.readTable(i),
              reportedBy: r.readTableOrNull(u),
              relatedItem: r.readTableOrNull(item),
              relatedBooking: r.readTableOrNull(b),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<int> createIncident({
    required int reportedByUserId,
    DateTime? occurredAt,
    required String severity,
    required String incidentType,
    int? relatedItemId,
    int? relatedBookingId,
    required String description,
    String? actionsTaken,
  }) async {
    return _db.into(_db.scienceLabIncidents).insert(
          ScienceLabIncidentsCompanion.insert(
            occurredAt: drift.Value(occurredAt ?? DateTime.now()),
            reportedByUserId: reportedByUserId,
            severity: drift.Value(severity.trim()),
            incidentType: drift.Value(incidentType.trim()),
            relatedItemId: drift.Value(relatedItemId),
            relatedBookingId: drift.Value(relatedBookingId),
            description: description.trim(),
            actionsTaken: drift.Value(actionsTaken?.trim().isEmpty == true ? null : actionsTaken?.trim()),
          ),
        );
  }

  Future<void> resolveIncident({
    required int incidentId,
  }) async {
    await (_db.update(_db.scienceLabIncidents)..where((i) => i.id.equals(incidentId))).write(
      ScienceLabIncidentsCompanion(resolvedAt: drift.Value(DateTime.now())),
    );
  }

  Future<void> updateIncident({
    required int incidentId,
    DateTime? occurredAt,
    String? severity,
    String? incidentType,
    int? relatedItemId,
    int? relatedBookingId,
    String? description,
    String? actionsTaken,
    DateTime? resolvedAt,
  }) async {
    final companion = ScienceLabIncidentsCompanion(
      occurredAt: occurredAt == null ? const drift.Value.absent() : drift.Value(occurredAt),
      severity: severity == null ? const drift.Value.absent() : drift.Value(severity.trim()),
      incidentType: incidentType == null ? const drift.Value.absent() : drift.Value(incidentType.trim()),
      relatedItemId: const drift.Value.absent(),
      relatedBookingId: const drift.Value.absent(),
      description: description == null ? const drift.Value.absent() : drift.Value(description.trim()),
      actionsTaken: drift.Value(actionsTaken?.trim().isEmpty == true ? null : actionsTaken?.trim()),
      resolvedAt: resolvedAt == null ? const drift.Value.absent() : drift.Value(resolvedAt),
    );

    final writes = companion.copyWith(
      relatedItemId: drift.Value(relatedItemId),
      relatedBookingId: drift.Value(relatedBookingId),
    );

    await (_db.update(_db.scienceLabIncidents)..where((i) => i.id.equals(incidentId))).write(writes);
  }

  // ----- Usage sessions -----

  Stream<List<ScienceLabUsageSessionWithMeta>> watchUsageSessions({DateTime? from}) {
    final start = from ?? DateTime.now().subtract(const Duration(days: 30));

    final s = _db.scienceLabUsageSessions;
    final cls = _db.schoolClasses;
    final subj = _db.schoolSubjects;
    final u = _db.users;

    final pCount = _db.scienceLabUsageParticipants.id.count();

    final q = _db.select(s).join([
      drift.leftOuterJoin(cls, cls.id.equalsExp(s.classId)),
      drift.leftOuterJoin(subj, subj.id.equalsExp(s.subjectId)),
      drift.leftOuterJoin(u, u.id.equalsExp(s.conductedByUserId)),
    ])
      ..where(s.startedAt.isBiggerOrEqualValue(start))
      ..orderBy([drift.OrderingTerm.desc(s.startedAt)]);

    return q.watch().asyncMap((rows) async {
      final sessions = rows.map((r) => r.readTable(s)).toList(growable: false);
      final ids = sessions.map((e) => e.id).toList(growable: false);

      final counts = <int, int>{};
      if (ids.isNotEmpty) {
        final cQ = _db.selectOnly(_db.scienceLabUsageParticipants)
          ..addColumns([_db.scienceLabUsageParticipants.sessionId, pCount])
          ..where(_db.scienceLabUsageParticipants.sessionId.isIn(ids))
          ..groupBy([_db.scienceLabUsageParticipants.sessionId]);

        final cRows = await cQ.get();
        for (final r in cRows) {
          counts[r.read(_db.scienceLabUsageParticipants.sessionId)!] = r.read(pCount) ?? 0;
        }
      }

      return rows
          .map((r) {
            final session = r.readTable(s);
            return ScienceLabUsageSessionWithMeta(
              session: session,
              schoolClass: r.readTableOrNull(cls),
              subject: r.readTableOrNull(subj),
              conductedBy: r.readTableOrNull(u),
              participants: counts[session.id] ?? 0,
            );
          })
          .toList(growable: false);
    });
  }

  Future<int> startUsageSession({
    int? bookingId,
    required int conductedByUserId,
    int? classId,
    int? subjectId,
    String? experimentTitle,
    String? notes,
  }) async {
    return _db.into(_db.scienceLabUsageSessions).insert(
          ScienceLabUsageSessionsCompanion.insert(
            bookingId: drift.Value(bookingId),
            conductedByUserId: conductedByUserId,
            classId: drift.Value(classId),
            subjectId: drift.Value(subjectId),
            experimentTitle: drift.Value(experimentTitle?.trim().isEmpty == true ? null : experimentTitle?.trim()),
            notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
          ),
        );
  }

  Future<void> endUsageSession(int sessionId) async {
    await (_db.update(_db.scienceLabUsageSessions)..where((s) => s.id.equals(sessionId))).write(
      ScienceLabUsageSessionsCompanion(endedAt: drift.Value(DateTime.now())),
    );
  }

  Stream<List<ScienceLabUsageParticipantWithMeta>> watchParticipantsWithMeta(int sessionId) {
    final p = _db.scienceLabUsageParticipants;
    final s = _db.students;

    final q = _db.select(p).join([
      drift.innerJoin(s, s.id.equalsExp(p.studentId)),
    ])
      ..where(p.sessionId.equals(sessionId))
      ..orderBy([
        drift.OrderingTerm.asc(s.lastName),
        drift.OrderingTerm.asc(s.firstName),
        drift.OrderingTerm.asc(p.checkInAt),
      ]);

    return q.watch().map((rows) {
      return rows
          .map(
            (r) => ScienceLabUsageParticipantWithMeta(
              participant: r.readTable(p),
              student: r.readTable(s),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<int> addParticipant({
    required int sessionId,
    required int studentId,
    String role = 'participant',
  }) async {
    // Prevent adding if session ended.
    final session = await (_db.select(_db.scienceLabUsageSessions)..where((s) => s.id.equals(sessionId))).getSingleOrNull();
    if (session == null) throw Exception('Session not found.');
    if (session.endedAt != null) throw Exception('Cannot add participants to an ended session.');

    return _db.into(_db.scienceLabUsageParticipants).insert(
          ScienceLabUsageParticipantsCompanion.insert(
            sessionId: sessionId,
            studentId: studentId,
            role: drift.Value(role.trim()),
          ),
          mode: drift.InsertMode.insertOrIgnore,
        );
  }

  Future<void> removeParticipant(int participantId) async {
    await (_db.delete(_db.scienceLabUsageParticipants)..where((p) => p.id.equals(participantId))).go();
  }

  // ----- Report helpers (date-range snapshots) -----

  Future<List<ScienceLabBookingWithMeta>> getBookings({required DateTime from, required DateTime to}) async {
    final booking = _db.scienceLabBookings;
    final cls = _db.schoolClasses;
    final subj = _db.schoolSubjects;
    final uReq = _db.alias(_db.users, 'sci_booking_requested_by');
    final uTeach = _db.alias(_db.users, 'sci_booking_teacher');
    final uAppr = _db.alias(_db.users, 'sci_booking_approved_by');

    final q = _db.select(booking).join([
      drift.leftOuterJoin(cls, cls.id.equalsExp(booking.classId)),
      drift.leftOuterJoin(subj, subj.id.equalsExp(booking.subjectId)),
      drift.leftOuterJoin(uReq, uReq.id.equalsExp(booking.requestedByUserId)),
      drift.leftOuterJoin(uTeach, uTeach.id.equalsExp(booking.teacherUserId)),
      drift.leftOuterJoin(uAppr, uAppr.id.equalsExp(booking.approvedByUserId)),
    ])
      ..where(booking.startAt.isBetweenValues(from, to))
      ..orderBy([drift.OrderingTerm.asc(booking.startAt)]);

    final rows = await q.get();
    return rows
        .map(
          (r) => ScienceLabBookingWithMeta(
            booking: r.readTable(booking),
            schoolClass: r.readTableOrNull(cls),
            subject: r.readTableOrNull(subj),
            requestedBy: r.readTableOrNull(uReq),
            teacher: r.readTableOrNull(uTeach),
            approvedBy: r.readTableOrNull(uAppr),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ScienceLabUsageSessionWithMeta>> getUsageSessions({required DateTime from, required DateTime to}) async {
    final s = _db.scienceLabUsageSessions;
    final cls = _db.schoolClasses;
    final subj = _db.schoolSubjects;
    final u = _db.users;

    final pCount = _db.scienceLabUsageParticipants.id.count();

    final q = _db.select(s).join([
      drift.leftOuterJoin(cls, cls.id.equalsExp(s.classId)),
      drift.leftOuterJoin(subj, subj.id.equalsExp(s.subjectId)),
      drift.leftOuterJoin(u, u.id.equalsExp(s.conductedByUserId)),
    ])
      ..where(s.startedAt.isBetweenValues(from, to))
      ..orderBy([drift.OrderingTerm.asc(s.startedAt)]);

    final rows = await q.get();
    final sessions = rows.map((r) => r.readTable(s)).toList(growable: false);
    final ids = sessions.map((e) => e.id).toList(growable: false);

    final counts = <int, int>{};
    if (ids.isNotEmpty) {
      final cQ = _db.selectOnly(_db.scienceLabUsageParticipants)
        ..addColumns([_db.scienceLabUsageParticipants.sessionId, pCount])
        ..where(_db.scienceLabUsageParticipants.sessionId.isIn(ids))
        ..groupBy([_db.scienceLabUsageParticipants.sessionId]);

      final cRows = await cQ.get();
      for (final r in cRows) {
        counts[r.read(_db.scienceLabUsageParticipants.sessionId)!] = r.read(pCount) ?? 0;
      }
    }

    return rows
        .map(
          (r) {
            final session = r.readTable(s);
            return ScienceLabUsageSessionWithMeta(
              session: session,
              schoolClass: r.readTableOrNull(cls),
              subject: r.readTableOrNull(subj),
              conductedBy: r.readTableOrNull(u),
              participants: counts[session.id] ?? 0,
            );
          },
        )
        .toList(growable: false);
  }

  Future<List<ScienceLabIncidentWithMeta>> getIncidents({required DateTime from, required DateTime to}) async {
    final i = _db.scienceLabIncidents;
    final u = _db.users;
    final item = _db.scienceLabItems;
    final b = _db.scienceLabBookings;

    final q = _db.select(i).join([
      drift.leftOuterJoin(u, u.id.equalsExp(i.reportedByUserId)),
      drift.leftOuterJoin(item, item.id.equalsExp(i.relatedItemId)),
      drift.leftOuterJoin(b, b.id.equalsExp(i.relatedBookingId)),
    ])
      ..where(i.occurredAt.isBetweenValues(from, to))
      ..orderBy([drift.OrderingTerm.asc(i.occurredAt)]);

    final rows = await q.get();
    return rows
        .map(
          (r) => ScienceLabIncidentWithMeta(
            incident: r.readTable(i),
            reportedBy: r.readTableOrNull(u),
            relatedItem: r.readTableOrNull(item),
            relatedBooking: r.readTableOrNull(b),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ScienceLabSafetyCheckWithMeta>> getSafetyChecks({required DateTime from, required DateTime to}) async {
    final c = _db.scienceLabSafetyChecks;
    final u = _db.users;

    final q = _db.select(c).join([
      drift.leftOuterJoin(u, u.id.equalsExp(c.performedByUserId)),
    ])
      ..where(c.checkDate.isBetweenValues(from, to))
      ..orderBy([drift.OrderingTerm.asc(c.checkDate)]);

    final rows = await q.get();
    return rows
        .map(
          (r) => ScienceLabSafetyCheckWithMeta(
            check: r.readTable(c),
            performedBy: r.readTableOrNull(u),
          ),
        )
        .toList(growable: false);
  }

  Future<List<ScienceLabItemSummary>> getItemsSnapshot() async {
    final rows = await (_db.select(_db.scienceLabItems)..orderBy([(i) => drift.OrderingTerm.asc(i.name)])).get();
    return rows.map(ScienceLabItemSummary.new).toList(growable: false);
  }
}
