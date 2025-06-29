import Foundation

// MARK: - Helper Types
struct EmptyResponse: Codable {}

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let baseURL = "https://ywuojdghqyozoiaaglbn.supabase.co"
    private let apiKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3dW9qZGdocXlvem9pYWFnbGJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNzU0ODIsImV4cCI6MjA2Njc1MTQ4Mn0.IMP129nurHwvG2ieJxSNvb5SwBWlenHCLnUKzz6jdGk"
    
    // Mock 모드 플래그 - 실제 DB 준비되면 false로 변경
    private let useMockData = false
    
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
    
    // MARK: - Auth
    func signUp(nickname: String, password: String, profileIcon: String) async throws {
        if useMockData {
            // Mock implementation
            let mockUser = User(
                id: UUID(),
                nickname: nickname,
                profileIcon: profileIcon,
                createdAt: Date()
            )
            
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                self.currentUser = mockUser
                self.isAuthenticated = true
            }
        } else {
            let userPayload = [
                "nickname": nickname,
                "password_hash": password,
                "profile_icon": profileIcon
            ]
            
            let data = try JSONSerialization.data(withJSONObject: userPayload)
            let users: [User] = try await makeRequest(
                endpoint: "users",
                method: "POST",
                body: data
            )
            
            if let user = users.first {
                await MainActor.run {
                    self.currentUser = user
                    self.isAuthenticated = true
                }
            }
        }
    }
    
    func signIn(nickname: String, password: String) async throws {
        if useMockData {
            // Mock implementation
            let mockUser = User(
                id: UUID(),
                nickname: nickname,
                profileIcon: AppConfig.profileIcons.randomElement(),
                createdAt: Date()
            )
            
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                self.currentUser = mockUser
                self.isAuthenticated = true
            }
            
            await loadUserMeetings()
        } else {
            // Supabase API를 통한 인증
            do {
                print("DEBUG: Attempting login for nickname: \(nickname)")
                let users: [User] = try await makeRequest(
                    endpoint: "users?nickname=eq.\(nickname)&password_hash=eq.\(password)&select=*"
                )
                
                print("DEBUG: Found \(users.count) users with matching credentials")
                
                if let user = users.first {
                    print("DEBUG: Authentication successful for user: \(user.nickname)")
                    
                    await MainActor.run {
                        self.currentUser = user
                        self.isAuthenticated = true
                    }
                    
                    // 로그인 후 참여 중인 모임 로드
                    await loadUserMeetings()
                } else {
                    print("DEBUG: Authentication failed - invalid nickname or password")
                    throw APIError.invalidCredentials
                }
            } catch {
                print("DEBUG: Login error: \(error)")
                throw error
            }
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
        
        print("DEBUG: makeRequest - URL: \(url)")
        print("DEBUG: makeRequest - Method: \(method)")
        print("DEBUG: makeRequest - Headers:")
        
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
            print("  \(key): \(value)")
        }
        
        if let body = body {
            request.httpBody = body
            if let bodyString = String(data: body, encoding: .utf8) {
                print("DEBUG: makeRequest - Body: \(bodyString)")
            }
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError
        }
        
        print("DEBUG: makeRequest - Status Code: \(httpResponse.statusCode)")
        
        // Handle different status codes
        switch httpResponse.statusCode {
        case 200...299:
            print("DEBUG: makeRequest - Success")
            break // Success
        case 401:
            print("DEBUG: makeRequest - 401 Unauthorized")
            if let errorData = String(data: data, encoding: .utf8) {
                print("DEBUG: makeRequest - 401 Error response: \(errorData)")
            }
            throw APIError.notAuthenticated
        case 403:
            print("DEBUG: makeRequest - 403 Forbidden")
            if let errorData = String(data: data, encoding: .utf8) {
                print("DEBUG: makeRequest - 403 Error response: \(errorData)")
            }
            throw APIError.notAuthorized
        case 409:
            print("DEBUG: makeRequest - 409 Conflict")
            throw APIError.alreadyParticipating
        default:
            print("DEBUG: makeRequest - Server error: \(httpResponse.statusCode)")
            if let errorData = String(data: data, encoding: .utf8) {
                print("DEBUG: makeRequest - Error response: \(errorData)")
            }
            throw APIError.serverError
        }
        
        // Handle empty responses for DELETE requests
        if method == "DELETE" && data.isEmpty {
            // DELETE 요청의 경우 빈 응답을 EmptyResponse로 처리
            return EmptyResponse() as! T
        }
        
        // Handle empty responses for other methods
        if data.isEmpty {
            return EmptyResponse() as! T
        }
        
        let decoder = JSONDecoder()
        
        // 커스텀 날짜 디코딩 전략
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            // Supabase 타임스탬프 형식들 시도
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'+00:00'",  // Supabase 기본 형식
                "yyyy-MM-dd'T'HH:mm:ss.SSS'+00:00'",     // 밀리초 3자리
                "yyyy-MM-dd'T'HH:mm:ss'+00:00'",         // 초까지만
                "yyyy-MM-dd'T'HH:mm:ssZ",                // ISO8601
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ"             // ISO8601 밀리초
            ]
            
            for format in formats {
                formatter.dateFormat = format
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // 모든 형식이 실패하면 현재 시간 반환
            print("DEBUG: Failed to parse date: \(dateString)")
            return Date()
        }
        
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            print("DEBUG: JSON decoding failed: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("DEBUG: Response data: \(jsonString)")
            }
            throw APIError.decodingError
        }
    }
    
    // MARK: - Restaurants
    func fetchRestaurants() async throws -> [Restaurant] {
        return try await makeRequest(endpoint: "restaurants?select=*")
    }
    
    // MARK: - Public API Helper
    func makePublicRequest<T: Codable>(endpoint: String, method: String = "GET", body: Data? = nil) async throws -> T {
        return try await makeRequest(endpoint: endpoint, method: method, body: body)
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
        
        // 모임 목록 새로고침
        await loadUserMeetings()
        
        return result.first!
    }
    
    // MARK: - Meeting Participation
    func joinMeeting(meetingId: UUID) async throws {
        print("DEBUG: joinMeeting - called with meetingId: \(meetingId)")
        print("DEBUG: joinMeeting - currentUser: \(String(describing: currentUser))")
        print("DEBUG: joinMeeting - isAuthenticated: \(isAuthenticated)")
        
        guard let userId = currentUser?.id else {
            print("DEBUG: joinMeeting - No currentUser, throwing notAuthenticated")
            throw APIError.notAuthenticated
        }
        
        print("DEBUG: joinMeeting - userId: \(userId)")
        print("DEBUG: joinMeeting - participatingMeetings count: \(participatingMeetings.count)")
        
        // 이미 참여 중인 모임이 있는지 확인
        if !participatingMeetings.isEmpty {
            print("DEBUG: joinMeeting - Already participating in another meeting")
            throw APIError.alreadyParticipating
        }
        
        // 이미 이 모임에 참여 중인지 확인
        if participatingMeetings.contains(where: { $0.id == meetingId }) {
            print("DEBUG: joinMeeting - Already participating in this meeting")
            throw APIError.alreadyParticipating
        }
        
        let participant = [
            "meeting_id": meetingId.uuidString,
            "user_id": userId.uuidString
        ]
        
        print("DEBUG: joinMeeting - participant data: \(participant)")
        
        if useMockData {
            // Mock implementation
            print("DEBUG: joinMeeting - Using mock mode")
            try await Task.sleep(nanoseconds: 500_000_000)
            
            // Mock 참여 성공
            await MainActor.run {
                // 임시로 Mock 모임을 participatingMeetings에 추가
                let mockMeeting = Meeting(
                    id: meetingId,
                    hostId: UUID(),
                    hostNickname: "다른 호스트",
                    dateString: "2025-06-29",
                    timeString: "18:00:00",
                    week: 27,
                    type: .fixed,
                    status: .recruiting,
                    selectedRestaurantId: UUID(),
                    selectedRestaurantName: "맘스터치",
                    rouletteResult: nil,
                    rouletteSpunAt: nil,
                    rouletteSpunBy: nil,
                    createdAt: Date(),
                    participantCount: 2,
                    voteCount: 0
                )
                participatingMeetings.append(mockMeeting)
            }
            print("DEBUG: joinMeeting - Mock participation successful")
        } else {
            let data = try JSONSerialization.data(withJSONObject: participant)
            
            do {
                let _: EmptyResponse = try await makeRequest(
                    endpoint: "meeting_participants",
                    method: "POST",
                    body: data
                )
                print("DEBUG: joinMeeting - API call successful")
            } catch {
                print("DEBUG: joinMeeting - API call failed: \(error)")
                throw error
            }
            
            // 로컬 상태 업데이트 (실제로는 서버에서 모임 정보를 다시 가져와야 함)
            await loadUserMeetings()
            print("DEBUG: joinMeeting - loadUserMeetings completed")
        }
    }
    
    func leaveMeeting(meetingId: UUID) async throws {
        guard let userId = currentUser?.id else {
            print("DEBUG: leaveMeeting - No currentUser, throwing notAuthenticated")
            throw APIError.notAuthenticated
        }
        
        print("DEBUG: leaveMeeting - meetingId: \(meetingId), userId: \(userId)")
        
        if useMockData {
            // Mock implementation
            try await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                participatingMeetings.removeAll { $0.id == meetingId }
            }
        } else {
            let deleteEndpoint = "meeting_participants?meeting_id=eq.\(meetingId.uuidString)&user_id=eq.\(userId.uuidString)"
            print("DEBUG: leaveMeeting - deleteEndpoint: \(deleteEndpoint)")
            
            do {
                let _: EmptyResponse = try await makeRequest(
                    endpoint: deleteEndpoint,
                    method: "DELETE"
                )
                print("DEBUG: leaveMeeting - API call successful")
            } catch {
                print("DEBUG: leaveMeeting - API call failed: \(error)")
                throw error
            }
            
            // 로컬 상태 업데이트
            await MainActor.run {
                participatingMeetings.removeAll { $0.id == meetingId }
                print("DEBUG: leaveMeeting - Updated local state")
            }
        }
    }
    
    func deleteMeeting(meetingId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        if useMockData {
            // Mock implementation
            try await Task.sleep(nanoseconds: 500_000_000)
            
            await MainActor.run {
                hostedMeetings.removeAll { $0.id == meetingId }
            }
        } else {
            print("DEBUG: deleteMeeting - meetingId: \(meetingId), userId: \(userId)")
            
            // 모임 삭제 (CASCADE로 관련 데이터도 모두 삭제됨)
            let deleteEndpoint = "meetings?id=eq.\(meetingId.uuidString)&host_id=eq.\(userId.uuidString)"
            
            print("DEBUG: deleteMeeting - deleteEndpoint: \(deleteEndpoint)")
            
            // DELETE 요청은 빈 응답을 반환할 수 있으므로 EmptyResponse 사용
            do {
                let _: EmptyResponse = try await makeRequest(
                    endpoint: deleteEndpoint,
                    method: "DELETE"
                )
                print("DEBUG: deleteMeeting - API call successful")
            } catch {
                print("DEBUG: deleteMeeting - API call failed: \(error)")
                throw error
            }
            
            await MainActor.run {
                hostedMeetings.removeAll { $0.id == meetingId }
                participatingMeetings.removeAll { $0.id == meetingId }
            }
        }
    }
    
    func transferHost(meetingId: UUID, newHostId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        // 호스트인지 확인
        guard hostedMeetings.contains(where: { $0.id == meetingId && $0.hostId == userId }) else {
            throw APIError.notAuthorized
        }
        
        // Mock implementation
        try await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            // 호스팅 목록에서 제거
            hostedMeetings.removeAll { $0.id == meetingId }
            // TODO: 실제로는 서버에서 호스트 변경 API 호출 필요
        }
    }
    
    func loadUserMeetings() async {
        guard let userId = currentUser?.id else { return }
        
        if useMockData {
            // Mock implementation
            await MainActor.run {
                // 처음 로드시에만 Mock 데이터 생성
                if participatingMeetings.isEmpty && hostedMeetings.isEmpty && Bool.random() {
                    let mockMeetingId = UUID()
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    let timeFormatter = DateFormatter()
                    timeFormatter.dateFormat = "HH:mm:ss"
                    
                    let mockMeeting = Meeting(
                        id: mockMeetingId,
                        hostId: UUID(),
                        hostNickname: "다른사람",
                        dateString: dateFormatter.string(from: Date().addingTimeInterval(3600)),
                        timeString: timeFormatter.string(from: Date()),
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
                    
                    // Mock 투표 후보들 저장 (투표 기능을 위해)
                    mockMeetingCandidates[mockMeetingId] = [
                        Restaurant(id: UUID(), name: "순이", category: "면류", description: nil, mapUrl: nil, createdAt: Date()),
                        Restaurant(id: UUID(), name: "맘스터치", category: "햄버거", description: nil, mapUrl: nil, createdAt: Date()),
                        Restaurant(id: UUID(), name: "상해교자", category: "중식", description: nil, mapUrl: nil, createdAt: Date())
                    ]
                    
                    participatingMeetings = [mockMeeting]
                }
            }
        } else {
            do {
                print("DEBUG: loadUserMeetings - Loading for user: \(userId)")
                
                // 참여 중인 모임 ID들 가져오기
                struct ParticipantRecord: Codable {
                    let meeting_id: UUID
                }
                
                let participantEndpoint = "meeting_participants?user_id=eq.\(userId.uuidString)&select=meeting_id"
                let participantRecords: [ParticipantRecord] = try await makeRequest(endpoint: participantEndpoint)
                
                print("DEBUG: loadUserMeetings - Found \(participantRecords.count) participant records")
                
                // 참여 중인 모임들의 상세 정보 가져오기
                var participatingMeetingsData: [Meeting] = []
                if !participantRecords.isEmpty {
                    let meetingIds = participantRecords.map { $0.meeting_id.uuidString }.joined(separator: ",")
                    let participatingEndpoint = "meetings?id=in.(\(meetingIds))&select=*"
                    participatingMeetingsData = try await makeRequest(endpoint: participatingEndpoint)
                    
                    // 참여 중인 모임들의 호스트 닉네임과 음식점 이름 로드
                    for i in 0..<participatingMeetingsData.count {
                        // 호스트 닉네임 가져오기
                        let userEndpoint = "users?id=eq.\(participatingMeetingsData[i].hostId.uuidString)&select=nickname"
                        do {
                            struct UserNickname: Codable {
                                let nickname: String
                            }
                            let users: [UserNickname] = try await makeRequest(endpoint: userEndpoint)
                            if let hostNickname = users.first?.nickname {
                                participatingMeetingsData[i].hostNickname = hostNickname
                            }
                        } catch {
                            participatingMeetingsData[i].hostNickname = "알 수 없음"
                        }
                        
                        // 선택된 음식점 이름 가져오기 (fixed 타입일 경우)
                        if let restaurantId = participatingMeetingsData[i].selectedRestaurantId {
                            let restaurantEndpoint = "restaurants?id=eq.\(restaurantId.uuidString)&select=name"
                            do {
                                struct RestaurantName: Codable {
                                    let name: String
                                }
                                let restaurants: [RestaurantName] = try await makeRequest(endpoint: restaurantEndpoint)
                                if let restaurantName = restaurants.first?.name {
                                    participatingMeetingsData[i].selectedRestaurantName = restaurantName
                                }
                            } catch {
                                participatingMeetingsData[i].selectedRestaurantName = "음식점 정보 없음"
                            }
                        }
                    }
                    
                    print("DEBUG: loadUserMeetings - Loaded \(participatingMeetingsData.count) participating meetings")
                    for meeting in participatingMeetingsData {
                        print("  - Participating in meeting: \(meeting.id)")
                    }
                }
                
                // 호스팅 중인 모임 가져오기
                let hostEndpoint = "meetings?host_id=eq.\(userId.uuidString)&status=eq.recruiting&select=*"
                var hostedData: [Meeting] = try await makeRequest(endpoint: hostEndpoint)
                
                // 호스팅 중인 모임들의 호스트 닉네임(본인)과 음식점 이름 로드
                for i in 0..<hostedData.count {
                    // 호스트 닉네임 (본인)
                    hostedData[i].hostNickname = currentUser?.nickname ?? "알 수 없음"
                    
                    // 선택된 음식점 이름 가져오기 (fixed 타입일 경우)
                    if let restaurantId = hostedData[i].selectedRestaurantId {
                        let restaurantEndpoint = "restaurants?id=eq.\(restaurantId.uuidString)&select=name"
                        do {
                            struct RestaurantName: Codable {
                                let name: String
                            }
                            let restaurants: [RestaurantName] = try await makeRequest(endpoint: restaurantEndpoint)
                            if let restaurantName = restaurants.first?.name {
                                hostedData[i].selectedRestaurantName = restaurantName
                            }
                        } catch {
                            hostedData[i].selectedRestaurantName = "음식점 정보 없음"
                        }
                    }
                }
                
                print("DEBUG: loadUserMeetings - Loaded \(hostedData.count) hosted meetings")
                
                await MainActor.run {
                    self.participatingMeetings = participatingMeetingsData
                    self.hostedMeetings = hostedData
                    print("DEBUG: loadUserMeetings - Updated local state")
                }
            } catch {
                print("DEBUG: loadUserMeetings - Failed to load user meetings: \(error)")
            }
        }
    }
    
    // Mock 투표 후보 저장소
    private var mockMeetingCandidates: [UUID: [Restaurant]] = [:]
    private var mockUserVotes: [UUID: UUID] = [:] // meetingId: restaurantId
    
    private func getCurrentWeek() -> Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: Date())
    }
    
    // MARK: - Voting
    func vote(meetingId: UUID, restaurantId: UUID) async throws {
        guard let userId = currentUser?.id else {
            throw APIError.notAuthenticated
        }
        
        if useMockData {
            // Mock implementation
            try await Task.sleep(nanoseconds: 300_000_000)
            
            await MainActor.run {
                mockUserVotes[meetingId] = restaurantId
            }
        } else {
            // 기존 투표 삭제
            let deleteEndpoint = "meeting_votes?meeting_id=eq.\(meetingId.uuidString)&user_id=eq.\(userId.uuidString)"
            let _: String = try await makeRequest(
                endpoint: deleteEndpoint,
                method: "DELETE"
            )
            
            // 새 투표 추가
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
            
            await MainActor.run {
                mockUserVotes[meetingId] = restaurantId
            }
        }
    }
    
    func getMeetingCandidates(meetingId: UUID) async throws -> [Restaurant] {
        if useMockData {
            // Mock implementation
            return mockMeetingCandidates[meetingId] ?? []
        } else {
            // 실제 API 호출시에는 복잡한 JSON 파싱 필요
            // 지금은 빈 배열 반환
            return []
        }
    }
    
    func getUserVote(meetingId: UUID) -> UUID? {
        // 로컬 캐시 반환 (실제로는 API 호출 필요)
        return mockUserVotes[meetingId]
    }
    
    // MARK: - Roulette
    func spinRoulette(meetingId: UUID) async throws -> UUID {
        guard currentUser?.id != nil else {
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
    case invalidCredentials
    case decodingError
    case alreadyParticipating
    case cannotCreateMeeting
    case notAuthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "잘못된 URL입니다."
        case .serverError:
            return "서버 오류가 발생했습니다."
        case .notAuthenticated:
            return "로그인이 필요합니다."
        case .invalidCredentials:
            return "아이디 또는 비밀번호가 올바르지 않습니다."
        case .decodingError:
            return "데이터 처리 중 오류가 발생했습니다."
        case .alreadyParticipating:
            return "이미 다른 모임에 참여 중입니다."
        case .cannotCreateMeeting:
            return "참여 중이거나 호스팅 중인 모임이 있어 새 모임을 만들 수 없습니다."
        case .notAuthorized:
            return "권한이 없습니다."
        }
    }
}