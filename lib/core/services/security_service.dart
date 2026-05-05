import 'package:drift/drift.dart' as drift;

import 'package:ghanaclass_school_management/core/database/app_database.dart';

class SecurityVisitorEntryWithMeta {
  final SecurityVisitorEntry entry;
  final User? createdBy;

  const SecurityVisitorEntryWithMeta({required this.entry, required this.createdBy});

  bool get isCheckedOut => entry.checkedOutAt != null;
}

class SecurityIncidentWithMeta {
  final SecurityIncident incident;
  final User? reportedBy;

  const SecurityIncidentWithMeta({required this.incident, required this.reportedBy});

  bool get isResolved => incident.resolvedAt != null;
}

class SecurityService {
  final AppDatabase _db;

  SecurityService(this._db);

  // ----- Visitors (Gate log) -----

  Stream<List<SecurityVisitorEntryWithMeta>> watchRecentVisitorEntries({int limit = 200, bool activeOnly = false}) {
    final q = _db.select(_db.securityVisitorEntries)
      ..orderBy([
        (t) => drift.OrderingTerm.desc(t.checkedInAt),
        (t) => drift.OrderingTerm.desc(t.id),
      ])
      ..limit(limit);

    if (activeOnly) {
      q.where((t) => t.checkedOutAt.isNull());
    }

    final join = q.join([
      drift.leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.securityVisitorEntries.createdByUserId)),
    ]);

    return join.watch().map(
          (rows) => rows
              .map(
                (r) => SecurityVisitorEntryWithMeta(
                  entry: r.readTable(_db.securityVisitorEntries),
                  createdBy: r.readTableOrNull(_db.users),
                ),
              )
              .toList(),
        );
  }

  Future<int> checkInVisitor({
    required String visitorName,
    String? visitorPhone,
    String? purpose,
    String? personToSee,
    required int createdByUserId,
    String? notes,
  }) {
    return _db.into(_db.securityVisitorEntries).insert(
          SecurityVisitorEntriesCompanion.insert(
            visitorName: visitorName.trim(),
            visitorPhone: drift.Value(visitorPhone?.trim().isEmpty ?? true ? null : visitorPhone?.trim()),
            purpose: drift.Value(purpose?.trim().isEmpty ?? true ? null : purpose?.trim()),
            personToSee: drift.Value(personToSee?.trim().isEmpty ?? true ? null : personToSee?.trim()),
            createdByUserId: createdByUserId,
            notes: drift.Value(notes?.trim().isEmpty ?? true ? null : notes?.trim()),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  Future<void> checkOutVisitor(int entryId) {
    return (_db.update(_db.securityVisitorEntries)..where((t) => t.id.equals(entryId))).write(
      SecurityVisitorEntriesCompanion(
        checkedOutAt: drift.Value(DateTime.now()),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }

  // ----- Incidents -----

  Stream<List<SecurityIncidentWithMeta>> watchIncidents({bool includeResolved = true, int limit = 200}) {
    final q = _db.select(_db.securityIncidents)
      ..orderBy([
        (t) => drift.OrderingTerm.desc(t.occurredAt),
        (t) => drift.OrderingTerm.desc(t.id),
      ])
      ..limit(limit);

    if (!includeResolved) {
      q.where((t) => t.resolvedAt.isNull());
    }

    final join = q.join([
      drift.leftOuterJoin(_db.users, _db.users.id.equalsExp(_db.securityIncidents.reportedByUserId)),
    ]);

    return join.watch().map(
          (rows) => rows
              .map(
                (r) => SecurityIncidentWithMeta(
                  incident: r.readTable(_db.securityIncidents),
                  reportedBy: r.readTableOrNull(_db.users),
                ),
              )
              .toList(),
        );
  }

  Future<int> reportIncident({
    required String incidentType,
    required String severity,
    required String description,
    String? actionsTaken,
    required int reportedByUserId,
    DateTime? occurredAt,
  }) {
    return _db.into(_db.securityIncidents).insert(
          SecurityIncidentsCompanion.insert(
            incidentType: drift.Value(incidentType),
            severity: drift.Value(severity),
            description: description.trim(),
            actionsTaken: drift.Value(actionsTaken?.trim().isEmpty ?? true ? null : actionsTaken?.trim()),
            reportedByUserId: reportedByUserId,
            occurredAt: drift.Value(occurredAt ?? DateTime.now()),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );
  }

  Future<void> resolveIncident(int incidentId, {bool resolved = true}) {
    return (_db.update(_db.securityIncidents)..where((t) => t.id.equals(incidentId))).write(
      SecurityIncidentsCompanion(
        resolvedAt: drift.Value(resolved ? DateTime.now() : null),
        updatedAt: drift.Value(DateTime.now()),
      ),
    );
  }
}
