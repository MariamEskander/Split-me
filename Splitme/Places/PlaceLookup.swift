import CoreLocation
import MapKit
import SwiftUI

/// A place a bill could have happened at.
struct Place: Identifiable, Hashable {
    let id = UUID()
    var name: String
    /// Street and locality, when Maps knows them.
    var detail: String?
    var latitude: Double
    var longitude: Double
    var category: String?

    init?(_ item: MKMapItem) {
        guard let name = item.name, let location = item.placemark.location else { return nil }
        self.name = name
        let parts = [item.placemark.thoroughfare, item.placemark.locality].compactMap { $0 }
        self.detail = parts.isEmpty ? nil : parts.joined(separator: ", ")
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.category = item.pointOfInterestCategory?.rawValue
    }

    /// An icon that matches what kind of place it is.
    var symbol: String {
        switch category.map(MKPointOfInterestCategory.init(rawValue:)) {
        case .some(.cafe):       return "cup.and.saucer.fill"
        case .some(.bakery):     return "birthday.cake.fill"
        case .some(.foodMarket): return "basket.fill"
        case .some(.nightlife), .some(.brewery), .some(.winery): return "wineglass.fill"
        default:                 return "fork.knife"
        }
    }
}

/// A single location fix. Wraps the delegate callbacks so the caller can just
/// `await` a coordinate, and resolves the authorisation prompt on the way.
private final class LocationOnce: NSObject, CLLocationManagerDelegate {
    enum Failure: Error {
        case denied
        case unavailable
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var awaitingAuthorization = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func current() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                awaitingAuthorization = true
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            default:
                finish(.failure(Failure.denied))
            }
        }
    }

    /// Resumes exactly once, whichever callback arrives first.
    private func finish(_ result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard awaitingAuthorization else { return }
        switch manager.authorizationStatus {
        case .notDetermined:
            break   // the prompt is still on screen
        case .authorizedWhenInUse, .authorizedAlways:
            awaitingAuthorization = false
            manager.requestLocation()
        default:
            awaitingAuthorization = false
            finish(.failure(Failure.denied))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            finish(.success(location))
        } else {
            finish(.failure(Failure.unavailable))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(.failure(error))
    }
}

/// Suggests places to name a bill after: what is nearby, then anything the user
/// types, searched around where they are.
///
/// Naming is never blocked on this — every failure path leaves the plain text
/// field working, because splitting a bill on restaurant wifi has to work.
@MainActor
@Observable
final class PlacePicker {
    enum Status: Equatable {
        case idle
        case locating
        case searching
        case ready([Place])
        case noResults
        case denied
        case failed(String)
    }

    private(set) var status: Status = .idle

    private let location = LocationOnce()
    private var center: CLLocationCoordinate2D?
    private var task: Task<Void, Never>?

    /// Whether we have a fix, and so whether typing can be searched nearby.
    var hasLocation: Bool { center != nil }

    /// Food and drink only — nobody names a bill after a petrol station.
    private static let categories: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .bakery, .foodMarket, .brewery, .winery, .nightlife
    ]

    func findNearby() {
        task?.cancel()
        status = .locating
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let coordinate: CLLocationCoordinate2D
                if let center { coordinate = center } else {
                    coordinate = try await location.current().coordinate
                    center = coordinate
                }
                guard !Task.isCancelled else { return }

                status = .searching
                let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: 450)
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: Self.categories)
                try await run(MKLocalSearch(request: request))
            } catch is CancellationError {
                // superseded by a newer request
            } catch LocationOnce.Failure.denied {
                status = .denied
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    /// Debounced, so typing a name does not fire a search per keystroke.
    func search(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let center else { return }
        guard trimmed.count >= 2 else {
            task?.cancel()
            findNearby()
            return
        }

        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }

            status = .searching
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = trimmed
            request.resultTypes = .pointOfInterest
            request.region = MKCoordinateRegion(center: center,
                                                latitudinalMeters: 6000,
                                                longitudinalMeters: 6000)
            do {
                try await run(MKLocalSearch(request: request))
            } catch is CancellationError {
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func dismiss() {
        task?.cancel()
        status = .idle
    }

    private func run(_ search: MKLocalSearch) async throws {
        let response = try await search.start()
        guard !Task.isCancelled else { return }
        let places = response.mapItems.compactMap(Place.init).prefix(8)
        status = places.isEmpty ? .noResults : .ready(Array(places))
    }
}
