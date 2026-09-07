import Foundation
import LuciqSDK   // The SPM product is "Luciq"; the module is "LuciqSDK".

/// Starts Luciq — crash reporting, bug reports, APM and session replay.
///
/// The token is read from the app's Info.plist, where it arrives from
/// `Config/Luciq.xcconfig` at build time. That file is gitignored: a token
/// committed to a public repository cannot be un-published.
enum Observability {

    /// Empty when `Config/Luciq.xcconfig` has no token, e.g. on a fresh clone.
    private static var appToken: String? {
        let token = (Bundle.main.object(forInfoDictionaryKey: "LuciqAppToken") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }

    /// Call as the first statement of the app's `init()`, so that anything that
    /// crashes during start-up is still captured.
    static func start() {
        guard let appToken else {
            #if DEBUG
            print("[Luciq] No app token — skipping start. Add one to Config/Luciq.xcconfig.")
            #endif
            return
        }

        // The floating button is the only *visible* entry point — without it
        // there is no SDK UI on screen at all, which makes the integration look
        // broken even when it is running. Shake and screenshot are kept as the
        // quieter paths.
        Luciq.start(withToken: appToken,
                    invocationEvents: [.floatingButton, .shake, .screenshot])

        configureNetworkMasking()
        configureScreenshotMasking()
    }

    /// Billy sends no credentials anywhere today, but the redaction list
    /// costs nothing and protects against a future endpoint that does.
    private static func configureNetworkMasking() {
        let headersToMask = ["Authorization", "Cookie", "X-API-Key", "token"]

        NetworkLogger.setRequestObfuscationHandler { request in
            let mutable = (request as NSURLRequest).mutableCopy() as! NSMutableURLRequest
            for header in headersToMask where mutable.value(forHTTPHeaderField: header) != nil {
                mutable.setValue("*****", forHTTPHeaderField: header)
            }
            return mutable.copy() as! URLRequest
        }
    }

    /// Repro steps with screenshots for both bug reports and crashes.
    ///
    /// Note what this means for this app: crash screenshots are captured
    /// automatically, so a crash on the Shares tab ships an image of who owes
    /// what, with names. That is a deliberate choice for debugging value over
    /// minimal capture.
    ///
    /// If that becomes uncomfortable, the fix is auto-masking rather than
    /// turning screenshots off — the SDK can mask all text, all images, or
    /// everything, and individual views can be marked private:
    /// https://docs.luciq.ai/ios/setup-luciq-for-ios/custom-settings/privacy-settings/repro-steps
    private static func configureScreenshotMasking() {
        Luciq.setReproStepsFor(.all, with: .enable)
    }
}
