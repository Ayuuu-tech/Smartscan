import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/services/card_vault_service.dart';
import 'package:smartscan/core/services/settings_service.dart';
import 'package:smartscan/core/services/pro_gate.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/core/theme/card_themes.dart';
import 'package:smartscan/core/utils/card_utils.dart';
import 'package:smartscan/features/wallet/presentation/widgets/card_visual.dart';

/// Arguments for [CardEntryScreen]: pass an existing card to edit it, or a
/// prefilled draft (e.g. from the scanner) with [isNew] = true.
class CardEntryArgs {
  final WalletCard? card;
  final bool isNew;
  const CardEntryArgs({this.card, this.isNew = true});
}

class CardEntryScreen extends ConsumerStatefulWidget {
  final CardEntryArgs args;
  const CardEntryScreen({super.key, this.args = const CardEntryArgs()});

  static const List<(String, String)> rewardOptions = [
    ('fuel', 'Fuel'),
    ('dining', 'Dining'),
    ('groceries', 'Groceries'),
    ('online', 'Online shopping'),
    ('travel', 'Travel'),
    ('bills', 'Bills & utilities'),
    ('movies', 'Movies'),
    ('lounge', 'Airport lounge'),
  ];

  @override
  ConsumerState<CardEntryScreen> createState() => _CardEntryScreenState();
}

