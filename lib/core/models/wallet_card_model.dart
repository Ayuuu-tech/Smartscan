import 'dart:convert';

/// Kinds of cards the wallet can hold.
enum WalletCardType { credit, debit, prepaid, loyalty, gift }

extension WalletCardTypeLabel on WalletCardType {
  String get label {
    switch (this) {
      case WalletCardType.credit:
        return 'Credit';
      case WalletCardType.debit:
        return 'Debit';
      case WalletCardType.prepaid:
        return 'Prepaid';
      case WalletCardType.loyalty:
        return 'Loyalty';
      case WalletCardType.gift:
        return 'Gift';
    }
  }

  bool get isPayment =>
      this == WalletCardType.credit ||
      this == WalletCardType.debit ||
      this == WalletCardType.prepaid;
}

/// A card stored in the encrypted local vault.
///
/// Payment cards keep [number]/[expiryMonth]/[expiryYear]/[cvv];
/// loyalty & gift cards use [barcodeData]/[barcodeFormat] instead.
class WalletCard {
  final String id;
  final WalletCardType type;
  final String title; // bank / store name, e.g. "HDFC Bank", "Big Bazaar"
  final String cardholderName;
  final String number; // digits only
  final int? expiryMonth; // 1-12
  final int? expiryYear; // 4 digits
  final String? cvv; // optional, user opt-in
  final String? notes;
  final int colorValue; // card visual color
  final String? barcodeData;
  final String? barcodeFormat; // 'qr' | 'code128' | 'ean13'
  final DateTime createdAt;

  /// User's own label, e.g. "Netflix billing card".
  final String nickname;

  /// Pinned to the top of the wallet.
  final bool isFavorite;

  /// Free-text credit limit, e.g. "₹2,00,000".
  final String? creditLimit;

  /// Statement generation day of month (1-31).
  final int? billingDay;

  /// Bill payment due day of month (1-31).
  final int? dueDay;

  /// Reward tags for "best card" suggestions, e.g. ['fuel', 'dining'].
  final List<String> rewardCategories;

  /// Second gradient color; when set the card uses a two-tone theme
  /// (colorValue → colorValue2) instead of the auto-darkened gradient.
  final int? colorValue2;

  const WalletCard({
    required this.id,
    required this.type,
    required this.title,
    this.cardholderName = '',
    this.number = '',
    this.expiryMonth,
    this.expiryYear,
    this.cvv,
    this.notes,
    this.colorValue = 0xFF1F2A44,
    this.barcodeData,
    this.barcodeFormat,
    required this.createdAt,
    this.nickname = '',
    this.isFavorite = false,
    this.creditLimit,
    this.billingDay,
    this.dueDay,
    this.rewardCategories = const [],
    this.colorValue2,
  });

  String get last4 =>
      number.length >= 4 ? number.substring(number.length - 4) : number;

  bool get hasExpiry => expiryMonth != null && expiryYear != null;

  String get expiryLabel => hasExpiry
      ? '${expiryMonth.toString().padLeft(2, '0')}/${(expiryYear! % 100).toString().padLeft(2, '0')}'
      : '';

  /// Expired, or expiring within [withinDays] days.
  bool expiresSoon({int withinDays = 45}) {
    if (!hasExpiry) return false;
    // Card is valid through the last day of the expiry month.
    final lastValid = DateTime(expiryYear!, expiryMonth! + 1, 0);
    return lastValid.difference(DateTime.now()).inDays <= withinDays;
  }

  bool get isExpired {
    if (!hasExpiry) return false;
    return DateTime(expiryYear!, expiryMonth! + 1, 0).isBefore(DateTime.now());
  }

  WalletCard copyWith({
    WalletCardType? type,
    String? title,
    String? cardholderName,
    String? number,
    int? expiryMonth,
    int? expiryYear,
    String? cvv,
    String? notes,
    int? colorValue,
    String? barcodeData,
    String? barcodeFormat,
    String? nickname,
    bool? isFavorite,
    String? creditLimit,
    int? billingDay,
    int? dueDay,
    List<String>? rewardCategories,
    int? colorValue2,
    bool clearCvv = false,
  }) {
    return WalletCard(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      cardholderName: cardholderName ?? this.cardholderName,
      number: number ?? this.number,
      expiryMonth: expiryMonth ?? this.expiryMonth,
      expiryYear: expiryYear ?? this.expiryYear,
      cvv: clearCvv ? null : (cvv ?? this.cvv),
      notes: notes ?? this.notes,
      colorValue: colorValue ?? this.colorValue,
      barcodeData: barcodeData ?? this.barcodeData,
      barcodeFormat: barcodeFormat ?? this.barcodeFormat,
      createdAt: createdAt,
      nickname: nickname ?? this.nickname,
      isFavorite: isFavorite ?? this.isFavorite,
      creditLimit: creditLimit ?? this.creditLimit,
      billingDay: billingDay ?? this.billingDay,
      dueDay: dueDay ?? this.dueDay,
      rewardCategories: rewardCategories ?? this.rewardCategories,
      colorValue2: colorValue2 ?? this.colorValue2,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'title': title,
        'cardholderName': cardholderName,
        'number': number,
        'expiryMonth': expiryMonth,
        'expiryYear': expiryYear,
        'cvv': cvv,
        'notes': notes,
        'colorValue': colorValue,
        'barcodeData': barcodeData,
        'barcodeFormat': barcodeFormat,
        'createdAt': createdAt.toIso8601String(),
        'nickname': nickname,
        'isFavorite': isFavorite,
        'creditLimit': creditLimit,
        'billingDay': billingDay,
        'dueDay': dueDay,
        'rewardCategories': rewardCategories,
        'colorValue2': colorValue2,
      };

  factory WalletCard.fromMap(Map<String, dynamic> map) => WalletCard(
        id: map['id'] as String,
        type: WalletCardType.values.firstWhere(
          (t) => t.name == map['type'],
          orElse: () => WalletCardType.debit,
        ),
        title: map['title'] as String? ?? '',
        cardholderName: map['cardholderName'] as String? ?? '',
        number: map['number'] as String? ?? '',
        expiryMonth: map['expiryMonth'] as int?,
        expiryYear: map['expiryYear'] as int?,
        cvv: map['cvv'] as String?,
        notes: map['notes'] as String?,
        colorValue: map['colorValue'] as int? ?? 0xFF1F2A44,
        barcodeData: map['barcodeData'] as String?,
        barcodeFormat: map['barcodeFormat'] as String?,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        nickname: map['nickname'] as String? ?? '',
        isFavorite: map['isFavorite'] as bool? ?? false,
        creditLimit: map['creditLimit'] as String?,
        billingDay: map['billingDay'] as int?,
        dueDay: map['dueDay'] as int?,
        rewardCategories: map['rewardCategories'] != null
            ? List<String>.from(map['rewardCategories'] as List)
            : const [],
        colorValue2: map['colorValue2'] as int?,
      );

  /// Case-insensitive match against title, nickname, type and last digits —
  /// used by the wallet search bar.
  bool matchesQuery(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        nickname.toLowerCase().contains(q) ||
        cardholderName.toLowerCase().contains(q) ||
        type.label.toLowerCase().contains(q) ||
        (number.isNotEmpty && number.endsWith(q)) ||
        (barcodeData?.toLowerCase().contains(q) ?? false);
  }

  static String encodeList(List<WalletCard> cards) =>
      json.encode(cards.map((c) => c.toMap()).toList());

  static List<WalletCard> decodeList(String source) =>
      (json.decode(source) as List)
          .map((e) => WalletCard.fromMap(e as Map<String, dynamic>))
          .toList();
}
