import SwiftUI

struct MeetingListView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @State private var selectedTab = 0
    @State private var fixedMeetings: [Meeting] = []
    @State private var rouletteMeetings: [Meeting] = []
    @State private var showingCreateMeeting = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab Selector
                HStack(spacing: 0) {
                    TabButton(
                        title: "음식점 정함",
                        icon: "checkmark.circle.fill",
                        isSelected: selectedTab == 0
                    ) {
                        selectedTab = 0
                    }
                    
                    TabButton(
                        title: "투표로 결정",
                        icon: "shuffle",
                        isSelected: selectedTab == 1
                    ) {
                        selectedTab = 1
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Content
                TabView(selection: $selectedTab) {
                    // Fixed Meetings Tab
                    MeetingContentView(
                        meetings: fixedMeetings,
                        emptyTitle: "정해진 음식점 모임이 없어요",
                        emptySubtitle: "맛있는 음식점을 미리 정하고 사람들을 모아보세요!",
                        emptyIcon: "fork.knife.circle"
                    )
                    .tag(0)
                    
                    // Roulette Meetings Tab
                    MeetingContentView(
                        meetings: rouletteMeetings,
                        emptyTitle: "투표 모임이 없어요",
                        emptySubtitle: "여러 음식점 후보를 정하고 투표로 결정해보세요!",
                        emptyIcon: "dice"
                    )
                    .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("모임")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateMeeting = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(AppConfig.primaryColor)
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateMeeting) {
            CreateMeetingView()
        }
        .task {
            await loadMeetings()
        }
    }
    
    private func loadMeetings() async {
        isLoading = true
        // Mock data for now
        let mockFixedMeetings = [
            Meeting(
                id: UUID(),
                hostId: UUID(),
                hostNickname: "김철수",
                dateString: "2025-06-29",
                timeString: "18:00:00",
                week: getCurrentWeek(),
                type: .fixed,
                status: .recruiting,
                selectedRestaurantId: UUID(),
                selectedRestaurantName: "맘스터치",
                rouletteResult: nil,
                rouletteSpunAt: nil,
                rouletteSpunBy: nil,
                createdAt: Date(),
                participantCount: 3,
                voteCount: 0
            )
        ]
        
        let mockRouletteMeetings = [
            Meeting(
                id: UUID(),
                hostId: UUID(),
                hostNickname: "이영희",
                dateString: "2025-06-30",
                timeString: "19:00:00",
                week: getCurrentWeek(),
                type: .roulette,
                status: .recruiting,
                selectedRestaurantId: nil,
                selectedRestaurantName: nil,
                rouletteResult: nil,
                rouletteSpunAt: nil,
                rouletteSpunBy: nil,
                createdAt: Date(),
                participantCount: 5,
                voteCount: 3
            )
        ]
        
        do {
            // 실제 Supabase에서 모임 목록 가져오기
            let currentWeek = getCurrentWeek()
            let endpoint = "meetings?week=eq.\(currentWeek)&status=eq.recruiting&order=created_at.desc"
            
            print("DEBUG: loadMeetings - endpoint: \(endpoint)")
            
            var allMeetings: [Meeting] = try await supabase.makePublicRequest(endpoint: endpoint)
            
            print("DEBUG: loadMeetings - loaded \(allMeetings.count) meetings")
            
            // 각 모임의 호스트 닉네임, 선택된 음식점 이름, 참여자 수를 별도로 가져오기
            for i in 0..<allMeetings.count {
                // 호스트 닉네임 가져오기
                let userEndpoint = "users?id=eq.\(allMeetings[i].hostId.uuidString)&select=nickname"
                do {
                    struct UserNickname: Codable {
                        let nickname: String
                    }
                    let users: [UserNickname] = try await supabase.makePublicRequest(endpoint: userEndpoint)
                    if let hostNickname = users.first?.nickname {
                        allMeetings[i].hostNickname = hostNickname
                    }
                } catch {
                    print("DEBUG: Failed to load host nickname for meeting \(allMeetings[i].id): \(error)")
                    allMeetings[i].hostNickname = "알 수 없음"
                }
                
                // 선택된 음식점 이름 가져오기 (fixed 타입일 경우)
                if let restaurantId = allMeetings[i].selectedRestaurantId {
                    let restaurantEndpoint = "restaurants?id=eq.\(restaurantId.uuidString)&select=name"
                    do {
                        struct RestaurantName: Codable {
                            let name: String
                        }
                        let restaurants: [RestaurantName] = try await supabase.makePublicRequest(endpoint: restaurantEndpoint)
                        if let restaurantName = restaurants.first?.name {
                            allMeetings[i].selectedRestaurantName = restaurantName
                        }
                    } catch {
                        print("DEBUG: Failed to load restaurant name for meeting \(allMeetings[i].id): \(error)")
                        allMeetings[i].selectedRestaurantName = "음식점 정보 없음"
                    }
                }
                
                // 참여자 수 계산 (호스트 포함)
                let participantEndpoint = "meeting_participants?meeting_id=eq.\(allMeetings[i].id.uuidString)&select=user_id"
                do {
                    struct ParticipantCount: Codable {
                        let user_id: UUID
                    }
                    let participants: [ParticipantCount] = try await supabase.makePublicRequest(endpoint: participantEndpoint)
                    // 호스트 + 참여자 수 (호스트가 meeting_participants에 없다면 +1)
                    let hasHostInParticipants = participants.contains { $0.user_id == allMeetings[i].hostId }
                    allMeetings[i].participantCount = participants.count + (hasHostInParticipants ? 0 : 1)
                    print("DEBUG: Meeting \(allMeetings[i].id) has \(participants.count) DB participants + host = \(allMeetings[i].participantCount ?? 0) total")
                } catch {
                    print("DEBUG: Failed to load participant count for meeting \(allMeetings[i].id): \(error)")
                    allMeetings[i].participantCount = 1 // 최소한 호스트는 있음
                }
            }
            
            await MainActor.run {
                self.fixedMeetings = allMeetings.filter { $0.type == .fixed }
                self.rouletteMeetings = allMeetings.filter { $0.type == .roulette }
                self.isLoading = false
            }
        } catch {
            print("DEBUG: Failed to load meetings: \(error)")
            // Fallback to mock data
            await MainActor.run {
                self.fixedMeetings = mockFixedMeetings
                self.rouletteMeetings = mockRouletteMeetings
                self.isLoading = false
            }
        }
    }
    
    private func getCurrentWeek() -> Int {
        let calendar = Calendar.current
        return calendar.component(.weekOfYear, from: Date())
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? AppConfig.primaryColor : Color.clear)
            )
            .foregroundColor(isSelected ? .white : AppConfig.primaryColor)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(AppConfig.primaryColor, lineWidth: isSelected ? 0 : 1)
            )
        }
    }
}

