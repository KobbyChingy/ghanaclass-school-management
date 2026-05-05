import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ghanaclass_school_management/core/services/email_service.dart';
import 'package:ghanaclass_school_management/core/services/sms_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kSmsEnabledKey = 'sms_enabled';
const _kSmsUsernameKey = 'sms_africas_talking_username';
const _kSmsApiKeyKey = 'sms_africas_talking_api_key';
const _kSmsSenderIdKey = 'sms_sender_id';

const _kEmailEnabledKey = 'email_enabled';
const _kEmailSmtpHostKey = 'email_smtp_host';
const _kEmailSmtpPortKey = 'email_smtp_port';
const _kEmailSmtpUsernameKey = 'email_smtp_username';
const _kEmailSmtpPasswordKey = 'email_smtp_password';
const _kEmailFromAddressKey = 'email_from_address';
const _kEmailFromNameKey = 'email_from_name';
const _kEmailUseSslKey = 'email_smtp_use_ssl';

/// Provides a configured [SmsGateway] from locally saved settings.
///
/// Returns `null` when SMS is disabled or credentials are missing.
final smsServiceProvider = FutureProvider<SmsGateway?>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  final enabled = prefs.getBool(_kSmsEnabledKey) ?? false;
  if (!enabled) return null;

  final apiKey = (prefs.getString(_kSmsApiKeyKey) ?? '').trim();
  final username = (prefs.getString(_kSmsUsernameKey) ?? '').trim();
  final senderId = (prefs.getString(_kSmsSenderIdKey) ?? '').trim();

  if (apiKey.isEmpty || username.isEmpty) return null;

  return SmsService(
    apiKey: apiKey,
    username: username,
    senderId: senderId.isEmpty ? 'SCHOOL' : senderId,
  );
});

/// Provides a configured [EmailGateway] from locally saved settings.
///
/// Returns `null` when email is disabled or SMTP settings are missing.
final emailServiceProvider = FutureProvider<EmailGateway?>((ref) async {
  final prefs = await SharedPreferences.getInstance();

  final enabled = prefs.getBool(_kEmailEnabledKey) ?? false;
  if (!enabled) return null;

  final smtpHost = (prefs.getString(_kEmailSmtpHostKey) ?? '').trim();
  final smtpPort = prefs.getInt(_kEmailSmtpPortKey) ?? 587;
  final smtpUsername = (prefs.getString(_kEmailSmtpUsernameKey) ?? '').trim();
  final smtpPassword = (prefs.getString(_kEmailSmtpPasswordKey) ?? '').trim();
  final fromAddress = (prefs.getString(_kEmailFromAddressKey) ?? '').trim();
  final fromName = (prefs.getString(_kEmailFromNameKey) ?? '').trim();
  final useSsl = prefs.getBool(_kEmailUseSslKey) ?? false;

  if (smtpHost.isEmpty || smtpPort <= 0 || smtpUsername.isEmpty || smtpPassword.isEmpty || fromAddress.isEmpty) {
    return null;
  }

  return EmailService(
    smtpHost: smtpHost,
    smtpPort: smtpPort,
    smtpUsername: smtpUsername,
    smtpPassword: smtpPassword,
    fromAddress: fromAddress,
    fromName: fromName,
    useSsl: useSsl,
  );
});
