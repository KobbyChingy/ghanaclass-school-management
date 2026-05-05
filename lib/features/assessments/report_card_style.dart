import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

enum ReportCardTemplate {
  classic,
  modern,
  minimal,
  ghanaNational,
}

enum ReportCardColorScheme {
  indigo,
  teal,
  emerald,
  purple,
  orange,
  red,
}

class ReportCardStyle {
  final ReportCardTemplate template;
  final ReportCardColorScheme colorScheme;

  const ReportCardStyle({
    this.template = ReportCardTemplate.classic,
    this.colorScheme = ReportCardColorScheme.indigo,
  });

  String get templateId => template.name;
  String get colorId => colorScheme.name;

  static ReportCardStyle fromIds({String? templateId, String? colorId}) {
    return ReportCardStyle(
      template: ReportCardTemplateX.fromId(templateId),
      colorScheme: ReportCardColorSchemeX.fromId(colorId),
    );
  }
}

extension ReportCardTemplateX on ReportCardTemplate {
  String get label {
    switch (this) {
      case ReportCardTemplate.classic:
        return 'Classic';
      case ReportCardTemplate.modern:
        return 'Modern';
      case ReportCardTemplate.minimal:
        return 'Minimal';
      case ReportCardTemplate.ghanaNational:
        return 'Ghana National';
    }
  }

  static ReportCardTemplate fromId(String? id) {
    final normalized = (id ?? '').trim().toLowerCase();
    for (final v in ReportCardTemplate.values) {
      if (v.name.toLowerCase() == normalized) return v;
    }
    return ReportCardTemplate.classic;
  }
}

extension ReportCardColorSchemeX on ReportCardColorScheme {
  String get label {
    switch (this) {
      case ReportCardColorScheme.indigo:
        return 'Indigo';
      case ReportCardColorScheme.teal:
        return 'Teal';
      case ReportCardColorScheme.emerald:
        return 'Emerald';
      case ReportCardColorScheme.purple:
        return 'Purple';
      case ReportCardColorScheme.orange:
        return 'Orange';
      case ReportCardColorScheme.red:
        return 'Red';
    }
  }

  Color get flutterColor {
    switch (this) {
      case ReportCardColorScheme.indigo:
        return Colors.indigo;
      case ReportCardColorScheme.teal:
        return Colors.teal;
      case ReportCardColorScheme.emerald:
        return Colors.green;
      case ReportCardColorScheme.purple:
        return Colors.deepPurple;
      case ReportCardColorScheme.orange:
        return Colors.deepOrange;
      case ReportCardColorScheme.red:
        return Colors.red;
    }
  }

  PdfColor get pdfColor {
    switch (this) {
      case ReportCardColorScheme.indigo:
        return PdfColors.indigo800;
      case ReportCardColorScheme.teal:
        return PdfColors.teal700;
      case ReportCardColorScheme.emerald:
        return PdfColors.green800;
      case ReportCardColorScheme.purple:
        return PdfColors.purple800;
      case ReportCardColorScheme.orange:
        return PdfColors.deepOrange800;
      case ReportCardColorScheme.red:
        return PdfColors.red800;
    }
  }

  PdfColor get pdfColorDark {
    switch (this) {
      case ReportCardColorScheme.indigo:
        return PdfColors.indigo900;
      case ReportCardColorScheme.teal:
        return PdfColors.teal900;
      case ReportCardColorScheme.emerald:
        return PdfColors.green900;
      case ReportCardColorScheme.purple:
        return PdfColors.purple900;
      case ReportCardColorScheme.orange:
        return PdfColors.deepOrange900;
      case ReportCardColorScheme.red:
        return PdfColors.red900;
    }
  }

  static ReportCardColorScheme fromId(String? id) {
    final normalized = (id ?? '').trim().toLowerCase();
    for (final v in ReportCardColorScheme.values) {
      if (v.name.toLowerCase() == normalized) return v;
    }
    return ReportCardColorScheme.indigo;
  }
}
