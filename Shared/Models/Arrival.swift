import Foundation
import CoreLocation

// Modelo de dominio de un arribo para la UI. No es el JSON crudo.
struct Arrival: Identifiable {
    let id: String
    let serviceId: String?
    let lineId: Int
    let line: TrainLine
    let ramalName: String
    let destinationName: String
    let originName: String
    let trackName: String?
    let scheduled: Date?
    let estimated: Date?
    let secondsUntil: Int
    let delay: DelayStatus
    let trainLocation: CLLocationCoordinate2D?
    let equipmentName: String?
    let isElectric: Bool
    let isCancelled: Bool
    let direction: Int
    let stateName: String?
    let route: [RouteStop]
}

// ServiceAlert vive en su propio archivo; ver ServiceAlert.swift.