struct MeetingContentView: View {
    let meetings: [Meeting]
    let emptyTitle: String
    let emptySubtitle: String
    let emptyIcon: String
    
    var body: some View {
        if meetings.isEmpty {
            VStack(spacing: 24) {
                Image(systemName: emptyIcon)
                    .font(.system(size: 60))
                    .foregroundColor(AppConfig.secondaryColor)
                
                VStack(spacing: 8) {
                    Text(emptyTitle)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(emptySubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(meetings) { meeting in
                        MeetingCardView(meeting: meeting)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
        }
    }
}

struct MeetingCardView: View {
    let meeting: Meeting
    @State private var showingMeetingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    // 모임 타입 태그
                    HStack(spacing: 8) {
                        Image(systemName: meeting.type == .fixed ? "checkmark.circle.fill" : "shuffle")
                            .foregroundColor(meeting.type == .fixed ? .green : AppConfig.primaryColor)
                            .font(.caption)
                        
                        Text(meeting.type.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(meeting.type == .fixed ? .green : AppConfig.primaryColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(meeting.type == .fixed ? Color.green.opacity(0.1) : AppConfig.lightPink)
                    )
                    
                    // 메인 제목 (음식점 이름 또는 투표 모임)
                    if meeting.type == .fixed, let restaurantName = meeting.selectedRestaurantName {
                        Text(restaurantName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    } else {
                        Text("투표로 결정하는 모임")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    // 호스트 정보
                    HStack(spacing: 4) {
                        Text("👤")
                            .font(.caption)
                        Text("by \(meeting.hostNickname ?? "알 수 없음")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                StatusBadge(status: meeting.status)
            }
            
            // Meeting Info
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(AppConfig.primaryColor)
                        .font(.caption)
                    Text(meeting.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                    
                    Image(systemName: "clock")
                        .foregroundColor(AppConfig.primaryColor)
                        .font(.caption)
                        .padding(.leading, 8)
                    Text(meeting.time.formatted(date: .omitted, time: .shortened))
                        .font(.subheadline)
                }
                
                
                HStack {
                    Image(systemName: "person.3")
                        .foregroundColor(AppConfig.primaryColor)
                        .font(.caption)
                    Text("\(meeting.participantCount ?? 0)명 참여")
                        .font(.subheadline)
                    
                    if meeting.type == .roulette {
                        Image(systemName: "hand.raised")
                            .foregroundColor(AppConfig.primaryColor)
                            .font(.caption)
                            .padding(.leading, 8)
                        Text("\(meeting.voteCount ?? 0)표")
                            .font(.subheadline)
                    }
                }
            }
            
            // Action Button
            Button {
                showingMeetingDetail = true
            } label: {
                HStack {
                    Text("참여하기")
                        .fontWeight(.medium)
                    Image(systemName: "arrow.right")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppConfig.primaryColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppConfig.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
        )
        .sheet(isPresented: $showingMeetingDetail) {
            NavigationView {
                MeetingDetailView(meeting: meeting)
            }
        }
    }
}

struct StatusBadge: View {
    let status: MeetingStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .recruiting:
            return .green
        case .closed:
            return AppConfig.primaryColor
        case .completed:
            return .gray
        }
    }
}