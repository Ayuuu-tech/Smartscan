import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:smartscan/core/services/my_card_service.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/core/theme/card_themes.dart';

/// Design your own visiting card: all details, a theme of your choice,
/// live preview — then share it as an image (WhatsApp etc.) or a vCard QR
/// that any phone camera saves straight to contacts.
class MyCardScreen extends ConsumerStatefulWidget {
  const MyCardScreen({super.key});

  @override
  ConsumerState<MyCardScreen> createState() => _MyCardScreenState();
}

class _MyCardScreenState extends ConsumerState<MyCardScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _company = TextEditingController();
  final _designation = TextEditingController();
  final _website = TextEditingController();
  final _address = TextEditingController();
  int _themeIndex = 0;
  bool _loaded = false;
  bool _sharing = false;

  /// Wraps the card preview so it can be rendered to a PNG for sharing.
  final _cardKey = GlobalKey();

  @override
  void dispose() {
    for (final c in [
      _name, _phone, _email, _company, _designation, _website, _address,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  MyCardProfile _current() => MyCardProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        company: _company.text.trim(),
        designation: _designation.text.trim(),
        website: _website.text.trim(),
        address: _address.text.trim(),
        themeIndex: _themeIndex,
      );

  Future<void> _save({bool notify = true}) async {
    await ref.read(myCardProvider.notifier).save(_current());
    if (!mounted || !notify) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Your card is saved'),
      backgroundColor: AppColors.success,
    ));
  }

  /// Renders the card preview to a PNG and opens the system share sheet.
  Future<void> _shareAsImage() async {
    final profile = _current();
    final messenger = ScaffoldMessenger.of(context);
    if (profile.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Add your name first')));
      return;
    }
    setState(() => _sharing = true);
    try {
      await _save(notify: false);
      final boundary = _cardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Preview not ready');
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/my_visiting_card.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        text: '${profile.fullName} — ${profile.company}'.trim(),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Share failed: $e'),
        backgroundColor: AppColors.error,
      ));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showQr() {
    final profile = _current();
    if (profile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add your name first')));
      return;
    }
    _save(notify: false);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(profile.fullName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87)),
              const SizedBox(height: 16),
              BarcodeWidget(
                barcode: Barcode.qrCode(),
                data: profile.toVCard(),
                width: 220,
                height: 220,
                errorBuilder: (_, _) =>
                    const Text('Details too long for a QR'),
              ),
              const SizedBox(height: 12),
              const Text(
                'Scan with any phone camera\nto save the contact.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black45, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myCardProvider);

    // Populate controllers once from storage.
    if (!_loaded && profileAsync.hasValue) {
      final p = profileAsync.value!;
      _name.text = p.fullName;
      _phone.text = p.phone;
      _email.text = p.email;
      _company.text = p.company;
      _designation.text = p.designation;
      _website.text = p.website;
      _address.text = p.address;
      _themeIndex = p.themeIndex;
      _loaded = true;
    }

    final profile = _current();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Visiting Card',
            style: TextStyle(
                color: AppColors.text,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Live themed preview — RepaintBoundary lets us export it as PNG.
          RepaintBoundary(
            key: _cardKey,
            child: VisitingCardVisual(profile: profile),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _sharing ? null : _shareAsImage,
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: Text(_sharing ? 'Preparing…' : 'Share image'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showQr,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                  label: const Text('Show QR'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('CARD THEME',
                style: TextStyle(
                    color: AppColors.hint,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8)),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: WalletCardTheme.presets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final t = WalletCardTheme.presets[i];
                final selected = _themeIndex == i;
                return Tooltip(
                  message: t.name,
                  child: GestureDetector(
                    onTap: () => setState(() => _themeIndex = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: t.gradient,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _field(_name, 'Full name', TextInputType.name),
          const SizedBox(height: 12),
          _field(_designation, 'Designation', TextInputType.text),
          const SizedBox(height: 12),
          _field(_company, 'Company', TextInputType.text),
          const SizedBox(height: 12),
          _field(_phone, 'Phone', TextInputType.phone),
          const SizedBox(height: 12),
          _field(_email, 'Email', TextInputType.emailAddress),
          const SizedBox(height: 12),
          _field(_website, 'Website', TextInputType.url),
          const SizedBox(height: 12),
          _field(_address, 'Address', TextInputType.streetAddress),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Save My Card',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _field(
      TextEditingController controller, String label, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
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
      ),
    );
  }
}

/// The visiting card design itself: themed gradient, name + role, contact
/// rows and a small vCard QR so a printed/shared image is scannable too.
class VisitingCardVisual extends StatelessWidget {
  final MyCardProfile profile;

  const VisitingCardVisual({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final theme = WalletCardTheme.byIndex(profile.themeIndex);

    return AspectRatio(
      aspectRatio: 1.7,
      child: Container(
        decoration: BoxDecoration(
          gradient: theme.gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color(theme.color1).withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: profile.isEmpty
            ? const Center(
                child: Text(
                  'Fill in your details below —\nyour card designs itself.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (profile.designation.isNotEmpty)
                          Text(
                            profile.designation,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (profile.company.isNotEmpty)
                          Text(
                            profile.company,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 11.5,
                            ),
                          ),
                        const Spacer(),
                        if (profile.phone.isNotEmpty)
                          _contactRow(Icons.phone_rounded, profile.phone),
                        if (profile.email.isNotEmpty)
                          _contactRow(Icons.mail_rounded, profile.email),
                        if (profile.website.isNotEmpty)
                          _contactRow(Icons.language_rounded, profile.website),
                        if (profile.address.isNotEmpty)
                          _contactRow(
                              Icons.location_on_rounded, profile.address),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: BarcodeWidget(
                          barcode: Barcode.qrCode(),
                          data: profile.toVCard(),
                          width: 64,
                          height: 64,
                          errorBuilder: (_, _) => const SizedBox(
                              width: 64, height: 64),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('SCAN ME',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          )),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 12),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      );
}
