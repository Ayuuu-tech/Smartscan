# SmartScan

Encrypted, offline-first card wallet for India: bank cards, loyalty cards
and visiting cards — scanned, stored locally, and usable at checkout.

## Features

- **Scan any card** — front + back OCR (ML Kit) with Luhn validation; bank
  name, number, expiry and cardholder auto-detected
- **Encrypted vault** — Android Keystore / iOS Keychain; nothing ever
  uploaded; biometric lock with background re-lock
- **Pay** — UPI intents (GPay/PhonePe/Paytm), saved payees, live merchant-QR
  scanner; copy-to-pay with self-clearing clipboard
- **Autofill (Android)** — fills saved cards into checkout forms in other
  apps (CVV never shared)
- **Loyalty & gift cards** — barcode/QR scan, full-screen display, family
  sharing via QR
- **Visiting card designer** — themed personal card with embedded vCard QR;
  share as image
- **Backups** — passphrase-encrypted export/restore + automatic backups
  (PBKDF2 + AES-256-GCM)
- **Reminders** — card expiry and credit-card bill due dates
- **Pro** — Play Billing / StoreKit subscriptions (₹25/mo, ₹139/yr)

## Development

```bash
flutter pub get
flutter analyze        # 0 issues expected
flutter test           # 40 tests
flutter run
```

CI (`.github/workflows/ci.yml`) runs analyze + tests + Android build, and a
no-codesign iOS compile check on macOS.

## Release

See [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md) for the full device-test and
store-submission runbook. Signing reads `android/key.properties`
(see `android/key.properties.example`).

## Architecture notes

- State: Riverpod. All card mutations flow through `CardVaultNotifier._persist`,
  which syncs secure storage → Android autofill mirror → notification
  reschedule → auto-backup in one place.
- Package name stays `smartscan` (imports + Firebase config); user-visible
  branding is SmartScan.
- Payment-card data never leaves the device by design — see the in-app
  privacy policy.
