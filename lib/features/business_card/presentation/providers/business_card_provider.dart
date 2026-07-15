import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:smartscan/features/business_card/data/models/business_card_model.dart';

class BusinessCardState {
  final bool isScanning;
  final bool isProcessing;
  final String? capturedImagePath;
  final String? rawOcrText;
  final BusinessCardModel? parsedCard;
  final bool isSaving;
  final bool isSaved;
  final bool isDuplicate;
  final String? errorMessage;

  const BusinessCardState({
    this.isScanning = false,
    this.isProcessing = false,
    this.capturedImagePath,
    this.rawOcrText,
    this.parsedCard,
    this.isSaving = false,
    this.isSaved = false,
    this.isDuplicate = false,
    this.errorMessage,
  });

  BusinessCardState copyWith({
    bool? isScanning,
    bool? isProcessing,
    String? capturedImagePath,
    String? rawOcrText,
    BusinessCardModel? parsedCard,
    bool? isSaving,
    bool? isSaved,
    bool? isDuplicate,
    String? errorMessage,
  }) {
    return BusinessCardState(
      isScanning: isScanning ?? this.isScanning,
      isProcessing: isProcessing ?? this.isProcessing,
      capturedImagePath: capturedImagePath ?? this.capturedImagePath,
      rawOcrText: rawOcrText ?? this.rawOcrText,
      parsedCard: parsedCard ?? this.parsedCard,
      isSaving: isSaving ?? this.isSaving,
      isSaved: isSaved ?? this.isSaved,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class BusinessCardNotifier extends Notifier<BusinessCardState> {
  @override
  BusinessCardState build() => const BusinessCardState();

  void setScanning(bool value) {
    state = state.copyWith(isScanning: value);
  }

  void setProcessing(bool value) {
    state = state.copyWith(isProcessing: value);
  }

  void setCapturedImage(String path) {
    state = state.copyWith(
      capturedImagePath: path,
      isScanning: false,
    );
  }

  void setRawOcrText(String text) {
    state = state.copyWith(rawOcrText: text);
  }

  void setParsedCard(BusinessCardModel card) {
    state = state.copyWith(
      parsedCard: card,
      isProcessing: false,
    );
  }

  void updateCardField({
    String? fullName,
    List<String>? phoneNumbers,
    List<String>? emailAddresses,
    String? companyName,
    String? designation,
    String? website,
    String? address,
  }) {
    final current = state.parsedCard;
    if (current == null) return;
    state = state.copyWith(
      parsedCard: current.copyWith(
        fullName: fullName,
        phoneNumbers: phoneNumbers,
        emailAddresses: emailAddresses,
        companyName: companyName,
        designation: designation,
        website: website,
        address: address,
      ),
    );
  }

  void setSaving(bool value) {
    state = state.copyWith(isSaving: value);
  }

  void setSaved(bool value) {
    state = state.copyWith(isSaved: value);
  }

  void setDuplicate(bool value) {
    state = state.copyWith(isDuplicate: value);
  }

  void setError(String? message) {
    state = state.copyWith(errorMessage: message);
  }

  void reset() {
    state = const BusinessCardState();
  }
}

final businessCardProvider =
    NotifierProvider<BusinessCardNotifier, BusinessCardState>(
        BusinessCardNotifier.new);
