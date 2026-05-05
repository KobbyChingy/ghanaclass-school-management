import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Abstraction for sending emails.
///
/// The UI/providers should depend on this interface so the underlying
/// implementation can be swapped later (e.g. API-based email provider).
abstract interface class EmailGateway {
  Future<EmailSendResult> sendBulkAnnouncement({
    required List<String> recipients,
    required String subject,
    required String body,
  });
}

class EmailSendResult {
  const EmailSendResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class EmailService implements EmailGateway {
  EmailService({
    required this.smtpHost,
    required this.smtpPort,
    required this.smtpUsername,
    required this.smtpPassword,
    required this.fromAddress,
    required this.fromName,
    required this.useSsl,
  });

  final String smtpHost;
  final int smtpPort;
  final String smtpUsername;
  final String smtpPassword;
  final String fromAddress;
  final String fromName;
  final bool useSsl;

  SmtpServer _server() {
    return SmtpServer(
      smtpHost,
      port: smtpPort,
      username: smtpUsername,
      password: smtpPassword,
      ssl: useSsl,
    );
  }

  @override
  Future<EmailSendResult> sendBulkAnnouncement({
    required List<String> recipients,
    required String subject,
    required String body,
  }) async {
    final uniqueRecipients = recipients
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (uniqueRecipients.isEmpty) {
      return const EmailSendResult(success: false, message: 'No email recipients found.');
    }

    final message = Message()
      ..from = Address(fromAddress, fromName.trim().isEmpty ? null : fromName.trim())
      ..subject = subject.trim().isEmpty ? 'Announcement' : subject.trim()
      ..text = body
      ..recipients.add(fromAddress)
      ..bccRecipients.addAll(uniqueRecipients);

    try {
      await send(message, _server());
      return EmailSendResult(success: true, message: 'Email sent to ${uniqueRecipients.length} recipient(s).');
    } catch (e) {
      return EmailSendResult(success: false, message: 'Email send failed: $e');
    }
  }
}
