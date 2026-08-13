import Foundation
import Observation

// ViewModel del tablero de estación. Carga arribos en vivo, refresca solo y cae a horario.
@MainActor
@Observable
final class StationBoardViewModel {
    let station: Station

    enum Phase: Equatable {
        case loading
        case live          // arribos en vivo
        case scheduled     // fallback a horario programado
        case empty         // sin arribos ni horario
        case unavailable   // línea no cubierta por la fuente
        case error(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var arrivals: [Arrival] = []
    private(set) var lastUpdated: Date?
    private(set) var isRefreshing = false

    // Filtro por grupo (ramal + sentido). nil = todos.
    var selectedGroupId: String?

    private var refreshTask: Task<Void, Never>?
    private let refreshInterval: TimeInterval = 25
    private let limit = 12

    init(station: Station) {
        self.station = station
    }

    // MARK: - Derivados

    var isLineCovered: Bool { station.line.covered }

    var groups: [ArrivalGrouping.Group] {
        ArrivalGrouping.byRamalDirection(arrivals)
    }

    // Grupos a mostrar según el filtro activo.
    var displayGroups: [ArrivalGrouping.Group] {
        let all = groups
        guard let sel = selectedGroupId else { return all }
        return all.filter { $0.id == sel }
    }

    var hasMultipleGroups: Bool { groups.count > 1 }

    var isScheduled: Bool { phase == .scheduled }

    // MARK: - Ciclo de vida

    func onAppear() {
        if arrivals.isEmpty && phase != .unavailable {
            Task { await load(initial: true) }
        }
        startAutoRefresh()
    }

    func onDisappear() {
        stopAutoRefresh()
    }

    func startAutoRefresh() {
        guard isLineCovered else { return }
        stopAutoRefresh()
        let interval = refreshInterval
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { break }
                await self?.load(initial: false)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    // MARK: - Carga

    // Pull-to-refresh.
    func refresh() async {
        isRefreshing = true
        await load(initial: false)
        isRefreshing = false
    }

    // Reintento manual desde el estado de error.
    func retry() async {
        await load(initial: true)
    }

    func load(initial: Bool) async {
        guard isLineCovered else {
            phase = .unavailable
            arrivals = []
            return
        }

        if initial || arrivals.isEmpty {
            phase = .loading
        }

        do {
            let live = try await SofseClient.shared.arrivals(stationId: station.id, limit: limit)
            if live.isEmpty {
                await loadScheduledFallback()
            } else {
                arrivals = live
                phase = .live
                lastUpdated = Date()
            }
            pruneSelection()
        } catch {
            // Si ya hay datos en pantalla, los conservamos y no rompemos por un refresh fallido.
            if arrivals.isEmpty {
                phase = .error(Self.message(for: error))
            }
        }
    }

    private func loadScheduledFallback() async {
        let now = Date()
        let time = Self.hhmm(now)
        do {
            let sched = try await SofseClient.shared.scheduledArrivals(
                stationId: station.id, date: now, time: time, limit: limit
            )
            if sched.isEmpty {
                arrivals = []
                phase = .empty
            } else {
                arrivals = sched
                phase = .scheduled
            }
            lastUpdated = Date()
        } catch {
            if arrivals.isEmpty {
                arrivals = []
                phase = .empty
            }
        }
    }

    // MARK: - Filtro

    func selectGroup(_ id: String?) {
        selectedGroupId = id
    }

    private func pruneSelection() {
        guard let sel = selectedGroupId else { return }
        if !groups.contains(where: { $0.id == sel }) {
            selectedGroupId = nil
        }
    }

    // MARK: - Helpers

    private static let hhmmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_AR")
        f.timeZone = TimeZone(identifier: "America/Argentina/Buenos_Aires")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static func hhmm(_ date: Date) -> String {
        hhmmFormatter.string(from: date)
    }

    private static func message(for error: Error) -> String {
        if let api = error as? APIError, let desc = api.errorDescription {
            return desc
        }
        return "Revisá tu conexión e intentá de nuevo."
    }
}
