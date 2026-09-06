# Brand fonts

The kit specifies **Poppins SemiBold** for headlines and **Inter Regular** for body.
Neither ships with iOS, so `BrandFont` uses them when present and falls back to
SF Rounded (the closest system geometric face) when they are not.

To switch the app onto the real faces, drop these files into this folder:

- `Poppins-SemiBold.ttf`
- `Poppins-Medium.ttf`
- `Inter-Regular.ttf`
- `Inter-Medium.ttf`

Nothing else to do — they are already declared in `UIAppFonts` (`Splitme-Info.plist`),
the folder is inside the synchronized group so Xcode copies them automatically, and
`BrandFont` picks them up at runtime. Both are SIL Open Font License, so they can
ship in the app.
