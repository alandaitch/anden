import Foundation

// Agrupa arribos por ramal y sentido, preservando el orden de llegada.
enum ArrivalGrouping {
    struct Group: Identifiable {
        let id: String
        let ramalName: String
        let direction: Int
        let destinationName: String
        let arrivals: [Arrival]
    }

    static func byRamalDirection(_ arrivals: [Arrival]) -> [Group] {
        var order: [String] = []
        var buckets: [String: [Arrival]] = [:]
        for a in arrivals {
            let key = "\(a.ramalName)#\(a.direction)"
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(a)
        }
        return order.map { key in
            let items = buckets[key] ?? []
            let first = items.first
            return Group(
                id: key,
                ramalName: first?.ramalName ?? "",
                direction: first?.direction ?? 0,
                destinationName: first?.destinationName ?? "",
                arrivals: items
            )
        }
    }
}