class _CardEntryScreenState extends ConsumerState<CardEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  late WalletCardType _type;
  late final TextEditingController _title;
  late final TextEditingController _name;
  late final TextEditingController _number;
  late final TextEditingController _expiry;
  late final TextEditingController _cvv;
  late final TextEditingController _barcode;
  late final TextEditingController _notes;
  late final TextEditingController _nickname;
  late final TextEditingController _creditLimit;
  late final TextEditingController _billingDay;
  late final TextEditingController _dueDay;
  late int _color;
  int? _color2;
  String _barcodeFormat = 'code128';
  late Set<String> _rewardTags;
  bool _saving = false;

  WalletCard? get _initial => widget.args.card;

  @override
  void initState() {
    super.initState();
    final c = _initial;
    _type = c?.type ?? WalletCardType.debit;
    _title = TextEditingController(text: c?.title ?? '');
    _name = TextEditingController(text: c?.cardholderName ?? '');
    _number = TextEditingController(
        text: c != null ? CardUtils.formatNumber(c.number) : '');
    _expiry = TextEditingController(text: c?.expiryLabel ?? '');
    _cvv = TextEditingController(text: c?.cvv ?? '');
    _barcode = TextEditingController(text: c?.barcodeData ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
    _nickname = TextEditingController(text: c?.nickname ?? '');
    _creditLimit = TextEditingController(text: c?.creditLimit ?? '');
    _billingDay =
        TextEditingController(text: c?.billingDay?.toString() ?? '');
    _dueDay = TextEditingController(text: c?.dueDay?.toString() ?? '');
    _color = c?.colorValue ?? WalletCardTheme.presets.first.color1;
    _color2 = c?.colorValue2 ?? WalletCardTheme.presets.first.color2;
    _barcodeFormat = c?.barcodeFormat ?? 'code128';
    _rewardTags = {...c?.rewardCategories ?? const []};
  }

  @override
  void dispose() {
    for (final c in [
      _title, _name, _number, _expiry, _cvv, _barcode, _notes,
      _nickname, _creditLimit, _billingDay, _dueDay,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isPayment => _type.isPayment;

  WalletCard _buildCard() {
    final digits = CardUtils.digitsOnly(_number.text);
    final expParts = _expiry.text.split('/');
    int? expM;
    int? expY;
    if (_isPayment && expParts.length == 2) {
      expM = int.tryParse(expParts[0]);
      expY = int.tryParse(expParts[1]);
      if (expY != null && expY < 100) expY += 2000;
    }
    final storeCvv = ref.read(settingsProvider).value?.storeCvv ?? false;
    return WalletCard(
      id: _initial?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      title: _title.text.trim(),
      cardholderName: _name.text.trim(),
      number: digits,
      expiryMonth: expM,
      expiryYear: expY,
      cvv: _isPayment && storeCvv && _cvv.text.trim().isNotEmpty
          ? _cvv.text.trim()
          : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      colorValue: _color,
      barcodeData:
          !_isPayment && _barcode.text.trim().isNotEmpty ? _barcode.text.trim() : null,
      barcodeFormat: !_isPayment ? _barcodeFormat : null,
      createdAt: _initial?.createdAt ?? DateTime.now(),
      nickname: _nickname.text.trim(),
      isFavorite: _initial?.isFavorite ?? false,
      creditLimit: _isPayment && _creditLimit.text.trim().isNotEmpty
          ? _creditLimit.text.trim()
          : null,
      billingDay: _isPayment ? _dayOrNull(_billingDay.text) : null,
      dueDay: _isPayment ? _dayOrNull(_dueDay.text) : null,
      rewardCategories: _isPayment ? _rewardTags.toList() : const [],
      colorValue2: _color2,
    );
  }

  static int? _dayOrNull(String text) {
    final d = int.tryParse(text.trim());
    return (d != null && d >= 1 && d <= 31) ? d : null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final card = _buildCard();
    final vault = ref.read(cardVaultProvider.notifier);
    if (widget.args.isNew) {
      await vault.addCard(card);
    } else {
      await vault.updateCard(card);
    }
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(widget.args.isNew ? 'Card saved to vault' : 'Card updated'),
      backgroundColor: AppColors.success,
    ));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final storeCvv = ref.watch(settingsProvider).value?.storeCvv ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.args.isNew ? 'Add Card' : 'Edit Card',
          style: const TextStyle(
              color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Live preview
            CardVisual(card: _buildPreviewCard()),
            // Scanned draft → ask the user to verify before saving. The
            // number is already Luhn-verified; names/expiry come from OCR.
            if (widget.args.isNew &&
                _initial != null &&
                _initial!.number.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.task_alt_rounded,
                        color: AppColors.success, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scanned & checksum-verified. Give the details one look before saving.',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _sectionLabel('CARD TYPE'),
            Wrap(
              spacing: 8,
              children: [
                for (final t in WalletCardType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: _type == t,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    labelStyle: TextStyle(
                      color: _type == t ? AppColors.primary : AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _field(
              controller: _title,
              label: _isPayment ? 'Bank / card name' : 'Store / program name',
              hint: _isPayment ? 'e.g. HDFC Millennia' : 'e.g. Star Rewards',
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _field(
              controller: _nickname,
              label: 'Nickname (optional)',
              hint: 'e.g. Netflix billing card',
              textCapitalization: TextCapitalization.sentences,
            ),
            if (_isPayment) ...[
              const SizedBox(height: 16),
              _field(
                controller: _number,
                label: 'Card number',
                hint: '1234 5678 9012 3456',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(19),
                  _CardNumberFormatter(),
                ],
                suffix: _brandBadge(),
                validator: (v) {
                  final digits = CardUtils.digitsOnly(v ?? '');
                  if (digits.isEmpty) return 'Required';
                  if (!CardUtils.luhnCheck(digits)) {
                    return 'Invalid card number';
                  }
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _field(
                      controller: _expiry,
                      label: 'Expiry (MM/YY)',
                      hint: '08/29',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        _ExpiryFormatter(),
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final m = RegExp(r'^(0[1-9]|1[0-2])/(\d{2})$')
                            .firstMatch(v.trim());
                        return m == null ? 'Use MM/YY' : null;
                      },
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: storeCvv
                        ? _field(
                            controller: _cvv,
                            label: 'CVV (optional)',
                            hint: '•••',
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              _cvv.text.isNotEmpty
                                  ? 'CVV was read from the card but will NOT be saved — CVV storage is off (Settings → Security).'
                                  : 'CVV storage is off (Settings → Security).',
                              style: TextStyle(
                                  color: AppColors.hint.withValues(alpha: 0.9),
                                  fontSize: 12),
                            ),
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _field(
                controller: _name,
                label: 'Cardholder name',
                hint: 'Name on card',
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              _sectionLabel('CARD FINANCES (OPTIONAL)'),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _creditLimit,
                      label: 'Credit limit',
                      hint: '₹2,00,000',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _billingDay,
                      label: 'Statement day',
                      hint: '1-31',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(
                      controller: _dueDay,
                      label: 'Due day',
                      hint: '1-31',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(2),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Set a due day to get a bill reminder one day before.',
                style: TextStyle(color: AppColors.hint, fontSize: 12),
              ),
              const SizedBox(height: 20),
              _sectionLabel('REWARDS ON THIS CARD'),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final (tag, label) in CardEntryScreen.rewardOptions)
                    FilterChip(
                      label: Text(label),
                      selected: _rewardTags.contains(tag),
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      onSelected: (sel) => setState(() {
                        sel ? _rewardTags.add(tag) : _rewardTags.remove(tag);
                      }),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 16),
              _field(
                controller: _barcode,
                label: 'Card / membership number',
                hint: 'Scan or type the code',
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              _sectionLabel('CODE FORMAT'),
              Wrap(
                spacing: 8,
                children: [
                  for (final f in const [
                    ('code128', 'Barcode'),
                    ('qr', 'QR code'),
                    ('ean13', 'EAN-13'),
                  ])
                    ChoiceChip(
                      label: Text(f.$2),
                      selected: _barcodeFormat == f.$1,
                      selectedColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      onSelected: (_) =>
                          setState(() => _barcodeFormat = f.$1),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            _field(
              controller: _notes,
              label: 'Notes (optional)',
              hint: 'e.g. billing address, helpline',
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            _sectionLabel('CARD THEME'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (i, t) in WalletCardTheme.presets.indexed)
                  Tooltip(
                    message: t.name,
                    child: GestureDetector(
                      // The first theme is free; the rest are Pro.
                      onTap: () async {
                        if (i != 0 &&
                            !await ProGate.require(context, ref,
                                feature: 'Custom card themes')) {
                          return;
                        }
                        setState(() {
                          _color = t.color1;
                          _color2 = t.color2;
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: t.gradient,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _color == t.color1 && _color2 == t.color2
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: _color == t.color1 && _color2 == t.color2
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 20)
                            : (i != 0
                                ? const Icon(Icons.lock_rounded,
                                    color: Colors.white70, size: 16)
                                : null),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(
                _saving
                    ? 'Saving…'
                    : (widget.args.isNew ? 'Save to Vault' : 'Update Card'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '🔒 Stored encrypted on this device only',
                style: TextStyle(color: AppColors.hint, fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  WalletCard _buildPreviewCard() {
    final digits = CardUtils.digitsOnly(_number.text);
    return WalletCard(
      id: 'preview',
      type: _type,
      title: _title.text.trim(),
      cardholderName: _name.text.trim(),
      number: digits,
      expiryMonth: int.tryParse(_expiry.text.split('/').firstOrNull ?? ''),
      expiryYear: () {
        final y = int.tryParse(
            _expiry.text.split('/').elementAtOrNull(1) ?? '');
        return y == null ? null : (y < 100 ? y + 2000 : y);
      }(),
      colorValue: _color,
      colorValue2: _color2,
      barcodeData: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      barcodeFormat: _barcodeFormat,
      createdAt: DateTime.now(),
    );
  }

  Widget? _brandBadge() {
    final brand = CardUtils.detectBrand(CardUtils.digitsOnly(_number.text));
    if (brand == CardBrand.unknown) return null;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Text(
        brand.label,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.hint,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8)),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Widget? suffix,
    bool obscureText = false,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: onChanged,
      obscureText: obscureText,
      maxLines: maxLines,
      textCapitalization: textCapitalization,
      style: const TextStyle(
          color: AppColors.text, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix == null
            ? null
            : Align(
                alignment: Alignment.centerRight,
                widthFactor: 1,
                child: suffix,
              ),
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
      ),
    );
  }
}

/// Groups typed digits as "1234 5678 9012 3456" while editing.
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Inserts the "/" of MM/YY automatically.
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    String text = digits;
    if (digits.length >= 3) {
      text = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
