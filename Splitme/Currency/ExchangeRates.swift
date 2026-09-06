import Foundation

/// A set of rates as published, kept whole so a bill's figures can always be
/// traced back to a dated snapshot rather than a moving number.
struct RateSnapshot: Codable, Equatable {
    /// Every rate is quoted against this code, so any pair can be derived from
    /// one request.
    var base: String
    var rates: [String: Double]
    /// When the provider last recalculated. The free tier moves once a day.
    var publishedAt: Date
    /// When this device fetched it.
    var fetchedAt: Date

    func rate(from: String, to: String) -> Double? {
        guard let source = rates[from], let target = rates[to], source != 0 else { return nil }
        return target / source
    }

    func convert(_ amount: Double, from: String, to: String) -> Double? {
        rate(from: from, to: to).map { amount * $0 }
    }

    var codes: [String] { rates.keys.sorted() }

    var isStale: Bool { Date().timeIntervalSince(fetchedAt) > 6 * 3600 }
}

/// Reads public exchange rates. No key, so nothing secret ships in the binary —
/// which is why this provider was chosen over the ones that need one.
enum RatesProvider {
    /// exchangerate-api's open endpoint: 160-plus currencies, updated daily.
    static let endpoint = URL(string: "https://open.er-api.com/v6/latest/USD")!
    static let attribution = "Rates by exchangerate-api.com"

    private struct Payload: Decodable {
        let result: String
        let baseCode: String
        let lastUpdate: Double
        let rates: [String: Double]

        enum CodingKeys: String, CodingKey {
            case result
            case baseCode = "base_code"
            case lastUpdate = "time_last_update_unix"
            case rates
        }
    }

    enum Failure: LocalizedError {
        case badResponse
        case providerError(String)

        var errorDescription: String? {
            switch self {
            case .badResponse: return "The rates service returned something unexpected."
            case .providerError(let result): return "The rates service reported: \(result)."
            }
        }
    }

    static func fetch() async throws -> RateSnapshot {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 12
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw Failure.badResponse
        }

        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.result == "success" else { throw Failure.providerError(payload.result) }

        return RateSnapshot(
            base: payload.baseCode,
            rates: payload.rates,
            publishedAt: Date(timeIntervalSince1970: payload.lastUpdate),
            fetchedAt: Date()
        )
    }
}

/// Holds the current snapshot, cached on disk so the converter still works with
/// no signal — a stale rate that says how old it is beats a spinner.
@MainActor
@Observable
final class RatesStore {
    enum Status: Equatable {
        case idle
        case loading
        case ready
        /// Failed, but there may still be a cached snapshot to show.
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var snapshot: RateSnapshot?

    private static let cacheKey = "splitme.rates.snapshot"

    init() {
        snapshot = Self.readCache()
        if snapshot != nil { status = .ready }
    }

    /// Fetches only when the cache is missing or old, unless forced.
    func refresh(force: Bool = false) async {
        if !force, let snapshot, !snapshot.isStale {
            status = .ready
            return
        }
        if case .loading = status { return }

        status = .loading
        do {
            let fresh = try await RatesProvider.fetch()
            snapshot = fresh
            Self.writeCache(fresh)
            status = .ready
        } catch {
            // Keep whatever is cached; only the banner changes.
            status = .failed(error.localizedDescription)
        }
    }

    // MARK: Cache

    private static func readCache() -> RateSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(RateSnapshot.self, from: data)
    }

    private static func writeCache(_ snapshot: RateSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
}

extension String {
    /// "EGP" → "Egyptian Pound" / "جنيه مصري". Takes the locale explicitly: the
    /// in-app language is an environment value, not `Locale.current`.
    func currencyName(in locale: Locale) -> String {
        locale.localizedString(forCurrencyCode: self) ?? self
    }
}
