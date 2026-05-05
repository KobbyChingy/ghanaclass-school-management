import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/shop/shop_service.dart';

class ShopReceiptPdfService {
  Future<Uint8List> buildSaleReceiptPdf({
    required ShopSaleDetail detail,
    InstitutionalIdentityData? schoolInfo,
    PdfPageFormat? pageFormat,
  }) async {
    final doc = pw.Document();
    final format = pageFormat ?? PdfPageFormat.roll80;

    final fontRegular = await PdfGoogleFonts.openSansRegular();
    final fontBold = await PdfGoogleFonts.openSansBold();

    final schoolName = (schoolInfo?.schoolName.trim().isNotEmpty == true)
        ? schoolInfo!.schoolName.trim()
        : 'GhanaClass School';

    String money(double value) => 'GHS ${value.toStringAsFixed(2)}';

    doc.addPage(
      pw.Page(
        pageFormat: format,
        margin: const pw.EdgeInsets.all(16),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  schoolName,
                  style: pw.TextStyle(font: fontBold, fontSize: 13),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'Shop POS Receipt',
                  style: pw.TextStyle(font: fontRegular, fontSize: 9),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(),
              _kv('Receipt', detail.sale.receiptNo, fontRegular, fontBold),
              _kv('Date', DateFormat('dd MMM yyyy, HH:mm').format(detail.sale.soldAt), fontRegular, fontBold),
              _kv('Payment', detail.sale.paymentMethod.toUpperCase(), fontRegular, fontBold),
              _kv('Customer', detail.sale.customerName ?? detail.sale.customerType, fontRegular, fontBold),
              pw.Divider(),
              pw.Text('Items', style: pw.TextStyle(font: fontBold, fontSize: 10)),
              pw.SizedBox(height: 4),
              ...detail.lines.map((line) {
                final name = line.item?.name ?? 'Item #${line.line.itemId}';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(name, style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '${line.line.quantity.toStringAsFixed(0)} x ${money(line.line.unitPrice)}',
                            style: pw.TextStyle(font: fontRegular, fontSize: 8),
                          ),
                          pw.Text(
                            money(line.line.lineTotal),
                            style: pw.TextStyle(font: fontBold, fontSize: 8.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              pw.Divider(),
              _kv('Units', detail.totalUnits.toStringAsFixed(0), fontRegular, fontBold),
              _kv('Total', money(detail.sale.totalAmount), fontRegular, fontBold),
              if (detail.sale.paymentMethod.toLowerCase() == 'cash') ...[
                _kv('Received', money(detail.sale.amountReceived), fontRegular, fontBold),
                _kv('Change', money(detail.sale.changeGiven), fontRegular, fontBold),
              ],
              if ((detail.sale.momoReference ?? '').trim().isNotEmpty)
                _kv('MoMo Ref', detail.sale.momoReference!.trim(), fontRegular, fontBold),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your purchase',
                  style: pw.TextStyle(font: fontRegular, fontSize: 8),
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _kv(String key, String value, pw.Font regular, pw.Font bold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 2,
            child: pw.Text(key, style: pw.TextStyle(font: regular, fontSize: 8.5)),
          ),
          pw.Expanded(
            flex: 3,
            child: pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 8.5), textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }
}
