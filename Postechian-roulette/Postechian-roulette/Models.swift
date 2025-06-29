import Foundation

// MARK: - User
struct User: Codable, Identifiable {
    let id: UUID
    let nickname: String
    let profileIcon: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case nickname
        case profileIcon = "profile_icon"
        case createdAt = "created_at"
    }
}

// MARK: - Restaurant
struct Restaurant: Codable, Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let category: String?
    let description: String?
    let mapUrl: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case category
        case description
        case mapUrl = "map_url"
        case createdAt = "created_at"
    }
}

// MARK: - Meeting Types
enum MeetingType: String, Codable, CaseIterable {
    case fixed = "fixed"
    case roulette = "roulette"
    
    var displayName: String {
        switch self {
        case .fixed:
            return "음식점 지정"
        case .roulette:
            return "투표로 결정"
        }
    }
}

enum MeetingStatus: String, Codable {
    case recruiting = "recruiting"
    case closed = "closed"
    case completed = "completed"
    
    var displayName: String {
        switch self {
        case .recruiting:
            return "모집중"
        case .closed:
            return "마감"
        case .completed:
            return "완료"
        }
    }
}

// MARK: - Meeting
struct Meeting: Codable, Identifiable {
    let id: UUID
    let hostId: UUID
    var hostNickname: String?
    let dateString: String  // "2025-06-29" 형태
    let timeString: String  // "18:19:01" 형태
    let week: Int
    let type: MeetingType
    let status: MeetingStatus
    let selectedRestaurantId: UUID?
    var selectedRestaurantName: String?
    let rouletteResult: RouletteResult?
    let rouletteSpunAt: Date?
    let rouletteSpunBy: UUID?
    let createdAt: Date
    var participantCount: Int?
    var voteCount: Int?
    
    // Computed properties for Date objects
    var date: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }
    
    var time: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.date(from: timeString) ?? Date()
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case hostId = "host_id"
        case hostNickname = "host_nickname"
        case dateString = "date"
        case timeString = "time"
        case week
        case type
        case status
        case selectedRestaurantId = "selected_restaurant_id"
        case selectedRestaurantName = "selected_restaurant_name"
        case rouletteResult = "roulette_result"
        case rouletteSpunAt = "roulette_spun_at"
        case rouletteSpunBy = "roulette_spun_by"
        case createdAt = "created_at"
        case participantCount = "participant_count"
        case voteCount = "vote_count"
    }
}

// MARK: - Roulette
struct RouletteResult: Codable {
    let randomValue: Double
    let candidates: [RouletteCandidate]
    let selectedRestaurantId: UUID
    
    enum CodingKeys: String, CodingKey {
        case randomValue = "random_value"
        case candidates
        case selectedRestaurantId = "selected_restaurant_id"
    }
}

struct RouletteCandidate: Codable {
    let restaurantId: UUID
    let restaurantName: String
    let voteCount: Int
    let probability: Double
    
    enum CodingKeys: String, CodingKey {
        case restaurantId = "restaurant_id"
        case restaurantName = "restaurant_name"
        case voteCount = "vote_count"
        case probability
    }
}

// MARK: - Preference
struct Preference: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let restaurantId: UUID
    let score: Float?
    let status: String?
    let note: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case restaurantId = "restaurant_id"
        case score
        case status
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}