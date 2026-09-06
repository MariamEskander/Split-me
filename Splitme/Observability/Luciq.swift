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

        // Shake to report is discoverable without putting a button over the UI;
        // the floating button would sit on top of the bill being split.
        Luciq.start(withToken: appToken, invocationEvents: [.shake, .screenshot])

        configureNetworkMasking()
        configureScreenshotMasking()
    }

    /// Split Me sends no credentials anywhere today, but the redaction list
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

    /// Screenshots of this app show real bills: what people ate, what they
    /// owe, and their names. So screenshots are captured **only** for bug
    /// reports, which the user starts deliberately and can review before
    /// sending. Crashes and session replay record the steps without images —
    /// enough to reproduce a bug, without silently shipping someone's dinner
    /// receipt to a dashboard.
    ///
    /// Change `.allCrashes` to `.enable` if crash screenshots prove necessary,
    /// but treat that as a privacy decision, not a debugging convenience.
    private static func configureScreenshotMasking() {
        Luciq.setReproStepsFor(.bug, with: .enable)
        Luciq.setReproStepsFor(.allCrashes, with: .enabledWithNoScreenshots)
        Luciq.setReproStepsFor(.sessionReplay, with: .enabledWithNoScreenshots)
    }
}
