import Foundation

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let baseURL = "https://ywuojdghqyozoiaaglbn.supabase.co"
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3dW9qZGdocXlvem9pYWFnbGJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzUzOTI4NzQsImV4cCI6MjA1MDk2ODg3NH0.QfbR_ELGLxJy0JRJ4DQYgNVSTxGNT-FDXFiLZT4nS4g"
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var participatingMeetings: [Meeting] = []
    @Published var hostedMeetings: [Meeting] = []
    
    private init() {}
    
    // MARK: - Business Logic
    var canCreateMeeting: Bool {
        // 이미 호스팅 중인 활성 모임이 있거나, 참여 중인 모임이 있으면 새 모임 생성 불가
        let hasActiveHostedMeeting = hostedMeetings.contains { $0.status == .recruiting }
        let hasParticipatingMeeting = !participatingMeetings.isEmpty
        return !hasActiveHostedMeeting && !hasParticipatingMeeting
    }
    
    func isParticipating(in meeting: Meeting) -> Bool {
        return participatingMeetings.contains { $0.id == meeting.id }
    }
    
    func isHosting(_ meeting: Meeting) -> Bool {
        return meeting.hostId == currentUser?.id
    }
    
    // MARK: - Headers
    private var headers: [String: String] {
        return [
            "apikey": apiKey,
            "Authorization": "Bearer \(apiKey)",
            "Content-Type": "application/json",
            "Prefer": "return=representation"
        ]
    }
    
    // MARK: - Auth (Simple Mock for MVP)
    func signUp(nickname: String, password: String, profileIcon: String) async throws {
        // For MVP, create a mock user
        let mockUser = User(
            id: UUID(),
            nickname: nickname,
            profileIcon: profileIcon,
            createdAt: Date()
        )
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.currentUser = mockUser
            self.isAuthenticated = true
        }
    }
    
    func signIn(nickname: String, password: String) async throws {
        // For MVP, create a mock user
        let mockUser = User(
            id: UUID(),
            nickname: nickname,
            profileIcon: AppConfig.profileIcons.randomElement(),
            createdAt: Date()
        )
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            self.currentUser = mockUser
            self.isAuthenticated = true
        }
    }
    
    func signOut() async throws {
        await MainActor.run {
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    // MARK: - REST API Helper
    private func makeRequest<T: Codable>(
        endpoint: String,
        method: String = "GET",
        body: Data? = nil
    ) async throws -> T {
        
        guard let url = URL(string: "\(baseURL)/rest/v1/\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let body = body {
            request.httpBody = body
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw APIError.serverError
        }
        
        // Handle empty responses for DELETE requests
        if method == "DELETE" && data.isEmpty {
            return "" as! T
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(T.self, from: data)
    }
    
    // MARK: - Restaurants
    func fetchRestaurants() async throws -> [Restaurant] {
        return try await makeRequest(endpoint: "restaurants?select=*")
    }
    
    func createRestaurant(name: String, category: String?, description: String?, mapUrl: String?) async throws {
        let restaurant = [
            "name": name,
            "category": category,
            "description": description,
            "map_url": mapUrl
        ]
        
        let data = try JSONSerialization.data(withJSONObject: restaurant)
        let _: [Restaurant] = try await makeRequest(
            endpoint: "restaurants",
            method: "POST",
            body: data
        )
    }
    
    // MARK: - Meetings
    func fetchMeetings(week: Int? = nil) async throws -> [Meeting] {
        var endpoint = "meetings?select=*,users!meetings_host_id_fkey(nickname),restaurants!meetings_selected_restaurant_id_fkey(name)"
        
        if let week = week {
            endpoint += "&week=eq.\(week)"
        }
        
        endpoint += "&order=date.desc"
        
        return try await makeRequest(endpoint: endpoint)
    }
    
    func createMeeting(
        date: Date,
        time: Date,
        week: Int,
        type: MeetingType,
        selectedRestaurantId: UUID?
    ) async throws -> Meeting {
        
        guard let userId = currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        // 모임 생성 권한 확인
        if !canCreateMeeting {
            throw APIError.cannotCreateMeeting
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        formatter.dateFormat = "HH:mm:ss"
        let timeString = formatter.string(from: time)
        
        let meeting = [
            "host_id": userId.uuidString,
            "date": dateString,
            "time": timeString,
            "week": week,
            "type": type.rawValue,
            "selected_restaurant_id": selectedRestaurantId?.uuidString
        ] as [String: Any?]
        
        let data = try JSONSerialization.data(withJSONObject: meeting.compactMapValues { $0 })
        let result: [Meeting] = try await makeRequest(
            endpoint: "meetings",
            method: "POST",
            body: data
        )
        
        return result.first!
    }
    
    // MARK: - Meeting Participation
    func joinMeeting(meetingId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        // 이미 참여 중인 모임이 있는지 확인
        if !participatingMeetings.isEmpty {
            throw APIError.alreadyParticipating
        }
        
        // 이미 이 모임에 참여 중인지 확인
        if participatingMeetings.contains(where: { $0.id == meetingId }) {
            throw APIError.alreadyParticipating
        }
        
        let participant = [
            "meeting_id": meetingId.uuidString,
            "user_id": userId.uuidString
        ]
        
        let data = try JSONSerialization.data(withJSONObject: participant)
        let _: String = try await makeRequest(
            endpoint: "meeting_participants",
            method: "POST",
            body: data
        )
        
        // 로컬 상태 업데이트 (실제로는 서버에서 모임 정보를 다시 가져와야 함)
        await loadUserMeetings()
    }
    
    func leaveMeeting(meetingId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        let deleteEndpoint = "meeting_participants?meeting_id=eq.\(meetingId.uuidString)&user_id=eq.\(userId.uuidString)"
        let _: String = try await makeRequest(
            endpoint: deleteEndpoint,
            method: "DELETE"
        )
        
        // 로컬 상태 업데이트
        await MainActor.run {
            participatingMeetings.removeAll { $0.id == meetingId }
        }
    }
    
    func loadUserMeetings() async {
        // Mock implementation - 실제로는 API에서 사용자의 참여/호스팅 모임을 가져옴
        await MainActor.run {
            // 예시: 참여 중인 모임 1개
            if !participatingMeetings.isEmpty {
                return // 이미 로드됨
            }
            
            // Mock 참여 모임 추가 (테스트용)
            if Bool.random() {
                participatingMeetings = [
                    Meeting(
                        id: UUID(),
                        hostId: UUID(),
                        hostNickname: "다른사람",
                        date: Date().addingTimeInterval(3600),
                        time: Date(),
                        week: getCurrentWeek(),
                        type: .roulette,
                        status: .recruiting,
                        selectedRestaurantId: nil,
                        selectedRestaurantName: nil,
                        rouletteResult: nil,
                        rouletteSpunAt: nil,
                        rouletteSpunBy: nil,
                        createdAt: Date(),
                        participantCount: 2,
                        voteCount: 1
                    )
                ]
            }
        }
    }
    
    private func getCurrentWeek() -> Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: Date())
    }
    
    // MARK: - Voting
    func vote(meetingId: UUID, restaurantId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        // First delete existing vote
        let deleteEndpoint = "meeting_votes?meeting_id=eq.\(meetingId.uuidString)&user_id=eq.\(userId.uuidString)"
        let _: String = try await makeRequest(
            endpoint: deleteEndpoint,
            method: "DELETE"
        )
        
        // Then insert new vote
        let vote = [
            "meeting_id": meetingId.uuidString,
            "user_id": userId.uuidString,
            "restaurant_id": restaurantId.uuidString
        ]
        
        let data = try JSONSerialization.data(withJSONObject: vote)
        let _: String = try await makeRequest(
            endpoint: "meeting_votes",
            method: "POST",
            body: data
        )
    }
    
    // MARK: - Roulette
    func spinRoulette(meetingId: UUID) async throws -> UUID {
        guard let userId = currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        // For MVP, simulate roulette with mock data
        // In real implementation, call the PostgreSQL function
        
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
        
        // Return random restaurant ID (mock)
        return UUID()
    }
}

// MARK: - Sample Data for MVP
extension SupabaseService {
    func loadSampleData() async throws -> [Restaurant] {
        // Sample restaurants based on your existing data
        return [
            Restaurant(
                id: UUID(),
                name: "순이",
                category: "면류",
                description: "해산물 라멘 전문점",
                mapUrl: nil,
                createdAt: Date()
            ),
            Restaurant(
                id: UUID(),
                name: "맘스터치",
                category: "햄버거",
                description: "국내 햄버거 체인점",
                mapUrl: nil,
                createdAt: Date()
            ),
            Restaurant(
                id: UUID(),
                name: "상해교자",
                category: "중식",
                description: "만두 전문 중식당",
                mapUrl: nil,
                createdAt: Date()
            ),
            Restaurant(
                id: UUID(),
                name: "해오름",
                category: "한식",
                description: "한식 정식 전문점",
                mapUrl: nil,
                createdAt: Date()
            ),
            Restaurant(
                id: UUID(),
                name: "탐솥",
                category: "한식",
                description: "솥밥 전문점",
                mapUrl: nil,
                createdAt: Date()
            )
        ]
    }
}

// MARK: - Errors
enum APIError: LocalizedError {
    case invalidURL
    case serverError
    case notAuthenticated
    case decodingError
    case alreadyParticipating
    case cannotCreateMeeting
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .serverError:
            return "서버 오류가 발생했습니다."
        case .notAuthenticated:
            return "로그인이 필요합니다."
        case .decodingError:
            return "데이터 처리 중 오류가 발생했습니다."
        case .alreadyParticipating:
            return "이미 다른 모임에 참여 중입니다."
        case .cannotCreateMeeting:
            return "참여 중이거나 호스팅 중인 모임이 있어 새 모임을 만들 수 없습니다."
        }
    }
}