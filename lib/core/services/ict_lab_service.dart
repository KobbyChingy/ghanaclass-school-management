import 'package:drift/drift.dart' as drift;

import 'package:ghanaclass_school_management/core/database/app_database.dart';

class BookingConflict {
  final IctLabBooking conflicting;

  const BookingConflict(this.conflicting);
}

class IctLabBookingWithMeta {
  final IctLabBooking booking;
  final SchoolClassesData? schoolClass;
  final SchoolSubject? subject;
  final User? requestedBy;
  final User? teacher;
  final User? approvedBy;

  const IctLabBookingWithMeta({
    required this.booking,
    required this.schoolClass,
    required this.subject,
    required this.requestedBy,
    required this.teacher,
    required this.approvedBy,
  });
}

class IctLabDeviceWithOpenTickets {
  final IctLabDevice device;
  final int openTickets;

  const IctLabDeviceWithOpenTickets({required this.device, required this.openTickets});
}

class IctLabUsageSessionWithMeta {
  final IctLabUsageSession session;
  final SchoolClassesData? schoolClass;
  final SchoolSubject? subject;
  final User? conductedBy;
  final int participants;

  const IctLabUsageSessionWithMeta({
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

class IctLabUsageParticipantWithMeta {
  final IctLabUsageParticipant participant;
  final Student student;
  final IctLabDevice? device;

  const IctLabUsageParticipantWithMeta({
    required this.participant,
    required this.student,
    required this.device,
  });
}

class IctLabMaintenanceTicketWithMeta {
  final IctLabMaintenanceTicket ticket;
  final IctLabDevice device;
  final User? reportedBy;

  const IctLabMaintenanceTicketWithMeta({
    required this.ticket,
    required this.device,
    required this.reportedBy,
  });
}

class IctLabDeviceLoanWithMeta {
  final IctLabDeviceLoan loan;
  final IctLabDevice device;
  final Student? borrowerStudent;
  final User? borrowerUser;
  final User? issuedBy;
  final User? returnedBy;

  const IctLabDeviceLoanWithMeta({
    required this.loan,
    required this.device,
    required this.borrowerStudent,
    required this.borrowerUser,
    required this.issuedBy,
    required this.returnedBy,
  });

  bool get isReturned => loan.returnedAt != null;

  String get borrowerName {
    final s = borrowerStudent;
    if (s != null) return '${s.lastName} ${s.firstName}'.trim();
    final u = borrowerUser;
    if (u != null) return u.fullName;
    return 'Unknown';
  }
}

class IctLabService {
  final AppDatabase _db;

  IctLabService(this._db);

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

        Stream<List<User>> watchActiveStaffUsers() {
          // Active (non-parent) users. This is used for device checkout to staff.
          return (_db.select(_db.users)
            ..where((u) => u.isActive.equals(true))
            ..where((u) => u.role.isNotValue('parent'))
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

  // ----- Devices -----

  Stream<List<IctLabDeviceWithOpenTickets>> watchDevicesWithOpenTickets() {
    final openCount = _db.ictLabMaintenanceTickets.id.count(
      filter: _db.ictLabMaintenanceTickets.status.equals('open') | _db.ictLabMaintenanceTickets.status.equals('in_progress'),
    );

    final q = _db.select(_db.ictLabDevices);
    q.orderBy([(d) => drift.OrderingTerm.asc(d.seatLabel), (d) => drift.OrderingTerm.asc(d.name)]);

    return q.watch().asyncMap((devices) async {
      if (devices.isEmpty) return const <IctLabDeviceWithOpenTickets>[];

      final deviceIds = devices.map((d) => d.id).toList(growable: false);
      final agg = _db.selectOnly(_db.ictLabMaintenanceTickets)
        ..addColumns([
          _db.ictLabMaintenanceTickets.deviceId,
          openCount,
        ])
        ..where(_db.ictLabMaintenanceTickets.deviceId.isIn(deviceIds))
        ..groupBy([_db.ictLabMaintenanceTickets.deviceId]);

      final rows = await agg.get();
      final byDevice = <int, int>{
        for (final r in rows)
          r.read(_db.ictLabMaintenanceTickets.deviceId)!: (r.read(openCount) ?? 0),
      };

      return devices
          .map((d) => IctLabDeviceWithOpenTickets(device: d, openTickets: byDevice[d.id] ?? 0))
          .toList(growable: false);
    });
  }

  Future<int> upsertDevice({
    int? id,
    required String name,
    String? assetTag,
    required String deviceType,
    required String status,
    String? seatLabel,
    String? notes,
  }) async {
    final now = DateTime.now();
    final companion = IctLabDevicesCompanion(
      name: drift.Value(name.trim()),
      assetTag: drift.Value(assetTag?.trim().isEmpty == true ? null : assetTag?.trim()),
      deviceType: drift.Value(deviceType.trim()),
      status: drift.Value(status.trim()),
      seatLabel: drift.Value(seatLabel?.trim().isEmpty == true ? null : seatLabel?.trim()),
      notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
      updatedAt: drift.Value(now),
    );

    if (id == null) {
      return await _db.into(_db.ictLabDevices).insert(
            companion.copyWith(createdAt: drift.Value(now)),
          );
    }

    await (_db.update(_db.ictLabDevices)..where((d) => d.id.equals(id))).write(companion);
    return id;
  }

  Future<void> deleteDevice(int id) async {
    await (_db.delete(_db.ictLabDevices)..where((d) => d.id.equals(id))).go();
  }

  // ----- Bookings -----

  Stream<List<IctLabBookingWithMeta>> watchBookings({DateTime? from}) {
    final start = from ?? DateTime.now().subtract(const Duration(days: 7));

    final booking = _db.ictLabBookings;
    final cls = _db.schoolClasses;
    final subj = _db.schoolSubjects;
    final uReq = _db.users;
    final uTeach = _db.users;
    final uAppr = _db.users;

    final q = _db.select(booking).join([
      drift.leftOuterJoin(cls, cls.id.equalsExp(booking.classId)),
      drift.leftOuterJoin(subj, subj.id.equalsExp(booking.subjectId)),
      drift.leftOuterJoin(uReq, uReq.id.equalsExp(booking.requestedByUserId)),
      drift.leftOuterJoin(uTeach, uTeach.id.equalsExp(booking.teacherUserId)),
      drift.leftOuterJoin(uAppr, uAppr.id.equalsExp(booking.approvedByUserId)),
    ])
      ..where(booking.endAt.isBiggerOrEqualValue(start))
      ..orderBy([
        drift.OrderingTerm.desc(booking.startAt),
      ]);

    return q.watch().map((rows) {
      return rows.map((r) {
        return IctLabBookingWithMeta(
          booking: r.readTable(booking),
          schoolClass: r.readTableOrNull(cls),
          subject: r.readTableOrNull(subj),
          requestedBy: r.readTableOrNull(uReq),
          teacher: r.readTableOrNull(uTeach),
          approvedBy: r.readTableOrNull(uAppr),
        );
      }).toList(growable: false);
    });
  }

  Future<BookingConflict?> checkBookingConflict({
    required DateTime startAt,
    required DateTime endAt,
    int? excludeBookingId,
  }) async {
    // Overlap condition: existing.start < new.end AND existing.end > new.start
    final q = _db.select(_db.ictLabBookings)
      ..where((b) => b.status.equals('approved'))
      ..where((b) => b.startAt.isSmallerThanValue(endAt))
      ..where((b) => b.endAt.isBiggerThanValue(startAt));

    if (excludeBookingId != null) {
      q.where((b) => b.id.isNotValue(excludeBookingId));
    }

    final conflict = await q.getSingleOrNull();
    if (conflict == null) return null;
    return BookingConflict(conflict);
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

    return await _db.into(_db.ictLabBookings).insert(
          IctLabBookingsCompanion.insert(
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

    final writes = IctLabBookingsCompanion(
      status: drift.Value(status),
      approvedByUserId: drift.Value(status == 'approved' ? actedByUserId : null),
      approvedAt: drift.Value(status == 'approved' ? now : null),
    );

    await (_db.update(_db.ictLabBookings)..where((b) => b.id.equals(bookingId))).write(writes);
  }

  // ----- Usage sessions -----

  Stream<List<IctLabUsageSessionWithMeta>> watchUsageSessions({DateTime? from}) {
    final start = from ?? DateTime.now().subtract(const Duration(days: 30));

    final s = _db.ictLabUsageSessions;
    final cls = _db.schoolClasses;
    final subj = _db.schoolSubjects;
    final u = _db.users;

    final pCount = _db.ictLabUsageParticipants.id.count();

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
        final cQ = _db.selectOnly(_db.ictLabUsageParticipants)
          ..addColumns([_db.ictLabUsageParticipants.sessionId, pCount])
          ..where(_db.ictLabUsageParticipants.sessionId.isIn(ids))
          ..groupBy([_db.ictLabUsageParticipants.sessionId]);

        final cRows = await cQ.get();
        for (final r in cRows) {
          counts[r.read(_db.ictLabUsageParticipants.sessionId)!] = r.read(pCount) ?? 0;
        }
      }

      return rows.map((r) {
        final session = r.readTable(s);
        return IctLabUsageSessionWithMeta(
          session: session,
          schoolClass: r.readTableOrNull(cls),
          subject: r.readTableOrNull(subj),
          conductedBy: r.readTableOrNull(u),
          participants: counts[session.id] ?? 0,
        );
      }).toList(growable: false);
    });
  }

  Future<int> startUsageSession({
    int? bookingId,
    required int conductedByUserId,
    int? classId,
    int? subjectId,
    String? notes,
  }) async {
    return await _db.into(_db.ictLabUsageSessions).insert(
          IctLabUsageSessionsCompanion.insert(
            bookingId: drift.Value(bookingId),
            conductedByUserId: conductedByUserId,
            classId: drift.Value(classId),
            subjectId: drift.Value(subjectId),
            notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
          ),
        );
  }

  Future<void> endUsageSession(int sessionId) async {
    await (_db.update(_db.ictLabUsageSessions)..where((s) => s.id.equals(sessionId))).write(
      IctLabUsageSessionsCompanion(endedAt: drift.Value(DateTime.now())),
    );
  }

  Stream<List<IctLabUsageParticipant>> watchParticipants(int sessionId) {
    return (_db.select(_db.ictLabUsageParticipants)..where((p) => p.sessionId.equals(sessionId))).watch();
  }

  Stream<List<IctLabUsageParticipantWithMeta>> watchParticipantsWithMeta(int sessionId) {
    final p = _db.ictLabUsageParticipants;
    final s = _db.students;
    final d = _db.ictLabDevices;

    final q = _db.select(p).join([
      drift.innerJoin(s, s.id.equalsExp(p.studentId)),
      drift.leftOuterJoin(d, d.id.equalsExp(p.deviceId)),
    ])
      ..where(p.sessionId.equals(sessionId))
      ..orderBy([
        drift.OrderingTerm.asc(s.lastName),
        drift.OrderingTerm.asc(s.firstName),
        drift.OrderingTerm.asc(p.checkInAt),
      ]);

    return q.watch().map((rows) {
      return rows
          .map((r) => IctLabUsageParticipantWithMeta(
                participant: r.readTable(p),
                student: r.readTable(s),
                device: r.readTableOrNull(d),
              ))
          .toList(growable: false);
    });
  }

  Future<void> addParticipant({
    required int sessionId,
    required int studentId,
    int? deviceId,
  }) async {
    await _db.into(_db.ictLabUsageParticipants).insert(
          IctLabUsageParticipantsCompanion.insert(
            sessionId: sessionId,
            studentId: studentId,
            deviceId: drift.Value(deviceId),
          ),
          mode: drift.InsertMode.insertOrIgnore,
        );
  }

  Future<void> checkoutParticipant(int participantId) async {
    await (_db.update(_db.ictLabUsageParticipants)..where((p) => p.id.equals(participantId))).write(
      IctLabUsageParticipantsCompanion(checkOutAt: drift.Value(DateTime.now())),
    );
  }

  // ----- Maintenance -----

  Stream<List<IctLabMaintenanceTicketWithMeta>> watchMaintenanceTickets({String status = 'open'}) {
    final t = _db.ictLabMaintenanceTickets;
    final d = _db.ictLabDevices;
    final u = _db.users;

    final q = _db.select(t).join([
      drift.innerJoin(d, d.id.equalsExp(t.deviceId)),
      drift.leftOuterJoin(u, u.id.equalsExp(t.reportedByUserId)),
    ])
      ..where(t.status.equals(status))
      ..orderBy([drift.OrderingTerm.desc(t.createdAt)]);

    return q.watch().map((rows) {
      return rows.map((r) {
        return IctLabMaintenanceTicketWithMeta(
          ticket: r.readTable(t),
          device: r.readTable(d),
          reportedBy: r.readTableOrNull(u),
        );
      }).toList(growable: false);
    });
  }

  Future<int> createMaintenanceTicket({
    required int deviceId,
    required int reportedByUserId,
    required String title,
    String? description,
    String priority = 'normal',
  }) async {
    return await _db.into(_db.ictLabMaintenanceTickets).insert(
          IctLabMaintenanceTicketsCompanion.insert(
            deviceId: deviceId,
            reportedByUserId: reportedByUserId,
            title: title.trim(),
            description: drift.Value(description?.trim().isEmpty == true ? null : description?.trim()),
            priority: drift.Value(priority.trim()),
          ),
        );
  }

  Future<void> updateTicketStatus({
    required int ticketId,
    required String status,
  }) async {
    await (_db.update(_db.ictLabMaintenanceTickets)..where((t) => t.id.equals(ticketId))).write(
      IctLabMaintenanceTicketsCompanion(
        status: drift.Value(status),
        resolvedAt: drift.Value(status == 'resolved' || status == 'closed' ? DateTime.now() : null),
      ),
    );
  }

  // ----- Device checkout (loans) -----

  Stream<List<IctLabDevice>> watchAvailableDevicesForCheckout() {
    final d = _db.ictLabDevices;
    final l = _db.ictLabDeviceLoans;

    final q = _db.select(d).join([
      drift.leftOuterJoin(
        l,
        l.deviceId.equalsExp(d.id) & l.returnedAt.isNull(),
      ),
    ])
      ..where(l.id.isNull())
      ..orderBy([
        drift.OrderingTerm.asc(d.seatLabel),
        drift.OrderingTerm.asc(d.name),
      ]);

    return q.watch().map((rows) => rows.map((r) => r.readTable(d)).toList(growable: false));
  }

  Stream<List<IctLabDeviceLoanWithMeta>> watchDeviceLoans({bool activeOnly = true}) {
    final l = _db.ictLabDeviceLoans;
    final d = _db.ictLabDevices;
    final s = _db.students;
    final uBorrow = _db.users;
    final uIssue = _db.users;
    final uReturn = _db.users;

    final q = _db.select(l).join([
      drift.innerJoin(d, d.id.equalsExp(l.deviceId)),
      drift.leftOuterJoin(s, s.id.equalsExp(l.borrowerStudentId)),
      drift.leftOuterJoin(uBorrow, uBorrow.id.equalsExp(l.borrowerUserId)),
      drift.leftOuterJoin(uIssue, uIssue.id.equalsExp(l.issuedByUserId)),
      drift.leftOuterJoin(uReturn, uReturn.id.equalsExp(l.returnedByUserId)),
    ]);

    if (activeOnly) {
      q.where(l.returnedAt.isNull());
    }

    q.orderBy([
      drift.OrderingTerm.desc(l.issuedAt),
    ]);

    return q.watch().map((rows) {
      return rows
          .map(
            (r) => IctLabDeviceLoanWithMeta(
              loan: r.readTable(l),
              device: r.readTable(d),
              borrowerStudent: r.readTableOrNull(s),
              borrowerUser: r.readTableOrNull(uBorrow),
              issuedBy: r.readTableOrNull(uIssue),
              returnedBy: r.readTableOrNull(uReturn),
            ),
          )
          .toList(growable: false);
    });
  }

  Future<int> issueDevice({
    required int deviceId,
    int? borrowerStudentId,
    int? borrowerUserId,
    required int issuedByUserId,
    DateTime? dueAt,
    String? notes,
  }) async {
    final hasStudent = borrowerStudentId != null;
    final hasUser = borrowerUserId != null;
    if (hasStudent == hasUser) {
      throw Exception('Select exactly one borrower (student or staff).');
    }

    final existing = await (_db.select(_db.ictLabDeviceLoans)
          ..where((l) => l.deviceId.equals(deviceId))
          ..where((l) => l.returnedAt.isNull()))
        .getSingleOrNull();
    if (existing != null) {
      throw Exception('This device is already checked out.');
    }

    return await _db.into(_db.ictLabDeviceLoans).insert(
          IctLabDeviceLoansCompanion.insert(
            deviceId: deviceId,
            borrowerStudentId: drift.Value(borrowerStudentId),
            borrowerUserId: drift.Value(borrowerUserId),
            issuedByUserId: issuedByUserId,
            dueAt: drift.Value(dueAt),
            notes: drift.Value(notes?.trim().isEmpty == true ? null : notes?.trim()),
          ),
        );
  }

  Future<void> returnDevice({
    required int loanId,
    required int returnedByUserId,
  }) async {
    final now = DateTime.now();
    await (_db.update(_db.ictLabDeviceLoans)..where((l) => l.id.equals(loanId))).write(
      IctLabDeviceLoansCompanion(
        returnedAt: drift.Value(now),
        returnedByUserId: drift.Value(returnedByUserId),
      ),
    );
  }

  // ----- Reports helpers -----

  Future<List<IctLabBookingWithMeta>> getBookings({DateTime? from, DateTime? to}) async {
    final booking = _db.ictLabBookings;
    final cls = _db.schoolClasses;
    final subj = _db.schoolSubjects;
    final uReq = _db.users;
    final uTeach = _db.users;
    final uAppr = _db.users;

    final q = _db.select(booking).join([
      drift.leftOuterJoin(cls, cls.id.equalsExp(booking.classId)),
      drift.leftOuterJoin(subj, subj.id.equalsExp(booking.subjectId)),
      drift.leftOuterJoin(uReq, uReq.id.equalsExp(booking.requestedByUserId)),
      drift.leftOuterJoin(uTeach, uTeach.id.equalsExp(booking.teacherUserId)),
      drift.leftOuterJoin(uAppr, uAppr.id.equalsExp(booking.approvedByUserId)),
    ]);

    if (from != null) {
      q.where(booking.endAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where(booking.startAt.isSmallerOrEqualValue(to));
    }

    q.orderBy([drift.OrderingTerm.desc(booking.startAt)]);

    final rows = await q.get();
    return rows
        .map(
          (r) => IctLabBookingWithMeta(
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

  Future<List<IctLabUsageSessionWithMeta>> getUsageSessions({DateTime? from, DateTime? to}) async {
    final s = _db.ictLabUsageSessions;
    final cls = _db.schoolClasses;
    final subj = _db.schoolSubjects;
    final u = _db.users;

    final pCount = _db.ictLabUsageParticipants.id.count();

    final q = _db.select(s).join([
      drift.leftOuterJoin(cls, cls.id.equalsExp(s.classId)),
      drift.leftOuterJoin(subj, subj.id.equalsExp(s.subjectId)),
      drift.leftOuterJoin(u, u.id.equalsExp(s.conductedByUserId)),
    ]);

    if (from != null) {
      q.where(s.startedAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where(s.startedAt.isSmallerOrEqualValue(to));
    }

    q.orderBy([drift.OrderingTerm.desc(s.startedAt)]);

    final rows = await q.get();
    final sessions = rows.map((r) => r.readTable(s)).toList(growable: false);
    final ids = sessions.map((e) => e.id).toList(growable: false);

    final counts = <int, int>{};
    if (ids.isNotEmpty) {
      final cQ = _db.selectOnly(_db.ictLabUsageParticipants)
        ..addColumns([_db.ictLabUsageParticipants.sessionId, pCount])
        ..where(_db.ictLabUsageParticipants.sessionId.isIn(ids))
        ..groupBy([_db.ictLabUsageParticipants.sessionId]);

      final cRows = await cQ.get();
      for (final r in cRows) {
        counts[r.read(_db.ictLabUsageParticipants.sessionId)!] = r.read(pCount) ?? 0;
      }
    }

    return rows
        .map(
          (r) {
            final session = r.readTable(s);
            return IctLabUsageSessionWithMeta(
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

  Future<List<IctLabMaintenanceTicketWithMeta>> getMaintenanceTickets({
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final t = _db.ictLabMaintenanceTickets;
    final d = _db.ictLabDevices;
    final u = _db.users;

    final q = _db.select(t).join([
      drift.innerJoin(d, d.id.equalsExp(t.deviceId)),
      drift.leftOuterJoin(u, u.id.equalsExp(t.reportedByUserId)),
    ]);

    if (status != null) {
      q.where(t.status.equals(status));
    }
    if (from != null) {
      q.where(t.createdAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where(t.createdAt.isSmallerOrEqualValue(to));
    }

    q.orderBy([drift.OrderingTerm.desc(t.createdAt)]);

    final rows = await q.get();
    return rows
        .map(
          (r) => IctLabMaintenanceTicketWithMeta(
            ticket: r.readTable(t),
            device: r.readTable(d),
            reportedBy: r.readTableOrNull(u),
          ),
        )
        .toList(growable: false);
  }

  Future<List<IctLabDeviceLoanWithMeta>> getDeviceLoans({DateTime? from, DateTime? to}) async {
    final l = _db.ictLabDeviceLoans;
    final d = _db.ictLabDevices;
    final s = _db.students;
    final uBorrow = _db.users;
    final uIssue = _db.users;
    final uReturn = _db.users;

    final q = _db.select(l).join([
      drift.innerJoin(d, d.id.equalsExp(l.deviceId)),
      drift.leftOuterJoin(s, s.id.equalsExp(l.borrowerStudentId)),
      drift.leftOuterJoin(uBorrow, uBorrow.id.equalsExp(l.borrowerUserId)),
      drift.leftOuterJoin(uIssue, uIssue.id.equalsExp(l.issuedByUserId)),
      drift.leftOuterJoin(uReturn, uReturn.id.equalsExp(l.returnedByUserId)),
    ]);

    if (from != null) {
      q.where(l.issuedAt.isBiggerOrEqualValue(from));
    }
    if (to != null) {
      q.where(l.issuedAt.isSmallerOrEqualValue(to));
    }

    q.orderBy([drift.OrderingTerm.desc(l.issuedAt)]);

    final rows = await q.get();
    return rows
        .map(
          (r) => IctLabDeviceLoanWithMeta(
            loan: r.readTable(l),
            device: r.readTable(d),
            borrowerStudent: r.readTableOrNull(s),
            borrowerUser: r.readTableOrNull(uBorrow),
            issuedBy: r.readTableOrNull(uIssue),
            returnedBy: r.readTableOrNull(uReturn),
          ),
        )
        .toList(growable: false);
  }
}
