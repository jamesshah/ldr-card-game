import ConvexMobile
import Foundation

enum AppConfig {
    static let fallbackConvexURL = "https://loyal-lapwing-231.convex.cloud"

    static var convexURL: String {
        resolveConvexURL(Bundle.main.object(forInfoDictionaryKey: "CONVEX_URL") as? String)
    }

    /// Falls back to the production deployment if the build setting is missing or unexpanded.
    static func resolveConvexURL(_ raw: String?) -> String {
        guard let value = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              value.hasPrefix("http"),
              !value.contains("$("),
              let host = URL(string: value)?.host, !host.isEmpty
        else { return fallbackConvexURL }
        return value
    }
}

enum Backend {
    /// One long-lived client for the whole app; ConvexMobile multiplexes subscriptions over one socket.
    static let client = ConvexClient(deploymentUrl: AppConfig.convexURL)

    static func message(for error: Error) -> String {
        if let clientError = error as? ClientError {
            switch clientError {
            case .ConvexError(let data):
                return GameFormatting.convexErrorMessage(fromData: data)
            case .ServerError(let msg):
                return msg.isEmpty ? "Something went wrong on the server. Please try again." : msg
            case .InternalError(let msg):
                return msg.isEmpty ? "Couldn't reach the server. Check your connection." : msg
            }
        }
        return error.localizedDescription
    }

    static var deviceTimeArgs: [String: ConvexEncodable?] {
        [
            "timeZone": TimeZone.current.identifier,
            "utcOffsetMinutes": Double(TimeZone.current.secondsFromGMT() / 60),
        ]
    }
}
