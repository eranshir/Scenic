import Foundation
import CoreLocation

// MARK: - Plan

struct Plan: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String?
    let createdBy: UUID // User ID
    let createdAt: Date
    var updatedAt: Date
    var isPublic: Bool
    var originalPlanId: UUID? // For forked plans
    var estimatedDuration: Int? // Days
    var startDate: Date?
    var endDate: Date?
    var items: [PlanItem]
    
    // MARK: - Computed Properties
    
    /// Returns the plan duration in days if both start and end dates are set
    var actualDuration: Int? {
        guard let start = startDate, let end = endDate else { return nil }
        return Calendar.current.dateComponents([.day], from: start, to: end).day
    }
    
    /// Returns a formatted date range string
    var dateRangeString: String? {
        guard let start = startDate else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if let end = endDate {
            if Calendar.current.isDate(start, inSameDayAs: end) {
                return formatter.string(from: start)
            } else {
                return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
            }
        } else {
            return "Starting \(formatter.string(from: start))"
        }
    }
    
    /// Returns items sorted by order index
    var sortedItems: [PlanItem] {
        items.sorted { $0.orderIndex < $1.orderIndex }
    }
    
    /// Returns items sorted chronologically (if scheduled)
    var chronologicalItems: [PlanItem] {
        items.sorted { item1, item2 in
            // First sort by scheduled date
            if let date1 = item1.scheduledDate, let date2 = item2.scheduledDate {
                if date1 == date2 {
                    // Same date, sort by start time
                    if let time1 = item1.scheduledStartTime, let time2 = item2.scheduledStartTime {
                        return time1 < time2
                    }
                }
                return date1 < date2
            }
            // Fallback to order index
            return item1.orderIndex < item2.orderIndex
        }
    }
    
    /// Statistics about the plan
    var stats: PlanStats {
        let itemsByType = Dictionary(grouping: items) { $0.type }
        return PlanStats(
            totalItems: items.count,
            spotCount: itemsByType[.spot]?.count ?? 0,
            accommodationCount: itemsByType[.accommodation]?.count ?? 0,
            restaurantCount: itemsByType[.restaurant]?.count ?? 0,
            attractionCount: itemsByType[.attraction]?.count ?? 0,
            scheduledItems: items.filter { $0.scheduledDate != nil }.count,
            isScheduled: !items.isEmpty && items.allSatisfy { $0.scheduledDate != nil }
        )
    }
}

// MARK: - PlanItem

struct PlanItem: Identifiable, Codable, Hashable {
    let id: UUID
    let planId: UUID
    var type: PlanItemType
    var orderIndex: Int
    var scheduledDate: Date?
    var scheduledStartTime: Date?
    var scheduledEndTime: Date?
    var timingPreference: TimingPreference?
    
    // For spot items
    var spotId: UUID?
    var spot: Spot? // Populated when loading from database
    
    // For POI items (accommodation, restaurant, attraction)
    var poiData: POIData?
    
    var notes: String?
    let createdAt: Date
    
    // MARK: - Computed Properties
    
    /// Display name for the item
    var displayName: String {
        switch type {
        case .spot:
            return spot?.title ?? "Unknown Spot"
        case .accommodation, .restaurant, .attraction:
            return poiData?.name ?? "Unknown Place"
        }
    }
    
    /// Location coordinate for the item
    var coordinate: CLLocationCoordinate2D? {
        switch type {
        case .spot:
            return spot?.location
        case .accommodation, .restaurant, .attraction:
            return poiData?.coordinate
        }
    }
    
    /// Duration in minutes if both start and end times are set
    var durationMinutes: Int? {
        guard let start = scheduledStartTime,
              let end = scheduledEndTime else { return nil }
        return Int(end.timeIntervalSince(start) / 60)
    }
    
    /// Formatted time range string
    var timeRangeString: String? {
        guard let start = scheduledStartTime else { return nil }
        
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        if let end = scheduledEndTime {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else {
            return formatter.string(from: start)
        }
    }
}

// MARK: - Supporting Types

enum PlanItemType: String, CaseIterable, Codable {
    case spot = "spot"
    case accommodation = "accommodation"
    case restaurant = "restaurant"
    case attraction = "attraction"
    
    var displayName: String {
        switch self {
        case .spot: return "Photo Spot"
        case .accommodation: return "Accommodation"
        case .restaurant: return "Restaurant"
        case .attraction: return "Attraction"
        }
    }
    
    var systemImage: String {
        switch self {
        case .spot: return "camera.fill"
        case .accommodation: return "bed.double.fill"
        case .restaurant: return "fork.knife"
        case .attraction: return "star.fill"
        }
    }
}

enum TimingPreference: String, CaseIterable, Codable {
    case sunrise = "sunrise"
    case sunset = "sunset"
    case goldenHour = "golden_hour"
    case blueHour = "blue_hour"
    case flexible = "flexible"
    
    var displayName: String {
        switch self {
        case .sunrise: return "Sunrise"
        case .sunset: return "Sunset"
        case .goldenHour: return "Golden Hour"
        case .blueHour: return "Blue Hour"
        case .flexible: return "Flexible"
        }
    }
    
