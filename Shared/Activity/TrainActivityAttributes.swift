import Foundation
import ActivityKit

// Atributos de la Live Activity. Compartido con el widget para renderizar.
struct TrainActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var eta: Date
        var delaySeconds: Int
        var statusLabel: String
        var trackName: String?
        var isCancelled: Bool
    }

    var stationName: String
    var destinationName: String
    var lineColorHex: String
    var lineShortCode: String
}
