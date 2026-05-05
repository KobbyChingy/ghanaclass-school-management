import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/providers/auth_providers.dart';
import 'package:ghanaclass_school_management/core/providers/communication_providers.dart';
import 'package:ghanaclass_school_management/features/director/director_communication_service.dart';

final directorCommunicationServiceProvider = Provider<DirectorCommunicationService>((ref) {
  final db = ref.watch(databaseProvider);
  final sms = ref.watch(smsServiceProvider).value;
  final email = ref.watch(emailServiceProvider).value;

  return DirectorCommunicationService(
    db,
    smsGateway: sms,
    emailGateway: email,
  );
});

final directorRecentNotificationsProvider = StreamProvider((ref) {
  return ref.watch(directorCommunicationServiceProvider).watchRecentNotifications(limit: 25);
});
