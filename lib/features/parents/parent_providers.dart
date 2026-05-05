import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/database_provider.dart';
import 'package:ghanaclass_school_management/features/parents/parent_service.dart';

// Parent Service Provider
final parentServiceProvider = Provider<ParentService>((ref) {
  final database = ref.watch(databaseProvider);
  return ParentService(database);
});
