import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

class PdfPreviewScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? pdfFileName;
  final bool canChangePageFormat;
  final bool canChangeOrientation;
  final FutureOr<Uint8List> Function(PdfPageFormat format) buildPdf;

  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.buildPdf,
    this.subtitle,
    this.pdfFileName,
    this.canChangePageFormat = true,
    this.canChangeOrientation = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveFileName = (pdfFileName ?? '').trim().isEmpty ? null : pdfFileName!.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Container(
        color: theme.colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle != null && subtitle!.trim().isNotEmpty)
                          Text(
                            subtitle!.trim(),
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        if (effectiveFileName != null)
                          Text(
                            effectiveFileName,
                            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'Preview',
                    style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: theme.dividerColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: PdfPreview(
                    build: (format) async {
                      final bytes = await buildPdf(format);
                      return bytes;
                    },
                    pdfFileName: pdfFileName,
                    canChangePageFormat: canChangePageFormat,
                    canChangeOrientation: canChangeOrientation,
                    allowPrinting: true,
                    allowSharing: true,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
