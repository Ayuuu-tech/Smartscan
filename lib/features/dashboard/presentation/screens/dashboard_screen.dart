import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:smartscan/core/models/wallet_card_model.dart';
import 'package:smartscan/core/services/auth_service.dart';
import 'package:smartscan/core/services/biometric_service.dart';
import 'package:smartscan/core/services/card_vault_service.dart';
import 'package:smartscan/core/services/settings_service.dart';
import 'package:smartscan/core/theme/app_colors.dart';
import 'package:smartscan/core/utils/card_utils.dart';
import 'package:smartscan/features/wallet/presentation/screens/card_entry_screen.dart';
import 'package:smartscan/features/wallet/presentation/screens/qr_scan_screen.dart';
import 'package:smartscan/features/dashboard/presentation/widgets/banner_ad_widget.dart';
import 'package:smartscan/features/dashboard/presentation/widgets/settings_tab.dart';
import 'package:smartscan/features/wallet/presentation/screens/lock_screen.dart';
import 'package:smartscan/features/wallet/presentation/widgets/card_visual.dart';
import 'package:smartscan/features/wallet/presentation/widgets/upi_pay_sheet.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentTab = 0;
  bool _searching = false;
  final _searchController = TextEditingController();

  /// Wallet re-locks if the app spends longer than this in the background.
  static const _relockAfter = Duration(seconds: 30);
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupQuickActions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only track pauses while unlocked — the biometric prompt itself
    // pauses the app, and re-locking mid-unlock would loop.
    if (state == AppLifecycleState.paused) {
      if (ref.read(vaultUnlockedProvider)) _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;
      final lockOn = ref.read(settingsProvider).value?.appLock ?? true;
      if (lockOn &&
          pausedAt != null &&
          DateTime.now().difference(pausedAt) > _relockAfter) {
        ref.read(vaultUnlockedProvider.notifier).set(false);
      }
    }
  }

  /// Long-press the app icon → jump straight to the favorite card or UPI.
  void _setupQuickActions() {
    const actions = QuickActions();
    actions.initialize((type) {
      if (!mounted) return;
      switch (type) {
        case 'favorite_card':
          final cards = ref.read(cardVaultProvider).value ?? [];
          final fav = cards.where((c) => c.isFavorite).firstOrNull ??
              cards.firstOrNull;
          if (fav != null) context.push('/card-detail', extra: fav.id);
        case 'upi_pay':
          showUpiPaySheet(context);
      }
    });
    actions.setShortcutItems(const [
      ShortcutItem(
          type: 'favorite_card',
          localizedTitle: 'Favorite card',
          icon: 'ic_launcher'),
      ShortcutItem(
          type: 'upi_pay', localizedTitle: 'UPI Pay', icon: 'ic_launcher'),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final unlocked = ref.watch(vaultUnlockedProvider);

    // Biometric gate: everything behind the lock until authenticated.
    if (settings != null && settings.appLock && !unlocked) {
      return const LockScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: _currentTab == 0 ? _buildWalletTab() : const SettingsTab(),
      floatingActionButton: _currentTab == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'best_card_fab',
                  onPressed: _showBestCardSheet,
                  tooltip: 'Best card?',
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.auto_awesome_rounded, size: 26),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'scan_card_fab',
                  onPressed: () => context.push('/card-scanner'),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: const CircleBorder(),
                  child:
                      const Icon(Icons.document_scanner_outlined, size: 26),
                ),
              ],
            )
          : null,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: BottomAppBar(
          color: AppColors.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 72,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                  index: 0,
                  icon: Icons.wallet_outlined,
                  activeIcon: Icons.wallet_rounded,
                  label: 'Wallet'),
              // Center action (not a tab): scan any QR — shared card or UPI.
              GestureDetector(
                onTap: _importFromQr,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded,
                          color: AppColors.text, size: 24),
                      Text('Import QR',
                          style: TextStyle(
                              color: AppColors.hint,
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              _buildBottomNavItem(
                  index: 1,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    if (_currentTab == 1) {
      return AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => setState(() => _currentTab = 0),
        ),
        title: const Center(
          child: Text('Settings',
              style: TextStyle(
                  color: AppColors.text,
                  fontWeight: FontWeight.bold,
                  fontSize: 18)),
        ),
      );
    }
    if (_searching) {
      return AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.text),
          onPressed: () => setState(() {
            _searching = false;
            _searchController.clear();
          }),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search bank, nickname, last 4 digits…',
            border: InputBorder.none,
          ),
          style: const TextStyle(color: AppColors.text, fontSize: 16),
          onChanged: (_) => setState(() {}),
        ),
      );
    }
    return AppBar(
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.wallet_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text('SmartScan',
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700, color: AppColors.text)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.text),
          tooltip: 'My visiting card',
          onPressed: () => context.push('/my-card'),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded, color: AppColors.text),
          tooltip: 'Search cards',
          onPressed: () => setState(() => _searching = true),
        ),
        IconButton(
          icon: const Icon(Icons.lock_outline_rounded, color: AppColors.text),
          tooltip: 'Lock wallet',
          onPressed: () =>
              ref.read(vaultUnlockedProvider.notifier).set(false),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ── Wallet tab ──────────────────────────────────────────────────────────

  Widget _buildWalletTab() {
    final cardsAsync = ref.watch(cardVaultProvider);
    final user = ref.watch(authStateProvider);
    final userName = user?.displayName ?? 'there';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hi, $userName',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.text,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          cardsAsync.when(
            data: (cards) => Text(
                cards.isEmpty
                    ? 'Your vault is empty'
                    : '${cards.length} card${cards.length == 1 ? '' : 's'} in your vault',
                style: const TextStyle(color: AppColors.hint, fontSize: 14)),
            loading: () => const Text('Opening vault…',
                style: TextStyle(color: AppColors.hint, fontSize: 14)),
            error: (_, _) => const Text('Vault error',
                style: TextStyle(color: AppColors.error, fontSize: 14)),
          ),
          const SizedBox(height: 24),
          _buildQuickActionsBar(),
          const SizedBox(height: 28),
          cardsAsync.when(
            data: _buildCardSections,
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: CircularProgressIndicator())),
            error: (e, _) => Center(
                child: Text('Error: $e',
                    style: const TextStyle(color: AppColors.error))),
          ),
          // Banner ad below the cards — free users only (Pro hides it).
          const Center(child: BannerAdWidget()),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildCardSections(List<WalletCard> allCards) {
    final query = _searchController.text;
    var cards = allCards.where((c) => c.matchesQuery(query)).toList()
      ..sort((a, b) {
        if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    if (cards.isEmpty && allCards.isNotEmpty) {
      return _sectionEmpty('No cards match "$query"');
    }
    if (cards.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.credit_card_off_outlined,
                  size: 64, color: AppColors.hint),
              const SizedBox(height: 16),
              const Text(
                'No cards yet.\nScan a card or add one manually —\neverything stays encrypted on this phone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.hint, fontSize: 14),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => context.push('/card-scanner'),
                icon: const Icon(Icons.document_scanner_outlined, size: 18),
                label: const Text('Scan your first card'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final payment = cards.where((c) => c.type.isPayment).toList();
    final other = cards.where((c) => !c.type.isPayment).toList();
    final expiring =
        payment.where((c) => c.expiresSoon() || c.isExpired).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (expiring.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFB9770E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: Color(0xFFB9770E), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${expiring.length} card${expiring.length == 1 ? '' : 's'} expired or expiring soon',
                    style: const TextStyle(
                        color: Color(0xFFB9770E),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (payment.isNotEmpty) ...[
          _sectionTitle('Payment cards'),
          const SizedBox(height: 12),
          for (final card in payment) _walletCardTile(card),
        ],
        if (other.isNotEmpty) ...[
          const SizedBox(height: 12),
          _sectionTitle('Loyalty & gift cards'),
          const SizedBox(height: 12),
          for (final card in other) _walletCardTile(card),
        ],
      ],
    );
  }

  Widget _walletCardTile(WalletCard card) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => context.push('/card-detail', extra: card.id),
        child: Hero(tag: 'card_${card.id}', child: CardVisual(card: card)),
      ),
    );
  }

  Widget _sectionEmpty(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(message,
              style: const TextStyle(color: AppColors.hint, fontSize: 14)),
        ),
      );

  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.text));

  Widget _buildQuickActionsBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: () => context.push('/card-scanner'),
            icon: const Icon(Icons.document_scanner_outlined, size: 18),
            label: const Text('Scan card'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const SizedBox(width: 12),
          _quickButton(
              icon: Icons.add_card_rounded,
              label: 'Add manually',
              onPressed: () =>
                  context.push('/card-entry', extra: const CardEntryArgs())),
          const SizedBox(width: 12),
          _quickButton(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Loyalty',
              onPressed: _addLoyaltyCard),
          const SizedBox(width: 12),
          _quickButton(
              icon: Icons.currency_rupee_rounded,
              label: 'UPI Pay',
              onPressed: () => showUpiPaySheet(context)),
          const SizedBox(width: 12),
          _quickButton(
              icon: Icons.contact_mail_outlined,
              label: 'Visiting card',
              onPressed: () => context.push('/visiting-cards')),
        ],
      ),
    );
  }

  /// Scan a loyalty barcode/QR and open the entry form pre-filled.
  Future<void> _addLoyaltyCard() async {
    final result =
        await scanCodeLive(context, title: 'Scan loyalty barcode');
    if (!mounted) return;
    final draft = WalletCard(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: WalletCardType.loyalty,
      title: '',
      colorValue: CardUtils.presetColors[7],
      barcodeData: result?.$1,
      barcodeFormat: result?.$2 ?? 'code128',
      createdAt: DateTime.now(),
    );
    context.push('/card-entry', extra: CardEntryArgs(card: draft));
  }

  /// F10: "which card should I use?" — pick a category, see the cards
  /// that earn rewards there (favorites first).
  void _showBestCardSheet() {
    final cards = (ref.read(cardVaultProvider).value ?? [])
        .where((c) => c.type.isPayment)
        .toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('What are you paying for?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppColors.text)),
              const SizedBox(height: 4),
              const Text('Cards tagged with that reward come first.',
                  style: TextStyle(color: AppColors.hint, fontSize: 13)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (tag, label) in CardEntryScreen.rewardOptions)
                    ActionChip(
                      label: Text(label),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showBestCardsFor(tag, label, cards);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showBestCardsFor(String tag, String label, List<WalletCard> cards) {
    final matching = cards
        .where((c) => c.rewardCategories.contains(tag))
        .toList()
      ..sort((a, b) => a.isFavorite == b.isFavorite
          ? 0
          : (a.isFavorite ? -1 : 1));
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                matching.isEmpty
                    ? 'No card tagged for $label yet'
                    : 'Best for $label',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.text),
              ),
            ),
            if (matching.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 24, left: 24, right: 24),
                child: Text(
                  'Tag reward categories on your cards (edit card → Rewards) to get suggestions.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.hint, fontSize: 13),
                ),
              ),
            for (final card in matching)
              ListTile(
                leading: Icon(
                    card.isFavorite
                        ? Icons.star_rounded
                        : Icons.credit_card_rounded,
                    color: card.isFavorite
                        ? const Color(0xFFFDA856)
                        : AppColors.primary),
                title: Text(
                    card.nickname.isNotEmpty ? card.nickname : card.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('•••• ${card.last4}'),
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/card-detail', extra: card.id);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  /// F11 + F6: scan any QR — a SmartScan shared card gets imported, a UPI
  /// merchant QR opens the pay sheet pre-filled.
  Future<void> _importFromQr() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await scanCodeLive(context, title: 'Import QR');
    if (!mounted || result == null) return;
    final data = result.$1;

    // Shared loyalty/gift card from another SmartScan install?
    try {
      final payload = json.decode(data) as Map<String, dynamic>;
      if ((payload['app'] == 'smartscan_cards' ||
              payload['app'] == 'scanmate_cards') &&
          payload['kind'] == 'shared_card') {
        final card =
            WalletCard.fromMap(payload['card'] as Map<String, dynamic>);
        if (card.type.isPayment) {
          messenger.showSnackBar(const SnackBar(
            content: Text('Payment cards cannot be imported via QR'),
            backgroundColor: AppColors.error,
          ));
          return;
        }
        final added =
            await ref.read(cardVaultProvider.notifier).importCards([card]);
        messenger.showSnackBar(SnackBar(
          content: Text(added > 0
              ? '"${card.title}" added to your wallet'
              : 'You already have this card'),
          backgroundColor: AppColors.success,
        ));
        return;
      }
    } catch (_) {
      // Not JSON — fall through.
    }

    // Merchant UPI QR?
    final upi = parseUpiQr(data);
    if (upi != null && mounted) {
      showUpiPaySheet(context,
          vpa: upi.$1, payeeName: upi.$2, amount: upi.$3);
      return;
    }

    messenger.showSnackBar(const SnackBar(
        content: Text('QR not recognized (not a shared card or UPI code)')));
  }

  Widget _quickButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18, color: AppColors.text),
      label: Text(label, style: const TextStyle(color: AppColors.text)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildBottomNavItem(
      {required int index,
      required IconData icon,
      required IconData activeIcon,
      required String label}) {
    final isActive = _currentTab == index;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEEF2FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon,
                color: isActive ? const Color(0xFF3F62F6) : AppColors.text,
                size: 24),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: Color(0xFF3F62F6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}
