import 'dart:convert';
import 'package:http/http.dart' as http;

/// Abstraction for sending SMS messages.
///
/// The UI/providers should depend on this interface so the underlying
/// implementation can be swapped later (e.g. different SMS vendor).
abstract interface class SmsGateway {
  Future<SmsResult> sendSms({
    required String phoneNumber,
    required String message,
  });

  Future<SmsResult> sendBulkAnnouncement({
    required List<String> phoneNumbers,
    required String announcement,
  });
}

/// SMS Service using Africa's Talking API
/// Supports sending SMS notifications to parents and staff
class SmsService implements SmsGateway {
  final String _apiKey;
  final String _username;
  final String _senderId;
  
  static const String _baseUrl = 'https://api.africastalking.com/version1/messaging';
  
  SmsService({
    required String apiKey,
    required String username,
    String senderId = 'SCHOOL',
  })  : _apiKey = apiKey,
        _username = username,
        _senderId = senderId;

  String _signature() {
    final s = _senderId.trim();
    return s.isEmpty ? 'School' : s;
  }
  
  /// Send SMS to a single recipient
  @override
  Future<SmsResult> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    return await _sendBulkSms(
      phoneNumbers: [phoneNumber],
      message: message,
    );
  }
  
  /// Send SMS to multiple recipients
  Future<SmsResult> _sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    try {
      // Format phone numbers (Africa's Talking expects +233... format)
      final formattedNumbers = phoneNumbers.map((phone) {
        if (!phone.startsWith('+')) {
          // Assume Ghana (+233) if no country code
          return '+233${phone.replaceFirst(RegExp(r'^0'), '')}';
        }
        return phone;
      }).join(',');
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'apiKey': _apiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: {
          'username': _username,
          'to': formattedNumbers,
          'message': message,
          'from': _senderId,
        },
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final recipients = data['SMSMessageData']['Recipients'] as List;
        
        // Check if any message was sent successfully
        final successCount = recipients.where((r) => r['status'] == 'Success').length;
        
        return SmsResult(
          success: successCount > 0,
          messageId: recipients.isNotEmpty ? recipients[0]['messageId'] : null,
          message: successCount > 0 
              ? 'SMS sent to $successCount recipient(s)'
              : 'Failed to send SMS',
          recipientCount: successCount,
        );
      } else {
        return SmsResult(
          success: false,
          message: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return SmsResult(
        success: false,
        message: 'Error sending SMS: $e',
      );
    }
  }
  
  /// Send fee reminder SMS
  Future<SmsResult> sendFeeReminder({
    required String phoneNumber,
    required String studentName,
    required double balance,
  }) async {
    final message = 'Dear Parent, your child $studentName has an outstanding fee balance of GH₵${balance.toStringAsFixed(2)}. Please make payment at your earliest convenience. - ${_signature()}';
    return await sendSms(phoneNumber: phoneNumber, message: message);
  }
  
  /// Send attendance alert SMS
  Future<SmsResult> sendAttendanceAlert({
    required String phoneNumber,
    required String studentName,
    required DateTime date,
  }) async {
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final message = 'Dear Parent, your child $studentName was marked absent on $dateStr. Please contact the school if this is incorrect. - ${_signature()}';
    return await sendSms(phoneNumber: phoneNumber, message: message);
  }
  
  /// Send exam notification SMS
  Future<SmsResult> sendExamNotification({
    required String phoneNumber,
    required String studentName,
    required String examTitle,
    required DateTime examDate,
  }) async {
    final dateStr = '${examDate.day}/${examDate.month}/${examDate.year}';
    final message = 'Dear Parent, $studentName has an upcoming exam: $examTitle on $dateStr. Please ensure they are well prepared. - ${_signature()}';
    return await sendSms(phoneNumber: phoneNumber, message: message);
  }
  
  /// Send custom announcement to multiple parents
  @override
  Future<SmsResult> sendBulkAnnouncement({
    required List<String> phoneNumbers,
    required String announcement,
  }) async {
    return await _sendBulkSms(
      phoneNumbers: phoneNumbers,
      message: announcement,
    );
  }
}

/// Result of an SMS sending operation
class SmsResult {
  final bool success;
  final String? messageId;
  final String message;
  final int recipientCount;
  
  SmsResult({
    required this.success,
    this.messageId,
    required this.message,
    this.recipientCount = 0,
  });
}
