import 'package:flutter/material.dart';
// import removed: unused

class AssetDepreciationMaintenanceCard extends StatelessWidget {
  const AssetDepreciationMaintenanceCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder: In a real implementation, fetch asset data and calculate depreciation/maintenance.
    final assets = [
      {'name': 'School Bus', 'value': 50000.0, 'years': 5, 'lastMaintenance': '2025-10-01'},
      {'name': 'Computers', 'value': 20000.0, 'years': 3, 'lastMaintenance': '2026-01-15'},
      {'name': 'Furniture', 'value': 10000.0, 'years': 7, 'lastMaintenance': '2025-12-10'},
    ];
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Asset Depreciation & Maintenance Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...assets.map((asset) {
              final depreciation = (asset['value'] as double) / (asset['years'] as int);
              return ListTile(
                leading: const Icon(Icons.inventory, color: Colors.brown),
                title: Text(asset['name'] as String),
                subtitle: Text('Annual Depreciation: GHS ${depreciation.toStringAsFixed(2)} | Last Maintenance: ${asset['lastMaintenance']}'),
              );
            }),
          ],
        ),
      ),
    );
  }
}
