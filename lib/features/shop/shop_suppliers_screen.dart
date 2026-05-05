import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ghanaclass_school_management/core/providers/system_settings_providers.dart';
import 'package:ghanaclass_school_management/core/database/app_database.dart';
import 'package:ghanaclass_school_management/features/shop/shop_providers.dart';
import 'package:ghanaclass_school_management/shared/widgets/portal_surface.dart';

class ShopSuppliersScreen extends ConsumerWidget {
  const ShopSuppliersScreen({super.key});

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {ShopSupplier? supplier}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => _SupplierEditorDialog(supplier: supplier),
    );
    if (ok == true) {
      ref.invalidate(shopSuppliersProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final academicYear = ref.watch(activeYearProvider);
    final term = ref.watch(activeTermProvider);
    final suppliersAsync = ref.watch(shopSuppliersProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add supplier'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PortalHeroBanner(
              eyebrow: 'Supplier network',
              title: 'Shop Suppliers',
              subtitle: 'Manage vendor contacts, procurement touchpoints, and supplier records for the shop portal.',
              icon: Icons.local_shipping_outlined,
              primary: const Color(0xFFD97706),
              accent: const Color(0xFF2563EB),
              metrics: [
                PortalHeroMetric(label: 'Academic year', value: '$academicYear'),
                PortalHeroMetric(label: 'Active term', value: 'Term $term'),
              ],
              trailing: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/pos'),
                    icon: const Icon(Icons.point_of_sale_outlined),
                    label: const Text('Back to POS'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => context.go('/inventory'),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('Inventory'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: PortalSectionPanel(
                title: 'Vendor Directory',
                subtitle: 'Approved suppliers and their contact details.',
                child: suppliersAsync.when(
          data: (suppliers) {
            if (suppliers.isEmpty) {
              return const Center(child: Text('No suppliers yet.'));
            }
            return ListView.separated(
              itemCount: suppliers.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = suppliers[index];
                return ListTile(
                  title: Text(s.name),
                  subtitle: Text([
                    if (s.phone != null && s.phone!.trim().isNotEmpty) s.phone!,
                    if (s.email != null && s.email!.trim().isNotEmpty) s.email!,
                  ].join(' • ')),
                  trailing: IconButton(
                    onPressed: () => _openEditor(context, ref, supplier: s),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierEditorDialog extends ConsumerStatefulWidget {
  final ShopSupplier? supplier;

  const _SupplierEditorDialog({this.supplier});

  @override
  ConsumerState<_SupplierEditorDialog> createState() => _SupplierEditorDialogState();
}

class _SupplierEditorDialogState extends ConsumerState<_SupplierEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final s = widget.supplier;
    _name = TextEditingController(text: s?.name ?? '');
    _phone = TextEditingController(text: s?.phone ?? '');
    _email = TextEditingController(text: s?.email ?? '');
    _address = TextEditingController(text: s?.address ?? '');
    _notes = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;

    final service = ref.read(shopServiceProvider);
    await service.upsertSupplier(
      id: widget.supplier?.id,
      name: name,
      phone: _phone.text,
      email: _email.text,
      address: _address.text,
      notes: _notes.text,
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.supplier != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit supplier' : 'Add supplier'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone'))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email'))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 8),
              TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
