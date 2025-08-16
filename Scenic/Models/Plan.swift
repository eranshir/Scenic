import Foundation

struct Plan: Identifiable, Codable {
    let id: UUID
    var userId: UUID
    var name: String
    var startDate: Date?
    var endDate: Date?
    var timezoneIdentifier: String
    var isOfflineCached: Bool
    var items: [PlanItem]
    var createdAt: Date
    var updatedAt: Date
    
    var timezone: TimeZone {
        TimeZone(identifier: timezoneIdentifier) ?? TimeZone.current
    }
    
    var sortedItems: [PlanItem] {
        items.sorted { item1, item2 in
            if let date1 = item1.targetDate, let date2 = item2.targetDate {
                if date1 == date2 {
                    if let arrival1 = item1.plannedArrivalUTC,
                       let arrival2 = item2.plannedArrivalUTC {
                        return arrival1 < arrival2
                    }
                }
                return date1 < date2
            }
            return false
        }
    }
}

struct PlanItem: Identifiable, Codable {
    let id: UUID
    var planId: UUID
    var spotId: UUID
    var spot: Spot?
    var targetDate: Date?
    var plannedArrivalUTC: Date?
    var plannedDepartureUTC: Date?
    var backupRank: Int?
    var notes: String?
    var isCompleted: Bool
    
    var durationMinutes: Int? {
        guard let arrival = plannedArrivalUTC,
              let departure = plannedDepartureUTC else { return nil }
        return Int(departure.timeIntervalSince(arrival) / 60)
    }
}

