import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smartscan/core/services/upi_payee_service.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/features/wallet/presentation/screens/qr_scan_screen.dart';

/// Parses a merchant `upi://pay?...` QR payload into (vpa, name, amount).
(String, String, String)? parseUpiQr(String data) {
  final uri = Uri.tryParse(data.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'upi') return null;
  final pa = uri.queryParameters['pa'];
  if (pa == null || pa.isEmpty) return null;
  return (
    pa,
    uri.queryParameters['pn'] ?? '',
    uri.queryParameters['am'] ?? '',
  );
}

/// Bottom sheet: pick a saved payee or scan a merchant QR, enter the
/// amount, and launch the user's UPI app with everything pre-filled.
Future<void> showUpiPaySheet(
  BuildContext context, {
  String? vpa,
  String? payeeName,
  String? amount,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _UpiPaySheet(
      initialVpa: vpa ?? '',
      initialName: payeeName ?? '',
      initialAmount: amount ?? '',
    ),
  );
}

class _UpiPaySheet extends ConsumerStatefulWidget {
  final String initialVpa;
  final String initialName;
  final String initialAmount;

  const _UpiPaySheet({
    required this.initialVpa,
    required this.initialName,
    required this.initialAmount,
  });

  @override
  ConsumerState<_UpiPaySheet> createState() => _UpiPaySheetState();
}

class _UpiPaySheetState extends ConsumerState<_UpiPaySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _vpa =
      TextEditingController(text: widget.initialVpa);
  late final TextEditingController _name =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _amount =
      TextEditingController(text: widget.initialAmount);
  bool _savePayee = false;

  @override
  void dispose() {
    _vpa.dispose();
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _scanQr() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await scanCodeLive(context, title: 'Scan UPI QR');
    if (!mounted) return;
    final parsed = result == null ? null : parseUpiQr(result.$1);
    if (parsed == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('That doesn\'t look like a UPI QR code'),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    setState(() {
      _vpa.text = parsed.$1;
      _name.text = parsed.$2;
      if (parsed.$3.isNotEmpty) _amount.text = parsed.$3;
    });
  }

  Future<void> _pay() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final vpa = _vpa.text.trim();
    final name = _name.text.trim();

    if (_savePayee) {
      await ref.read(upiPayeesProvider.notifier).savePayee(
          UpiPayee(name: name.isEmpty ? vpa : name, vpa: vpa));
    }

    final uri = Uri(
      scheme: 'upi',
      host: 'pay',
      queryParameters: {
        'pa': vpa,
        if (name.isNotEmpty) 'pn': name,
        'am': _amount.text.trim(),
        'cu': 'INR',
      },
    );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok) {
      nav.pop();
    } else {
      messenger.showSnackBar(const SnackBar(
        content: Text('No UPI app found on this device'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final payees = ref.watch(upiPayeesProvider).value ?? [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Pay via UPI',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: AppColors.text)),
                  ),
                  TextButton.icon(
                    onPressed: _scanQr,
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    label: const Text('Scan QR'),
                    style:
                        TextButton.styleFrom(foregroundColor: AppColors.primary),
                  ),
                ],
              ),
              const Text(
                'Opens your UPI app with the details pre-filled.',
                style: TextStyle(color: AppColors.hint, fontSize: 13),
              ),
              if (payees.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: payees.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final p = payees[i];
                      return InputChip(
                        avatar: const Icon(Icons.person_rounded, size: 16),
                        label: Text(p.name),
                        onPressed: () => setState(() {
                          _vpa.text = p.vpa;
                          _name.text = p.name;
                        }),
                        onDeleted: () => ref
                            .read(upiPayeesProvider.notifier)
                            .removePayee(p.vpa),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _vpa,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Payee UPI ID',
                  hintText: 'name@bank',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v != null &&
                        RegExp(r'^[\w.\-]{2,}@[a-zA-Z]{2,}$')
                            .hasMatch(v.trim())
                    ? null
                    : 'Enter a valid UPI ID',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Payee name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = double.tryParse(v?.trim() ?? '');
                  return (n == null || n <= 0) ? 'Enter a valid amount' : null;
                },
              ),
              CheckboxListTile(
                value: _savePayee,
                onChanged: (v) => setState(() => _savePayee = v ?? false),
                title: const Text('Save payee for next time',
                    style: TextStyle(fontSize: 14)),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pay,
                icon: const Icon(Icons.currency_rupee_rounded),
                label: const Text('Pay Now',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
