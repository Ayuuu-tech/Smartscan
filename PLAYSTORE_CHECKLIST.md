# SmartScan — Play Store Launch Checklist

Status of the 10 items + store-listing (ASO) so "SmartScan" ranks on search.

---

## ✅ Done in the app (code / config)

| # | Item | What was done |
|---|------|---------------|
| 1 | **Release signing key** | Keystore `android/app/smartscan-release.jks` + `android/key.properties` created. Release builds are now signed with `CN=SmartScan` (verified). **Both files are gitignored — BACK THEM UP (see warning below).** |
| 2 | **App Bundle (AAB)** | `./build_apk.sh aab` produces `SmartScan.aab` (signed) — this is what you upload to Play. `./build_apk.sh all` builds APK + AAB. |
| 7 | **Notification frequency** | Reminder changed from every 4 hours → **once per day** (Play-friendly, less spammy). |
| 9 | **Apple Sign-In** | Hidden on Android (only shows on iOS). No more dead "requires iOS" button. |
| 4 | **Privacy policy page** | Hosted-ready HTML at `docs/index.html` (SmartScan-branded, light/dark). Enable GitHub Pages to get a public URL — see below. |

## ⚠️ You must do in Play Console / consoles (I can't access these)

| # | Item | Steps |
|---|------|-------|
| 3 | **Resend API key is inside the APK** | The login/signup OTP key ships in the binary and can be extracted. It's a *send-only* key so damage is limited, but for a real launch move OTP sending behind a free backend (Deno Deploy / Cloudflare Workers — no card needed). Until then, you can rotate the key anytime in the Resend dashboard if abused. |
| 5 | **Permissions justification** | In Play Console → App content → declare use of **Contacts** and **Camera**. Suggested text below. |
| 6 | **In-app purchase products** | Play Console → Monetize → Subscriptions → create `smartscan_pro_monthly` (₹25/mo) and `smartscan_pro_yearly` (₹139/yr). Until created, the Pro screen shows "coming soon". |
| 8 | **Reset email deliverability** | Firebase Console → Authentication → Templates → Password reset → customise sender/subject. Optionally set a custom domain so mail doesn't land in spam. |
| 10 | **Package id** | `com.scanmate.scanmate` is permanent and cannot change after publishing. It's fine (only the internal id; users see "SmartScan"). Left as-is on purpose. |

---

## 🔑 CRITICAL: back up your signing key

If you lose `android/app/smartscan-release.jks` **you can never update the app again** on Play. Copy it (and `android/key.properties` with the passwords) to a safe place — password manager, private cloud, USB. Do NOT commit them to git (already gitignored).

Keystore password / key password: `SmartScan@2026key` · alias: `smartscan`

*(Recommended: enable Play App Signing when you upload — Google then holds the app signing key and your .jks becomes just the "upload key", which is safer.)*

---

## 🌐 Publish the privacy policy (free, public URL)

Play needs a publicly reachable URL. The claude.ai artifact is private, so use GitHub Pages:

1. Commit `docs/index.html` and push.
2. GitHub → repo **Settings → Pages** → Source: `Deploy from a branch` → Branch `main`, folder `/docs` → Save.
3. In ~1 min your URL is live: **https://ayuuu-tech.github.io/Smartscan/**
4. Paste that URL in Play Console → Store listing → Privacy policy, and in the Data safety section.

---

## 🔎 Store listing (ASO — helps "SmartScan" rank on search)

Ranking #1 also depends on installs & reviews over time, but a keyword-tuned listing is the foundation.

**App name (30 chars max):**
```
SmartScan: Card Wallet & Scan
```

**Short description (80 chars max):**
```
Scan & store bank, loyalty & visiting cards. Encrypted, offline, secure wallet.
```

**Full description (4000 chars max):**
```
SmartScan is the simple, private way to keep every card in one place.

Scan your bank cards, loyalty cards and visiting cards — SmartScan stores
them in an encrypted vault right on your phone. Nothing is uploaded to any
server, so your data stays yours.

WHY SMARTSCAN
• Scan any card with your camera — details are read on-device and the photo is discarded
• Bank & payment cards, loyalty/reward cards, and business (visiting) cards, all in one wallet
• Bank-grade encryption backed by your phone's secure hardware
• Works fully offline — your card numbers never leave your device
• Unlock with fingerprint or face
• UPI Pay: pre-fill payment details straight into your UPI app
• Save visiting cards to your phone contacts in one tap
• Encrypted backups you control with a passphrase
• Expiry & bill-due reminders so you never miss a date

PRIVATE BY DESIGN
SmartScan never sells your data and never uploads your card numbers. Your
vault lives on your device and is erased if you uninstall.

Download SmartScan and carry your whole wallet — safely — on your phone.
```

**Keywords to weave in (Play has no keyword field — repeat naturally in the description):**
`card wallet, card scanner, scan card, loyalty card, visiting card, business card scanner, digital wallet, card holder, save cards, smartscan`

**Category:** Finance (or Tools) · **Tags:** Wallet, Scanner

**Suggested permission justifications:**
- **Camera:** "Used only to scan the user's cards. Images are processed on-device and never stored or uploaded."
- **Contacts:** "Used only when the user chooses to save a scanned visiting card to their phone contacts, and to detect duplicates. Contacts are never uploaded."

---

## Still needed before you hit publish (Play requirements)
- Feature graphic (1024×500) + app icon (512×512) + at least 2 phone screenshots
- Content rating questionnaire
- Data safety form (use the privacy policy above)
- Target audience & **ads declaration → YES, app contains ads** (AdMob banner for free users)

---

## 📣 Ads (AdMob) — set up before release

The app shows a **banner ad on the wallet screen for free users only** (Pro subscribers see no ads). It currently runs Google's **TEST** ad unit, so no real revenue yet. To earn:

1. Create an [AdMob account](https://admob.google.com) → add app "SmartScan" (Android).
2. Copy your real **AdMob App ID** (`ca-app-pub-...~...`) → replace the test id in `android/app/src/main/AndroidManifest.xml` (the `APPLICATION_ID` meta-data).
3. Create a **Banner** ad unit → copy its id (`ca-app-pub-.../...`) → put it in `secrets.json` as `ADMOB_BANNER_ANDROID`, then rebuild with `./build_apk.sh aab`.
4. Play Console → App content → **Ads** → declare "Yes, my app contains ads".
5. Link your AdMob to a **payments profile** to get paid.

⚠️ **Never tap your own live ads** while testing — AdMob will suspend the account. The test unit is safe to click; only swap to real ids for the actual Play release.
- Test on a real device via internal testing track first
