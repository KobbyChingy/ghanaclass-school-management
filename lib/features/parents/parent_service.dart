import 'package:drift/drift.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for managing parent accounts and parent-related operations
class ParentService {
  final AppDatabase _database;
  ParentService(this._database);

  /// Get parent account by id
  Future<ParentAccount?> getParentById(int id) async {
    return await (_database.select(_database.parentAccounts)..where((p) => p.id.equals(id))).getSingleOrNull();
  }

  /// Create a new parent account linked to a student
  Future<int> createParentAccount({
    required int studentId,
    required String parentName,
    required String email,
    required String password,
    required String phoneNumber,
    required String relationship,
  }) async {
    final passwordHash = _hashPassword(password);
    final companion = ParentAccountsCompanion.insert(
      studentId: studentId,
      parentName: parentName.trim(),
      email: email.toLowerCase().trim(),
      passwordHash: passwordHash,
      phoneNumber: phoneNumber.trim(),
      relationship: relationship.trim(),
      isDirty: const Value(true),
    );
    return await _database.into(_database.parentAccounts).insert(companion);
  }

  /// Hashes a password using SHA256
  // ...existing code...

  /// Get school calendar (term dates, events) for a student
  Future<List<Map<String, dynamic>>> getStudentCalendar(int studentId) async {
    final reports = await (_database.select(_database.reportSummaries)
          ..where((r) => r.studentId.equals(studentId)))
        .get();
    final events = <Map<String, dynamic>>[];
    for (final r in reports) {
      events.add({
        'date': r.nextTermBegins,
        'title': 'Next Term Begins',
      });
      events.add({
        'date': r.updatedAt,
        'title': 'Report Card Issued',
      });
    }
    // TODO: Add more events from other tables if needed
    return events;
  }

  /// Get timetable (subjects offered in class) for a student
  Future<List<String>> getStudentTimetable(int studentId) async {
    final student = await (_database.select(_database.students)
          ..where((s) => s.id.equals(studentId)))
        .getSingleOrNull();
    if (student == null || student.classId == null) return [];

    final offerings = await (_database.select(_database.classSubjectOfferings)
          ..where((o) => o.classId.equals(student.classId!)))
        .get();
    final subjectIds = offerings.map((o) => o.subjectId).toList();
    if (subjectIds.isEmpty) return [];

    final subjects = await (_database.select(_database.schoolSubjects)
          ..where((s) => s.id.isIn(subjectIds)))
        .get();
    return subjects.map((s) => s.subjectName).toList();
  }

  /// Get lesson notes (assignments/homework) for a student (by class/subjects)
  Future<List<LessonNote>> getStudentLessonNotes(int studentId) async {
    final student = await (_database.select(_database.students)
          ..where((s) => s.id.equals(studentId)))
        .getSingleOrNull();
    if (student == null || student.classId == null) return [];

    final notes = await (_database.select(_database.lessonNotes)
          ..where((n) => n.classId.equals(student.classId!)))
        .get();
    return notes;
  }

