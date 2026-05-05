import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:ghanaclass_school_management/core/constants/theme.dart';

class AssetsInventoryScreen extends StatelessWidget {
  const AssetsInventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory & Assets')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Assets Register (Optional)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track school assets (furniture, books, toys) and optionally stock items like uniforms/canteen goods.',
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.plus, size: 18),
                      label: const Text('Add Asset'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.qrCode, size: 18),
                      label: const Text('Barcode/Tagging'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.actionIndigo.withValues(alpha: 0.08), foregroundColor: AppTheme.actionIndigo, elevation: 0),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _comingSoon(context),
                      icon: const Icon(LucideIcons.bell, size: 18),
                      label: const Text('Low Stock Alerts'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.authorityYellow, foregroundColor: Colors.black),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Card(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(LucideIcons.package, color: AppTheme.textMuted),
                            SizedBox(height: 10),
                            Text('Assets & inventory tracking is coming soon.', style: TextStyle(color: AppTheme.textMuted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Inventory & Assets: coming soon.')),
    );
  }
}
