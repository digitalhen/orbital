import Foundation

/// GA4 Measurement Protocol for tracking app events.
/// No SDK needed — just HTTP POSTs to Google's collection endpoint.
class Analytics {
    static let shared = Analytics()

    private let measurementId = "G-GVZHZ4N315"
    private let apiSecret: String
    private let clientId: String

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        return URLSession(configuration: config)
    }()

    private init() {
        // Stable client ID per install
        let key = "analyticsClientId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            clientId = existing
        } else {
            let id = UUID().uuidString
            UserDefaults.standard.set(id, forKey: key)
            clientId = id
        }

        // API secret from config or bundled
        apiSecret = Bundle.main.object(forInfoDictionaryKey: "GA_API_SECRET") as? String ?? ""
    }

    func track(_ event: String, params: [String: String] = [:]) {
        guard !apiSecret.isEmpty else { return }

        let body: [String: Any] = [
            "client_id": clientId,
            "events": [
                [
                    "name": event,
                    "params": params
                ]
            ]
        ]

        guard let url = URL(string: "https://www.google-analytics.com/mp/collect?measurement_id=\(measurementId)&api_secret=\(apiSecret)"),
              let data = try? JSONSerialization.data(withJSONObject: body) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        session.dataTask(with: request).resume()
    }
}