  /// Creates a parent account for a student if none exists, otherwise updates the existing account and resets the password.
  Future<ParentAccount> upsertParentAccountForStudent({
    required int studentId,
    required String parentName,
    required String email,
    required String password,
    required String phoneNumber,
    required String relationship,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();
    if (normalizedEmail.isEmpty) throw Exception('Parent email is required.');
    if (password.trim().isEmpty) throw Exception('Parent password is required.');
    if (phoneNumber.trim().isEmpty) throw Exception('Parent phone number is required.');
    if (parentName.trim().isEmpty) throw Exception('Parent name is required.');
    if (relationship.trim().isEmpty) throw Exception('Parent relationship is required.');
    final existing = await getParentForStudent(studentId);
    final passwordHash = _hashPassword(password);
    if (existing == null) {
      final id = await createParentAccount(
        studentId: studentId,
        parentName: parentName.trim(),
        email: normalizedEmail,
        password: password,
        phoneNumber: phoneNumber.trim(),
        relationship: relationship.trim(),
      );
      final created = await getParentById(id);
      if (created == null) {
        throw Exception('Failed to create parent account.');
      }
      if (created.passwordHash != passwordHash) {
        throw Exception('Parent login could not be created. Please try again.');
      }
      return created;
    }
    final updated = await updateParentAccount(
      ParentAccountsCompanion(
        id: Value(existing.id),
        studentId: Value(studentId),
        parentName: Value(parentName.trim()),
        email: Value(normalizedEmail),
        passwordHash: Value(passwordHash),
        phoneNumber: Value(phoneNumber.trim()),
        relationship: Value(relationship.trim()),
        isActive: const Value(true),
        lastLoginAt: const Value.absent(),
        remoteId: const Value.absent(),
        lastSyncedAt: const Value.absent(),
        isDirty: const Value(true),
        createdAt: const Value.absent(),
      ),
    );
    if (!updated) throw Exception('Failed to update parent account.');
    final refreshed = await getParentById(existing.id);
    if (refreshed == null) throw Exception('Parent account not found after update.');
    if (refreshed.passwordHash != passwordHash) {
      throw Exception('Parent login could not be updated. Please try again.');
    }
    return refreshed;
  }

  Future<ParentAccount?> getParentByEmail(String email) async {
    return await (_database.select(_database.parentAccounts)
          ..where((p) => p.email.equals(email.toLowerCase().trim())))
        .getSingleOrNull();
  }

  Future<void> updateParentPhoneNumber({
    required int parentId,
    required String phoneNumber,
  }) async {
    final parent = await getParentById(parentId);
    if (parent == null) throw Exception('Parent account not found.');
    await _database.update(_database.parentAccounts).replace(
          parent.copyWith(phoneNumber: phoneNumber.trim()),
        );
  }

  Future<void> updateParentPassword({
    required int parentId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final parent = await getParentById(parentId);
    if (parent == null) throw Exception('Parent account not found.');
    if (!parent.isActive) throw Exception('Parent account is inactive.');
    final oldHash = _hashPassword(oldPassword);
    if (parent.passwordHash != oldHash) {
      throw Exception('Current password is incorrect.');
    }
    final newHash = _hashPassword(newPassword);
    await _database.update(_database.parentAccounts).replace(
          parent.copyWith(passwordHash: newHash),
        );
  }

  Future<ParentAccount?> verifyParentLogin(String email, String password) async {
    final parent = await getParentByEmail(email);
    if (parent == null) return null;
    final passwordHash = _hashPassword(password);
    if (parent.passwordHash == passwordHash && parent.isActive) {
      await _database.update(_database.parentAccounts).replace(
        parent.copyWith(lastLoginAt: Value(DateTime.now())),
      );
      return parent;
    }
    return null;
  }

  Future<bool> canParentLogin(String email, String password) async {
    final parent = await getParentByEmail(email);
    if (parent == null) return false;
    if (!parent.isActive) return false;
    return parent.passwordHash == _hashPassword(password);
  }

  Future<List<Student>> getChildrenForParent(int parentId) async {
    final parent = await (_database.select(_database.parentAccounts)
          ..where((p) => p.id.equals(parentId)))
        .getSingleOrNull();
    if (parent == null) return [];
    final student = await (_database.select(_database.students)
          ..where((s) => s.id.equals(parent.studentId)))
        .getSingleOrNull();
    return student != null ? [student] : [];
  }

  Future<Map<String, dynamic>> getStudentFinancialSummary(int studentId) async {
    final student = await (_database.select(_database.students)
          ..where((s) => s.id.equals(studentId)))
        .getSingleOrNull();
    if (student == null) {
      return {'error': 'Student not found'};
    }
    final payments = await (_database.select(_database.payments)
          ..where((p) => p.studentId.equals(studentId)))
        .get();
    final totalPaid = payments.fold<double>(0, (sum, p) => sum + p.amountPaid);
    final balance = student.enrolledFees - totalPaid;
    return {
      'totalFees': student.enrolledFees,
      'totalPaid': totalPaid,
      'balance': balance,
      'recentPayments': payments.take(5).toList(),
    };
  }

  Future<Map<String, dynamic>> getStudentAttendanceSummary(int studentId) async {
    final records = await (_database.select(_database.attendanceRecords)
          ..where((r) => r.studentId.equals(studentId)))
        .get();
    final totalDays = records.length;
    final presentDays = records.where((r) => r.status == 'present').length;
    final absentDays = records.where((r) => r.status == 'absent').length;
    final lateDays = records.where((r) => r.status == 'late').length;
    final attendanceRate = totalDays > 0 ? (presentDays / totalDays * 100) : 0.0;
    return {
      'totalDays': totalDays,
      'presentDays': presentDays,
      'absentDays': absentDays,
      'lateDays': lateDays,
      'attendanceRate': attendanceRate,
    };
  }

  Future<List<TermResult>> getStudentRecentGrades(int studentId) async {
    return await (_database.select(_database.termResults)
          ..where((r) => r.studentId.equals(studentId))
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(10))
        .get();
  }

  Future<int> sendMessageToTeacher({
    required int parentId,
    required int studentId,
    required int? teacherId,
    required String subject,
    required String message,
  }) async {
    final companion = ParentMessagesCompanion.insert(
      parentId: parentId,
      teacherId: Value(teacherId),
      studentId: studentId,
      subject: subject,
      message: message,
      senderType: 'parent',
    );
    return await _database.into(_database.parentMessages).insert(companion);
  }

  Future<int> sendMessageToParent({
    required int parentId,
    required int studentId,
    required int teacherId,
    required String subject,
    required String message,
  }) async {
    final companion = ParentMessagesCompanion.insert(
      parentId: parentId,
      teacherId: Value(teacherId),
      studentId: studentId,
      subject: subject,
      message: message,
      senderType: 'teacher',
    );
    return await _database.into(_database.parentMessages).insert(companion);
  }

  Future<ParentAccount?> getParentForStudent(int studentId) async {
    return await (_database.select(_database.parentAccounts)..where((p) => p.studentId.equals(studentId))).getSingleOrNull();
  }

  Future<List<ParentMessage>> getTeacherParentThread({
    required int parentId,
    required int studentId,
    required int teacherId,
  }) async {
    return await (_database.select(_database.parentMessages)
          ..where((m) => m.parentId.equals(parentId) & m.studentId.equals(studentId))
          ..where((m) => m.teacherId.isNull() | m.teacherId.equals(teacherId))
          ..orderBy([(m) => OrderingTerm.asc(m.sentAt)]))
        .get();
  }

  Future<void> markThreadAsReadForTeacher({
    required int parentId,
    required int studentId,
    required int teacherId,
  }) async {
    await (_database.update(_database.parentMessages)
          ..where((m) => m.parentId.equals(parentId) & m.studentId.equals(studentId))
          ..where((m) => m.senderType.equals('parent'))
          ..where((m) => m.isRead.equals(false))
          ..where((m) => m.teacherId.isNull() | m.teacherId.equals(teacherId)))
        .write(const ParentMessagesCompanion(isRead: Value(true)));
  }

  Future<List<ParentMessage>> getParentMessages(int parentId) async {
    return await (_database.select(_database.parentMessages)
          ..where((m) => m.parentId.equals(parentId))
          ..orderBy([(m) => OrderingTerm.desc(m.sentAt)]))
        .get();
  }

  Future<void> markMessageAsRead(int messageId) async {
    final message = await (_database.select(_database.parentMessages)
          ..where((m) => m.id.equals(messageId)))
        .getSingleOrNull();
    if (message != null) {
      await _database.update(_database.parentMessages).replace(
        message.copyWith(isRead: true),
      );
    }
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<List<ParentAccount>> getAllParents() async {
    return await _database.select(_database.parentAccounts).get();
  }

  Future<bool> updateParentAccount(ParentAccountsCompanion companion) async {
    return await (_database.update(_database.parentAccounts)
          ..where((p) => p.id.equals(companion.id.value)))
        .write(companion) > 0;
  }

  Future<void> deactivateParentAccount(int parentId) async {
    final parent = await (_database.select(_database.parentAccounts)
          ..where((p) => p.id.equals(parentId)))
        .getSingleOrNull();
    if (parent != null) {
      await _database.update(_database.parentAccounts).replace(
        parent.copyWith(isActive: false),
      );
    }
  }
}
