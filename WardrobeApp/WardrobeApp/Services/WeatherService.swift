import Foundation
import CoreLocation
import WeatherKit

struct WeatherInfo {
    let currentTemp: Double // Fahrenheit
    let conditionDescription: String
    let conditionSymbol: String
    let highTemp: Double
    let lowTemp: Double
}

@MainActor
class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentWeather: WeatherInfo?
    @Published var locationError: Bool = false

    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        let status = locationManager.authorizationStatus
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            locationError = true
        }
    }

    func fetchWeather() async {
        guard let location = currentLocation else {
            requestLocation()
            return
        }

        do {
            let weatherService = WeatherKit.WeatherService.shared
            let weather = try await weatherService.weather(for: location)

            let current = weather.currentWeather
            let daily = weather.dailyForecast.first

            currentWeather = WeatherInfo(
                currentTemp: current.temperature.converted(to: .fahrenheit).value,
                conditionDescription: current.condition.description,
                conditionSymbol: current.symbolName,
                highTemp: daily?.highTemperature.converted(to: .fahrenheit).value ?? 0,
                lowTemp: daily?.lowTemperature.converted(to: .fahrenheit).value ?? 0
            )
        } catch {
            locationError = true
        }
    }

    func fetchWeatherForLocation(latitude: Double, longitude: Double) async -> WeatherInfo? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let weatherService = WeatherKit.WeatherService.shared
            let weather = try await weatherService.weather(for: location)
            let current = weather.currentWeather
            let daily = weather.dailyForecast.first

            return WeatherInfo(
                currentTemp: current.temperature.converted(to: .fahrenheit).value,
                conditionDescription: current.condition.description,
                conditionSymbol: current.symbolName,
                highTemp: daily?.highTemperature.converted(to: .fahrenheit).value ?? 0,
                lowTemp: daily?.lowTemperature.converted(to: .fahrenheit).value ?? 0
            )
        } catch {
            return nil
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            currentLocation = locations.first
            await fetchWeather()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            locationError = true
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}
