import CoreLocation
import MapKit

protocol GolfCourseNameProviding {
    func nearestCourseName(to coordinate: CLLocationCoordinate2D) async -> String?
}

struct MapKitGolfCourseNameProvider: GolfCourseNameProviding {
    func nearestCourseName(to coordinate: CLLocationCoordinate2D) async -> String? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "golf course"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 8_000,
            longitudinalMeters: 8_000
        )

        guard let response = try? await MKLocalSearch(request: request).start() else {
            return nil
        }

        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        return response.mapItems
            .compactMap { item -> (name: String, distance: CLLocationDistance)? in
                guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                      name.isEmpty == false else {
                    return nil
                }

                let isGolfCourse = name.localizedCaseInsensitiveContains("golf") ||
                    name.localizedCaseInsensitiveContains("country club")

                guard isGolfCourse else {
                    return nil
                }

                let location = CLLocation(
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )

                return (name, location.distance(from: origin))
            }
            .sorted { lhs, rhs in lhs.distance < rhs.distance }
            .first?
            .name
    }
}

struct StaticGolfCourseNameProvider: GolfCourseNameProviding {
    let name: String?

    func nearestCourseName(to coordinate: CLLocationCoordinate2D) async -> String? {
        name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

extension GolfCourseNameProviding where Self == StaticGolfCourseNameProvider {
    static func testingName(_ name: String?) -> StaticGolfCourseNameProvider {
        StaticGolfCourseNameProvider(name: name)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
