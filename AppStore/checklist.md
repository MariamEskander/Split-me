# Split Me — release checklist

Status as of 6 September 2026.

## Done — in the project

- [x] App icon, 1024×1024, no alpha channel *(a common first rejection)*
- [x] iPhone only — `TARGETED_DEVICE_FAMILY = 1`. Previously declared iPad and
      Vision Pro, which would have forced iPad screenshots and iPad review
- [x] `SUPPORTED_PLATFORMS` narrowed to iOS
- [x] Home-screen name `Split Me` via `CFBundleDisplayName`
- [x] `ITSAppUsesNonExemptEncryption = false`
- [x] `PrivacyInfo.xcprivacy` — no tracking, no collected data, UserDefaults
      declared with reason CA92.1
- [x] Usage strings for camera, location when-in-use, and location always
- [x] Launch screen with the brand navy, so there is no white flash
- [x] Deployment target iOS 17.0
- [x] Version 1.0, build 1

## Done — written and ready to paste

- [x] English metadata — `en.md`
- [x] Arabic metadata — `ar.md`
- [x] App Review notes, including the Always-location justification —
      `review-and-privacy.md`
- [x] App Privacy answers, age rating answers — `review-and-privacy.md`
- [x] Support and privacy pages, live at
      `https://mariameskander.github.io/Split-me-docs/`

## To do — needs you

- [ ] **Apple Developer Program membership**, $99/year. Nothing can be
      distributed on the current free personal team
- [ ] **Enable GitHub Pages** on Split-me-docs (Settings → Pages → main, root)
      and confirm both URLs load
- [ ] **Check the app name is free** on the App Store; fallbacks are listed in
      `en.md`
- [ ] **Screenshots** — 6.9" display (1320×2868), 3 to 10 images. Suggested:
      Bills list, Items with people assigned, Shares, Currency, Essentials.
      Add an Arabic set too if you localize the listing
- [ ] **Phone number** for App Review contact
- [ ] Set the **bundle ID** `app.founderah.Splitme` in App Store Connect and
      create the app record
- [ ] **Archive and upload:** destination *Any iOS Device (arm64)* →
      Product → Archive → Distribute App → App Store Connect → Upload
- [ ] **TestFlight on a real device before submitting.** Two things a simulator
      cannot tell you: whether the OCR copes with real creased receipts, and
      whether the leaving-home geofence actually fires when you walk out
- [ ] Submit for review

## Known review risks, in order of likelihood

1. **Guideline 5.1.1 / 2.5.4 — background location.** The most likely
   rejection. The notes in `review-and-privacy.md` address it directly: the
   permission is optional, the feature degrades to a daily reminder, and the
   coordinate never leaves the device
2. **Reviewer cannot scan a receipt** and reports the core feature broken. The
   notes tell them to use manual entry
3. **Metadata mismatch.** The listing describes bill splitting; the app also
   contains a going-out reminder and a currency converter. Both are mentioned in
   the description on purpose — an unexplained feature reads as scope creep

## After approval

- [ ] Revoke the GitHub tokens created during setup
- [ ] Decide whether `Split-me` should stay public now that the site has its own
      repository
