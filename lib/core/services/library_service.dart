import 'package:drift/drift.dart' as drift;

import 'package:ghanaclass_school_management/core/database/app_database.dart';

class LibraryLoanWithMeta {
  final LibraryLoan loan;
  final LibraryBook book;
  final User? issuedBy;
  final User? returnedBy;

  const LibraryLoanWithMeta({
    required this.loan,
    required this.book,
    required this.issuedBy,
    required this.returnedBy,
  });

  bool get isReturned => loan.returnedAt != null;
}

class LibraryService {
  final AppDatabase _db;

  LibraryService(this._db);

  // ----- Catalog -----

  Stream<List<LibraryBook>> watchBooks() {
    return (_db.select(_db.libraryBooks)
          ..orderBy([(t) => drift.OrderingTerm.asc(t.title)]))
        .watch();
  }

  Future<int> upsertBook({
    int? id,
    required String title,
    String? author,
    String? isbn,
    String? category,
    int totalCopies = 1,
    String? notes,
  }) async {
    final comp = LibraryBooksCompanion(
      title: drift.Value(title.trim()),
      author: drift.Value(author?.trim().isEmpty ?? true ? null : author?.trim()),
      isbn: drift.Value(isbn?.trim().isEmpty ?? true ? null : isbn?.trim()),
      category: drift.Value(category?.trim().isEmpty ?? true ? null : category?.trim()),
      totalCopies: drift.Value(totalCopies < 1 ? 1 : totalCopies),
      notes: drift.Value(notes?.trim().isEmpty ?? true ? null : notes?.trim()),
      updatedAt: drift.Value(DateTime.now()),
    );

    if (id == null) {
      return _db.into(_db.libraryBooks).insert(comp);
    }

    await (_db.update(_db.libraryBooks)..where((t) => t.id.equals(id))).write(comp);
    return id;
  }

  Future<void> deleteBook(int id) {
    return (_db.delete(_db.libraryBooks)..where((t) => t.id.equals(id))).go();
  }

  // ----- Loans -----

  Stream<List<LibraryLoanWithMeta>> watchLoans({bool activeOnly = false, int limit = 250}) {
    final q = _db.select(_db.libraryLoans)
      ..orderBy([
        (t) => drift.OrderingTerm.desc(t.issuedAt),
        (t) => drift.OrderingTerm.desc(t.id),
      ])
      ..limit(limit);

    if (activeOnly) {
      q.where((t) => t.returnedAt.isNull());
    }

    final issuedByAlias = _db.alias(_db.users, 'lib_issued_by');
    final returnedByAlias = _db.alias(_db.users, 'lib_returned_by');

    final join = q.join([
      drift.innerJoin(_db.libraryBooks, _db.libraryBooks.id.equalsExp(_db.libraryLoans.bookId)),
      drift.leftOuterJoin(issuedByAlias, issuedByAlias.id.equalsExp(_db.libraryLoans.issuedByUserId)),
      drift.leftOuterJoin(returnedByAlias, returnedByAlias.id.equalsExp(_db.libraryLoans.returnedByUserId)),
    ]);

    return join.watch().map(
          (rows) => rows
              .map(
                (r) => LibraryLoanWithMeta(
                  loan: r.readTable(_db.libraryLoans),
                  book: r.readTable(_db.libraryBooks),
                  issuedBy: r.readTableOrNull(issuedByAlias),
                  returnedBy: r.readTableOrNull(returnedByAlias),
                ),
              )
              .toList(),
        );
  }

  Future<int> issueLoan({
    required int bookId,
    required String borrowerType,
    int? borrowerStudentId,
    int? borrowerUserId,
    required String borrowerName,
    required int issuedByUserId,
    DateTime? dueAt,
    String? notes,
  }) {
    return _db.into(_db.libraryLoans).insert(
          LibraryLoansCompanion.insert(
            bookId: bookId,
            borrowerType: drift.Value(borrowerType.trim()),
            borrowerStudentId: drift.Value(borrowerStudentId),
            borrowerUserId: drift.Value(borrowerUserId),
            borrowerName: borrowerName.trim(),
            issuedByUserId: issuedByUserId,
            dueAt: drift.Value(dueAt),
            notes: drift.Value(notes?.trim().isEmpty ?? true ? null : notes?.trim()),
          ),
        );
  }

  Future<void> returnLoan({required int loanId, required int returnedByUserId}) {
    return (_db.update(_db.libraryLoans)..where((t) => t.id.equals(loanId))).write(
      LibraryLoansCompanion(
        returnedAt: drift.Value(DateTime.now()),
        returnedByUserId: drift.Value(returnedByUserId),
      ),
    );
  }
}