    var systemImage: String {
        switch self {
        case .sunrise: return "sunrise.fill"
        case .sunset: return "sunset.fill"
        case .goldenHour: return "sun.max.fill"
        case .blueHour: return "moon.stars.fill"
        case .flexible: return "clock.fill"
        }
    }
}

struct POIData: Codable, Hashable, Equatable {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    let category: String
    var phoneNumber: String?
    var website: String?
    var mapItemIdentifier: String? // Apple Maps MKMapItem identifier
    var businessHours: [String: BusinessHours]? // Day of week -> hours
    var amenities: [String]?
    var rating: Double?
    var priceRange: String? // $, $$, $$$, $$$$
    var photos: [String]? // URLs to photos
    
    static func == (lhs: POIData, rhs: POIData) -> Bool {
        return lhs.name == rhs.name &&
               lhs.address == rhs.address &&
               lhs.coordinate.latitude == rhs.coordinate.latitude &&
               lhs.coordinate.longitude == rhs.coordinate.longitude &&
               lhs.category == rhs.category &&
               lhs.phoneNumber == rhs.phoneNumber &&
               lhs.website == rhs.website &&
               lhs.mapItemIdentifier == rhs.mapItemIdentifier &&
               lhs.businessHours == rhs.businessHours &&
               lhs.amenities == rhs.amenities &&
               lhs.rating == rhs.rating &&
               lhs.priceRange == rhs.priceRange &&
               lhs.photos == rhs.photos
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(address)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
        hasher.combine(category)
        hasher.combine(phoneNumber)
        hasher.combine(website)
        hasher.combine(mapItemIdentifier)
        hasher.combine(rating)
        hasher.combine(priceRange)
    }
}

struct BusinessHours: Codable, Hashable {
    let open: String // HH:MM format
    let close: String // HH:MM format
    let isClosed: Bool // For days when business is closed
    
    init(open: String, close: String, isClosed: Bool = false) {
        self.open = open
        self.close = close
        self.isClosed = isClosed
    }
}

struct PlanStats {
    let totalItems: Int
    let spotCount: Int
    let accommodationCount: Int
    let restaurantCount: Int
    let attractionCount: Int
    let scheduledItems: Int
    let isScheduled: Bool
}

// MARK: - POIData JSON Helpers
extension POIData {
    func toJSONData() throws -> Data {
        return try JSONEncoder().encode(self)
    }
    
    static func fromJSONData(_ data: Data) throws -> POIData {
        return try JSONDecoder().decode(POIData.self, from: data)
    }
    
    func toDictionary() throws -> [String: Any] {
        var dict: [String: Any] = [
            "name": name,
            "address": address,
            "coordinate": [
                "latitude": coordinate.latitude,
                "longitude": coordinate.longitude
            ],
            "category": category
        ]
        
        if let phoneNumber = phoneNumber {
            dict["phone_number"] = phoneNumber
        }
        if let website = website {
            dict["website"] = website
        }
        if let mapItemIdentifier = mapItemIdentifier {
            dict["map_item_identifier"] = mapItemIdentifier
        }
        if let businessHours = businessHours {
            dict["business_hours"] = businessHours.mapValues { hours in
                [
                    "open": hours.open,
                    "close": hours.close,
                    "is_closed": hours.isClosed
                ]
            }
        }
        if let amenities = amenities {
            dict["amenities"] = amenities
        }
        if let rating = rating {
            dict["rating"] = rating
        }
        if let priceRange = priceRange {
            dict["price_range"] = priceRange
        }
        if let photos = photos {
            dict["photos"] = photos
        }
        
        return dict
    }
    
    static func fromDictionary(_ dict: [String: Any]) throws -> POIData {
        guard let name = dict["name"] as? String,
              let address = dict["address"] as? String,
              let coordinateDict = dict["coordinate"] as? [String: Any],
              let latitude = coordinateDict["latitude"] as? Double,
              let longitude = coordinateDict["longitude"] as? Double,
              let category = dict["category"] as? String else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid POIData dictionary")
            )
        }
        
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        var businessHours: [String: BusinessHours]?
        if let hoursDict = dict["business_hours"] as? [String: [String: Any]] {
            businessHours = [:]
            for (day, hours) in hoursDict {
                if let open = hours["open"] as? String,
                   let close = hours["close"] as? String,
                   let isClosed = hours["is_closed"] as? Bool {
                    businessHours?[day] = BusinessHours(open: open, close: close, isClosed: isClosed)
                }
            }
        }
        
        return POIData(
            name: name,
            address: address,
            coordinate: coordinate,
            category: category,
            phoneNumber: dict["phone_number"] as? String,
            website: dict["website"] as? String,
            mapItemIdentifier: dict["map_item_identifier"] as? String,
            businessHours: businessHours,
            amenities: dict["amenities"] as? [String],
            rating: dict["rating"] as? Double,
            priceRange: dict["price_range"] as? String,
            photos: dict["photos"] as? [String]
        )
    }
}

