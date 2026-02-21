import CoreLocation
import Foundation

@Observable
class WeatherService: NSObject, CLLocationManagerDelegate {
    private static let storageKey = "notch.weatherLocations"
    private static let selectedKey = "notch.selectedWeatherLocation"
    private let locationManager = CLLocationManager()
    private var refreshTimer: Timer?
    private var searchTask: URLSessionDataTask?
    private var searchDebounceTimer: Timer?

    var locations: [WeatherLocation] = []
    var searchResults: [GeoSearchResult] = []
    var isSearching = false
    var selectedLocationID: UUID?

    // Left wing data (selected location, fallback to current location)
    private var displayLocation: WeatherLocation? {
        if let id = selectedLocationID, let loc = locations.first(where: { $0.id == id }) {
            return loc
        }
        return locations.first(where: { $0.isCurrentLocation })
    }
    var temperature: Int? { displayLocation?.temperature }
    var weatherCode: Int? { displayLocation?.weatherCode }

    var sfSymbolName: String {
        guard let code = weatherCode else { return "questionmark.circle" }
        return Self.sfSymbol(for: code)
    }

    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "cloud.sun.fill"
        case 2: return "cloud.fill"
        case 3: return "smoke.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "晴"
        case 1: return "少云"
        case 2: return "多云"
        case 3: return "阴"
        case 45, 48: return "雾"
        case 51: return "小毛毛雨"
        case 53: return "毛毛雨"
        case 55: return "大毛毛雨"
        case 56: return "轻冻毛毛雨"
        case 57: return "重冻毛毛雨"
        case 61: return "小雨"
        case 63: return "中雨"
        case 65: return "大雨"
        case 66, 67: return "冻雨"
        case 71: return "小雪"
        case 73: return "中雪"
        case 75: return "大雪"
        case 77: return "雪粒"
        case 80: return "小阵雨"
        case 81: return "阵雨"
        case 82: return "大阵雨"
        case 85, 86: return "阵雪"
        case 95: return "雷暴"
        case 96, 99: return "雷暴冰雹"
        default: return "未知"
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        loadLocations()
        loadSelectedLocation()

        // Ensure current location entry exists
        if !locations.contains(where: { $0.isCurrentLocation }) {
            locations.insert(WeatherLocation(name: "当前位置", latitude: 0, longitude: 0, isCurrentLocation: true), at: 0)
        }
    }

    func startMonitoring() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            // Location denied or restricted, still fetch weather for manually added cities
            fetchAllWeather()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.requestLocationUpdate()
            self?.fetchAllWeather()
        }
    }

    private func requestLocationUpdate() {
        let status = locationManager.authorizationStatus
        if status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }

    // MARK: - Location Management

    func addLocation(_ result: GeoSearchResult) {
        let loc = WeatherLocation(name: result.name, latitude: result.latitude, longitude: result.longitude)
        locations.append(loc)
        saveLocations()
        fetchWeatherByID(loc.id)
    }

    func removeLocation(_ location: WeatherLocation) {
        guard !location.isCurrentLocation else { return }
        if selectedLocationID == location.id {
            selectedLocationID = nil
            saveSelectedLocation()
        }
        locations.removeAll { $0.id == location.id }
        saveLocations()
    }

    func selectLocation(_ location: WeatherLocation) {
        selectedLocationID = location.id
        saveSelectedLocation()
    }

    // MARK: - City Search

    func searchCities(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchDebounceTimer?.invalidate()
            searchTask?.cancel()
            searchResults = []
            return
        }

        searchDebounceTimer?.invalidate()
        searchTask?.cancel()

        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.performCitySearch(trimmed)
        }
    }

    private func performCitySearch(_ query: String) {
        isSearching = true
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=8&language=zh"
        guard let url = URL(string: urlString) else { return }

        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer { DispatchQueue.main.async { self?.isSearching = false } }
            guard let data = data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                DispatchQueue.main.async { self?.searchResults = [] }
                return
            }

            let parsed = results.compactMap { item -> GeoSearchResult? in
                guard let name = item["name"] as? String,
                      let lat = item["latitude"] as? Double,
                      let lon = item["longitude"] as? Double else { return nil }
                return GeoSearchResult(
                    name: name,
                    admin1: item["admin1"] as? String,
                    country: item["country"] as? String,
                    latitude: lat,
                    longitude: lon
                )
            }

            DispatchQueue.main.async {
                self?.searchResults = parsed
            }
        }
        searchTask = task
        task.resume()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        manager.stopUpdatingLocation()

        if let idx = self.locations.firstIndex(where: { $0.isCurrentLocation }) {
            self.locations[idx].latitude = location.coordinate.latitude
            self.locations[idx].longitude = location.coordinate.longitude
        }
        fetchAllWeather()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location failed, still fetch weather for manually added cities
        fetchAllWeather()
    }

    // MARK: - Weather Fetch

    func fetchAllWeather() {
        for location in locations {
            fetchWeatherByID(location.id)
        }
    }

    private func fetchWeatherByID(_ locationID: UUID) {
        guard let loc = locations.first(where: { $0.id == locationID }) else { return }
        guard loc.latitude != 0 || loc.longitude != 0 else { return }

        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(loc.latitude)&longitude=\(loc.longitude)&current=temperature_2m,weather_code"
        guard let url = URL(string: urlString) else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let data = data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any] else { return }

            let temp = current["temperature_2m"] as? Double
            let code = current["weather_code"] as? Int

            DispatchQueue.main.async {
                guard let self = self,
                      let idx = self.locations.firstIndex(where: { $0.id == locationID }) else { return }
                if let temp = temp {
                    self.locations[idx].temperature = Int(temp.rounded())
                }
                self.locations[idx].weatherCode = code
            }
        }.resume()
    }

    // MARK: - Persistence

    private func saveLocations() {
        let custom = locations.filter { !$0.isCurrentLocation }
        if let data = try? JSONEncoder().encode(custom) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    private func loadLocations() {
        guard let data = UserDefaults.standard.data(forKey: Self.storageKey),
              let decoded = try? JSONDecoder().decode([WeatherLocation].self, from: data) else { return }
        locations.append(contentsOf: decoded)
    }

    private func saveSelectedLocation() {
        if let id = selectedLocationID {
            UserDefaults.standard.set(id.uuidString, forKey: Self.selectedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.selectedKey)
        }
    }

    private func loadSelectedLocation() {
        if let str = UserDefaults.standard.string(forKey: Self.selectedKey) {
            selectedLocationID = UUID(uuidString: str)
        }
    }
}
