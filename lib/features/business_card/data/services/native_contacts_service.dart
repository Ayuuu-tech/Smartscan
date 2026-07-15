import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:smartscan/features/business_card/data/models/business_card_model.dart';

final nativeContactsServiceProvider = Provider<NativeContactsService>((ref) {
  return NativeContactsService();
});

class NativeContactsService {
  Future<bool> requestContactsPermission() async {
    if (kIsWeb) return false;
    return await FlutterContacts.permissions
            .request(PermissionType.readWrite) ==
        PermissionStatus.granted;
  }

  Future<bool> hasContactsPermission() async {
    if (kIsWeb) return false;
    return await FlutterContacts.permissions.has(PermissionType.readWrite);
  }

  Future<bool> saveContact(BusinessCardModel card) async {
    if (kIsWeb) return false;

    final hasPermission = await requestContactsPermission();
    if (!hasPermission) return false;

    try {
      final nameParts = _splitFullName(card.fullName ?? '');

      final contact = Contact(
        name: Name(
          first: nameParts['first'],
          last: nameParts['last'],
        ),
        organizations: [
          Organization(
            name: card.companyName ?? '',
            jobTitle: card.designation ?? '',
          ),
        ],
        phones: card.phoneNumbers
            .map((p) => Phone(
                  number: p,
                  label: const Label(PhoneLabel.mobile),
                ))
            .toList(),
        emails: card.emailAddresses
            .map((e) => Email(
                  address: e,
                  label: const Label(EmailLabel.work),
                ))
            .toList(),
        addresses: card.address != null
            ? [
                Address(
                  street: card.address!,
                  label: const Label(AddressLabel.work),
                ),
              ]
            : [],
        websites: card.website != null
            ? [
                Website(
                  url: card.website!,
                  label: const Label(WebsiteLabel.work),
                ),
              ]
            : [],
      );

      final id = await FlutterContacts.create(contact);
      return id.isNotEmpty;
    } catch (e) {
      debugPrint('Error saving contact: $e');
      return false;
    }
  }

  Future<bool> isDuplicate(BusinessCardModel card) async {
    if (kIsWeb) return false;

    final hasPermission = await hasContactsPermission();
    if (!hasPermission) return false;

    try {
      final allContacts = await FlutterContacts.getAll();

      for (final existing in allContacts) {
        for (final phone in card.phoneNumbers) {
          final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
          if (existing.phones.any((p) {
            final existingNorm = p.number.replaceAll(RegExp(r'[^\d+]'), '');
            return existingNorm.contains(normalized) ||
                normalized.contains(existingNorm);
          })) {
            return true;
          }
        }

        for (final email in card.emailAddresses) {
          if (existing.emails.any(
              (e) => e.address.toLowerCase() == email.toLowerCase())) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking duplicates: $e');
      return false;
    }
  }

  Map<String, String?> _splitFullName(String fullName) {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return {'first': null, 'last': null};
    if (parts.length == 1) return {'first': parts[0], 'last': null};
    return {
      'first': parts.first,
      'last': parts.sublist(1).join(' '),
    };
  }
}
