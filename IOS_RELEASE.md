# Yacht — iOS release & App Store submission

The Capacitor iOS project lives at `ios/`. Everything in `src/` is identical
to the Android build — the same `mobile-shim`, `mobile-rpc`, vault, and
signing logic runs in both shells. The iOS-specific code is just:

- `ios/App/App/SecureStoragePlugin.swift` — Keychain-backed AES-GCM wrap
  matching the Android Keystore plugin.
- `ios/App/App/AppDelegate.swift` — privacy-overlay for the app-switcher
  snapshot (iOS analog of Android's `FLAG_SECURE`).
- `ios/App/App/PrivacyInfo.xcprivacy` — Apple's mandatory privacy
  manifest declaring no tracking, no data collection.
- `ios/App/App/Info.plist` — `NSCameraUsageDescription`, portrait-only
  on iPhone, `ITSAppUsesNonExemptEncryption=false`.

---

## 1. Hard prerequisites

| Prereq | How |
|---|---|
| **Apple Developer Program** | https://developer.apple.com/programs/ — $99/year, ID verification takes 24–48 h. Sign up under the legal entity name you want on the App Store (Yacht Industries or your personal name). |
| **Full Xcode** | Mac App Store → search "Xcode" → install. 40+ GB. The `xcodebuild` at `/usr/bin` is just a stub from Command Line Tools and is NOT enough. |
| **Xcode CLI license accepted** | After installing, open Terminal once and run `sudo xcodebuild -license accept` (Xcode also prompts you the first time you launch it). |
| **macOS** | iOS apps can only be built on a Mac. You have one — already done. |

## 2. One-time Xcode project setup

After Xcode is installed and your developer account is approved:

1. `cd "/Users/sadiecole/Documents/YachtWallet copy"`
2. `npm run sync:mobile` (rebuilds dist-mobile and syncs into ios/).
3. Open the workspace, NOT the project:
   ```bash
   open ios/App/App.xcworkspace
   ```
4. **Add the two iOS-specific files** that Capacitor's `cap sync` doesn't
   pick up automatically:
   - In the Xcode left sidebar, right-click the **App** group (the
     folder icon, not the project root) → **Add Files to "App"…**
   - Hold ⌘ and select both `SecureStoragePlugin.swift` and
     `PrivacyInfo.xcprivacy` in `ios/App/App/`.
   - In the dialog: **Copy items if needed = unchecked**, **Added folders
     = Create groups**, **Add to targets = App** (checked). Click Add.
5. **Configure signing**:
   - Click the project root in the left sidebar → select the **App**
     target → **Signing & Capabilities** tab.
   - Check **Automatically manage signing**.
   - In **Team**, choose your Apple Developer team.
   - Bundle Identifier: `com.yacht.wallet` (already set — must match the
     `appId` in `capacitor.config.ts` and the Android `applicationId`).
   - If Xcode reports a provisioning profile error, click **Try Again**
     — it will create the profile automatically.

## 3. App Store Connect setup

Once your Developer Program membership is active:

1. https://appstoreconnect.apple.com → **My Apps → +** → **New App**
2. Platform: **iOS** · Name: **Yacht** · Primary language: **English (U.S.)**
3. Bundle ID: select `com.yacht.wallet` from the dropdown (it appears
   after Xcode has built and registered the bundle ID for your team —
   may take a few minutes the first time).
4. SKU: anything unique to you — `yacht-wallet-v1` is fine.
5. User Access: **Full Access**.

Then fill in the listing fields:
- **App icon** 1024×1024 (Xcode reads from `AppIcon.appiconset`; you don't need to upload separately).
- **Privacy Policy URL** — the GitHub Pages URL from `MOBILE_RELEASE.md`.
- **Category** — **Finance**, secondary optional.
- **Description** (≤ 4000 chars).
- **Promotional Text** (≤ 170 chars, can be updated without resubmit).
- **Keywords** (≤ 100 chars, comma-separated) — e.g. `wallet,apechain,ape,nft,swap,ethereum,defi,crypto`.
- **Support URL** — link to your GitHub repo issues page.
- **Marketing URL** (optional).
- **Screenshots** — required sizes (provide at least one set):
  - iPhone 6.7" (1290×2796) — 3 to 10 screenshots
  - iPhone 6.5" (1242×2688) — fallback
  - iPad Pro 12.9" (2048×2732) — only if you support iPad
- **App Review Information** — your contact email + phone, plus reviewer
  notes (see § 5 below).

## 4. The App Privacy ("Nutrition Label") form

Apple's questionnaire on what data you collect. Match the answers from
the Play Console Data Safety form:

- **Do you or your third-party partners collect data from this app?** → **No**
- That ends the form. You'll see a "We don't collect data" badge on the
  store listing.

Per-data-type questions you'd otherwise hit:
| Data | Linked to user? | Tracking? |
|---|---|---|
| Crypto wallet address | (we don't collect) | — |
| Camera | (we don't collect — images aren't stored or transmitted) | — |

Apple typically follows up on this for wallet apps. The phrasing
that has worked for MetaMask / Phantom / Rainbow: *"Yacht is a
non-custodial software wallet. The app stores an encrypted vault
locally on the user's device. Network calls go directly from the
device to public blockchain RPC endpoints and public token metadata
services. No backend infrastructure operated by Yacht receives,
stores, or shares user data."*

## 5. Reviewer notes (paste into "App Review Information")

```
Yacht is a non-custodial cryptocurrency wallet for ApeChain (chain id 33139).
Reviewers can install the app, create a wallet by setting any password, and
explore every screen without credentials from us. Real on-chain operations
(send, swap, NFT view) require the wallet to be funded with ApeChain APE,
which we cannot provide — but every screen and flow is accessible without
funds.

Crypto wallet declarations:
- Wallet type: Non-custodial software wallet
- The user holds their own private keys, generated and encrypted on their
  device with Argon2id + AES-256-GCM and an additional Keychain wrap.
- We do not custody, exchange, or hold user funds.
- The wallet does not enable purchasing crypto with fiat.

No login, no account creation, no subscription. The app is fully usable
offline for screen navigation; on-chain features require an internet
connection to public RPC endpoints (rpc.apechain.com).
```

## 6. Build and upload the archive

Back in Xcode, with the workspace open:

1. Top toolbar device picker → choose **Any iOS Device (arm64)**.
2. Menu: **Product → Archive**. Xcode builds for release; takes 2–5 min.
3. When done, the **Organizer** window opens with your archive listed.
4. Select the archive → **Distribute App**.
5. Distribution method: **App Store Connect**.
6. Destination: **Upload**.
7. Sign with the automatically-managed certificate.
8. Click through until you see "Upload Successful".

After 10–30 min the build appears in App Store Connect under your app →
**TestFlight** tab → **iOS** section.

## 7. TestFlight (recommended before submitting to App Store)

1. App Store Connect → your app → **TestFlight** → pick the build.
2. Fill in the **Export Compliance** answer:
   - Does your app use encryption? → **Yes**
   - Does your app qualify for any of the exemptions? → **Yes**
     (the Info.plist `ITSAppUsesNonExemptEncryption=false` means this is
     pre-answered on subsequent submissions).
3. Add yourself as an **Internal Tester** — installed via the TestFlight
   app on your iPhone within 1–2 hours.
4. Verify the wallet works end-to-end. Pay special attention to:
   - Camera permission prompt appears (first scan attempt)
   - QR scan succeeds without "module not available" errors
   - App switcher thumbnail is the navy privacy overlay, not the
     wallet UI
   - Sending the app to background locks the vault

## 8. Submit for App Store review

1. App Store Connect → your app → **App Store** tab → **+ Version**.
2. Fill in the version number (e.g. `0.1.44`) and "What's New" text.
3. Attach the TestFlight build.
4. Submit for Review.

First-pass review for a crypto wallet takes 24–48 h. Apple is stricter
than Google on a few fronts:

- **No price predictions / "guaranteed returns" language** in the listing.
  Stick to "send, receive, swap, view your ApeChain tokens and NFTs."
- **No initial wallet funding via Apple-IAP-incompatible methods inside the
  app**. Yacht doesn't offer fiat onramps, so this is fine.
- **No mention of "mining" or "earning" rewards.** Yacht has on-chain
  chat tipping and NFT voting — describe these as utility features,
  not income.
- **App Review may ask for a demo video** for crypto-heavy apps. Have a
  30-second screen recording ready showing wallet creation, balance
  view, and the swap flow.

---

## Pre-launch checklist (iOS)

- [ ] Apple Developer Program active
- [ ] Xcode installed and license accepted
- [ ] Bundle ID `com.yacht.wallet` registered in your team
- [ ] `SecureStoragePlugin.swift` + `PrivacyInfo.xcprivacy` added to App target in Xcode
- [ ] Signing & Capabilities → Team set, automatic profile created
- [ ] Build number bumped (Xcode → General → Build)
- [ ] Marketing version matches `package.json` (Xcode → General → Version)
- [ ] `npm run sync:mobile` completed
- [ ] `Product → Archive` succeeds without warnings
- [ ] Upload to App Store Connect succeeds
- [ ] TestFlight install on your phone passes: vault unlock, QR scan,
      send/swap UI, screenshot-blocked app switcher, lock-on-background
- [ ] Privacy policy URL accessible from Apple's reviewers (test in an
      incognito window — must NOT require login)
- [ ] App Review Information notes paste matches § 5 above
- [ ] Submit for Review
