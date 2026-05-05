import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';

/// Singleton-ish database provider for the app.
///
/// Screens should depend on this instead of creating their own AppDatabase.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});
