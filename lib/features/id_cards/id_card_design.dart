import 'package:pdf/pdf.dart';

enum IdCardTemplate {
  classic,
  modern,
  minimal,
}

class IdCardStyle {
  final IdCardTemplate template;

  /// ARGB (0xAARRGGBB)
  final int primaryColor;

  /// ARGB (0xAARRGGBB)
  final int accentColor;

  /// ARGB (0xAARRGGBB)
  final int backgroundColor;

  const IdCardStyle({
    this.template = IdCardTemplate.modern,
    this.primaryColor = 0xFF1E40AF, // Indigo-ish
    this.accentColor = 0xFF0EA5E9, // Sky-ish
    this.backgroundColor = 0xFFFFFFFF,
  });

  PdfColor get primaryPdf => PdfColor.fromInt(primaryColor);
  PdfColor get accentPdf => PdfColor.fromInt(accentColor);
  PdfColor get backgroundPdf => PdfColor.fromInt(backgroundColor);
}
