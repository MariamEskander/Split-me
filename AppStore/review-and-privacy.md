# App Review Information & the privacy questionnaires

The two questionnaires are quick because Split Me genuinely collects nothing.
The review notes are the part worth reading — they pre-empt the rejection this
app is most likely to get.

## App Review Information → Notes

Paste this verbatim. It answers, before it is asked, why an app about bills
requests background location.

```
No account or login is required. All features are available immediately.

TESTING THE RECEIPT SCANNER
The scanner uses Apple's on-device Vision text recognition and needs a physical
receipt in front of the camera. If no receipt is available on the review device,
please use "Or add the items by hand" on the Items tab to add items manually —
every other feature (assigning items, tax and service, shares, sharing) works
identically with hand-entered items.

WHY THE APP REQUESTS "ALWAYS" LOCATION
Only for the optional reminder on the Essentials tab. The user sets a home
location, and the app registers a single UNLocationNotificationTrigger with a
CLCircularRegion around it, with notifyOnExit set. iOS delivers a local
notification when the user leaves that area, reminding them of the items they
listed (water bottle, ID, keys). This cannot work with "When In Use", because
noticing that the user has left home requires the system to evaluate the region
while the app is not running.

The permission is never required. If the user declines, or grants only "When In
Use", the feature falls back to a daily local notification at a time the user
chooses, and the screen states which mode is active. Nothing else in the app
depends on it.

The coordinate is stored only in the app's own preferences on the device and is
compared only against that region. It is never transmitted — the app has no
server and no account system.

WHY THE APP REQUESTS "WHEN IN USE" LOCATION
Separately and also optionally, to suggest nearby restaurants and cafés when
naming a bill (MKLocalSearch). Declining leaves the name as a plain text field.

NETWORK USE
Two requests only, neither carrying personal data: exchange rates from
open.er-api.com (public, keyless) for the Currency tab, and Apple Maps place
searches when the user taps the nearby-places button.
```

## App Review Information → Contact

| Field | Value |
|---|---|
| First / Last name | Mariam Eskander |
| Phone | *(your number — required)* |
| Email | mariam.rizk62@gmail.com |
| Sign-in required | **No** |

## App Privacy questionnaire

Answer: **"No, we do not collect data from this app."**

That is accurate and covers every category. For the record, if a reviewer
queries it:

- Bills, items, people, groups and the essentials list are in an on-device
  SwiftData store and never leave the device.
- Receipt images are processed on-device by Vision and are neither stored nor
  transmitted; only the confirmed items and the recognised text are saved.
- Location is used on-device only, as described above.
- No analytics SDK, no crash reporter, no advertising identifier, no third-party
  SDKs of any kind.

The bundled `PrivacyInfo.xcprivacy` matches these answers: no tracking, no
collected data types, and `NSPrivacyAccessedAPICategoryUserDefaults` declared
with reason `CA92.1` (language choice, home coordinate, cached rate snapshot).

## Age Rating questionnaire

Every question: **None**. No unrestricted web access, no gambling, no user
generated content, no in-app purchases. Result: **4+**.

## Export compliance

Already declared in `Splitme-Info.plist` — `ITSAppUsesNonExemptEncryption` is
`false`, because the app uses only standard HTTPS, which is exempt. You will not
be asked at upload time.

## Content rights

The app contains no third-party content requiring rights, with one attribution
obligation already satisfied in the app: the Currency tab credits
`exchangerate-api.com`, as their free tier requires. Keep it visible.
