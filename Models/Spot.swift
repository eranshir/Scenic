import Foundation
import CoreLocation

struct Spot: Identifiable, Codable {
    let id: UUID
    var title: String
    var location: CLLocationCoordinate2D
    var headingDegrees: Int?
    var elevationMeters: Int?
    var subjectTags: [String]
    var difficulty: Difficulty
    var createdBy: UUID
    var privacy: Privacy
    var license: String
    var status: SpotStatus
    var createdAt: Date
    var updatedAt: Date
    
    // Location metadata from reverse geocoding (optional for backward compatibility)
    var country: String? = nil
    var countryCode: String? = nil
    var administrativeArea: String? = nil // State/Province
    var subAdministrativeArea: String? = nil // County
    var locality: String? = nil // City
    var subLocality: String? = nil // Neighborhood
    var thoroughfare: String? = nil // Street name
    var subThoroughfare: String? = nil // Street number
    var postalCode: String? = nil
    var locationName: String? = nil // Name from placemark
    var areasOfInterest: [String]? = nil // Landmarks/POIs
    
    var media: [Media] = []
    var sunSnapshot: SunSnapshot?
    var weatherSnapshot: WeatherSnapshot?
    var accessInfo: AccessInfo?
    var comments: [Comment] = []
    var voteCount: Int = 0
    
    enum Difficulty: Int, Codable, CaseIterable {
        case veryEasy = 1
        case easy = 2
        case moderate = 3
        case hard = 4
        case veryHard = 5
        
        var displayName: String {
            switch self {
            case .veryEasy: return "Very Easy"
            case .easy: return "Easy"
            case .moderate: return "Moderate"
            case .hard: return "Hard"
            case .veryHard: return "Very Hard"
            }
        }
        
        var icon: String {
            switch self {
            case .veryEasy: return "figure.walk"
            case .easy: return "figure.walk"
            case .moderate: return "figure.hiking"
            case .hard: return "figure.climbing"
            case .veryHard: return "figure.climbing"
            }
        }
    }
    
    enum Privacy: String, Codable {
        case publicSpot = "public"
        case privateSpot = "private"
    }
    
    enum SpotStatus: String, Codable {
        case active
        case pending
        case removed
    }
}

extension CLLocationCoordinate2D: Codable {
    enum CodingKeys: String, CodingKey {
        case latitude
        case longitude
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
}