import Foundation

struct WeatherLocation: Identifiable, Codable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var isCurrentLocation: Bool

    // Runtime only, not persisted
    var temperature: Int?
    var weatherCode: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, isCurrentLocation
    }

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, isCurrentLocation: Bool = false) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.isCurrentLocation = isCurrentLocation
    }
}

struct GeoSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let admin1: String?
    let country: String?
    let latitude: Double
    let longitude: Double

    var displayName: String {
        [name, admin1, country].compactMap { $0 }.joined(separator: ", ")
    }
}
