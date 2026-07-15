# SmartScan — Launch Checklist

Everything the code can't do for you. Work top to bottom; each section is
independent.

## 1. On-device test pass (1 phone, ~1 hour)

Install: `flutter run --release`

- [ ] Onboarding → "Continue without account" → wallet opens
- [ ] Add a card manually — Luhn validation, theme picker, save
- [ ] Scan a real card (front + back) — number/expiry/name/bank auto-filled
      (console prints `Card OCR text:` in debug builds if a field is wrong)
- [ ] Lock: background the app >30s → biometric prompt on return
- [ ] Reveal + copy card number — clipboard clears after 30s
- [ ] UPI Pay → real GPay/PhonePe opens pre-filled; save a payee
- [ ] Scan a shop's UPI QR (live scanner + torch + gallery import)
- [ ] Loyalty card: scan barcode → save → full-screen barcode at counter
- [ ] Settings → Autofill → enable → open any checkout form → card offered
- [ ] Backup: export (share sheet), auto-backup toggle, restore on second
      device / after reinstall
- [ ] Notifications: add a card expiring next month → reminder scheduled
      (check with `adb shell dumpsys notification` or wait for it)
- [ ] My Visiting Card: fill details, switch themes, Share image →
      WhatsApp; scan the QR on the image with another phone
- [ ] Long-press app icon → Favorite card / UPI Pay shortcuts

## 2. Play Store

- [ ] Play Console account (~$25 one-time)
- [ ] Generate release keystore:
      `keytool -genkey -v -keystore ~/smartscan-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias smartscan`
- [ ] Copy `android/key.properties.example` → `android/key.properties`, fill in
- [ ] `flutter build appbundle --release` → upload the AAB
- [ ] Monetize → Subscriptions → create EXACTLY these product ids:
      - `smartscan_pro_monthly` — ₹25/month
      - `smartscan_pro_yearly` — ₹139/year
- [ ] Add yourself as a license tester → test a purchase (free)
- [ ] Data safety form: financial info **stored on device, encrypted,
      not collected/shared** — your local-only architecture is the answer
      to every question
- [ ] Store listing: screenshots, privacy policy URL (host the in-app text)

## 3. iOS

- [ ] Apple Developer account ($99/yr) + a Mac (or Codemagic/GitHub Actions
      macOS runner — CI already compile-checks iOS)
- [ ] `cd ios && pod install`, then `flutter build ipa`
- [ ] App Store Connect: create the same two subscription products
- [ ] Apply for the Small Business Program (15% instead of 30% cut)
- [ ] TestFlight → review. Notes for review: local-only vault, Face ID
      usage string already set, no card data leaves the device.

## 4. After launch

- [ ] Razorpay UPI-autopay web flow (allowed OUTSIDE the stores only)
- [ ] Crash reporting (Firebase Crashlytics) + analytics you're comfortable
      with privacy-wise
- [ ] Remove the debug OCR `debugPrint` in `card_scan_screen.dart` once
      scanning accuracy is tuned on real cards
