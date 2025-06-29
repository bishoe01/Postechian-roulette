import SwiftUI

struct MeetingParticipant: Identifiable {
    let id: UUID
    let userId: UUID
    let nickname: String
    let profileIcon: String?
    let isHost: Bool
}

struct MeetingDetailView: View {
    let meeting: Meeting
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseService
    
    @State private var isParticipating = false
    @State private var selectedRestaurant: UUID?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showRouletteResult = false
    @State private var rouletteWinner: String?
    @State private var candidates: [Restaurant] = []
    @State private var selectedVote: UUID?
    @State private var showHostOptions = false
    @State private var participants: [MeetingParticipant] = []
    
    var isHost: Bool {
        supabase.currentUser?.id == meeting.hostId
    }
    
    var canJoin: Bool {
        !isParticipating && meeting.status == .recruiting
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header Card
                headerCard
                
                // Meeting Details
                detailsCard
                
                // Restaurant Info (Fixed) or Voting (Roulette)
                if meeting.type == .fixed {
                    fixedRestaurantCard
                } else {
                    rouletteVotingCard
                }
                
                // Participants Section
                participantsCard
                
                // Action Buttons
                actionButtons
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(errorMessage == "참여 완료!" ? .green : .red)
                        .font(.caption)
                        .padding()
                        .background((errorMessage == "참여 완료!" ? Color.green : Color.red).opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .navigationTitle("모임 상세")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("닫기") {
                    dismiss()
                }
                .foregroundColor(AppConfig.primaryColor)
            }
        }
        .task {
            await loadParticipationStatus()
            await loadParticipants()
            if meeting.type == .roulette {
                await loadCandidates()
            }
        }
        .alert("룰렛 결과", isPresented: $showRouletteResult) {
            Button("확인") { }
        } message: {
            if let winner = rouletteWinner {
                Text("당첨된 음식점: \(winner)")
            }
        }
        .confirmationDialog("모임 파토내기", isPresented: $showHostOptions) {
            Button("모임 삭제하기", role: .destructive) {
                deleteMeeting()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("정말로 모임을 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
        }
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    // 모임 타입과 상태
                    HStack(spacing: 8) {
                        Image(systemName: meeting.type == .fixed ? "checkmark.circle.fill" : "shuffle")
                            .foregroundColor(meeting.type == .fixed ? .green : AppConfig.primaryColor)
                            .font(.title3)
                        
                        Text(meeting.type.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(meeting.type == .fixed ? .green : AppConfig.primaryColor)
                        
                        Spacer()
                        
                        StatusBadge(status: meeting.status)
                    }
                    
                    // 메인 제목 (음식점 이름 또는 투표 모임)
                    if meeting.type == .fixed, let restaurantName = meeting.selectedRestaurantName {
                        Text(restaurantName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    } else {
                        Text("투표로 결정하는 모임")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    // 호스트 정보
                    HStack(spacing: 8) {
                        Text("👤")
                            .font(.title3)
                        
                        Text("호스트: \(meeting.hostNickname ?? "알 수 없음")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(meeting.type == .fixed ? Color.green.opacity(0.05) : AppConfig.lightPink)
        )
    }
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("모임 정보")
                .font(.headline)
                .fontWeight(.bold)
            
            VStack(spacing: 12) {
                DetailRow(
                    icon: "calendar",
                    title: "날짜",
                    value: meeting.date.formatted(date: .abbreviated, time: .omitted)
                )
                
                DetailRow(
                    icon: "clock",
                    title: "시간",
                    value: meeting.time.formatted(date: .omitted, time: .shortened)
                )
                
                DetailRow(
                    icon: "person.3",
                    title: "참여자",
                    value: "\(meeting.participantCount ?? 0)명"
                )
                
                if meeting.type == .roulette {
                    DetailRow(
                        icon: "hand.raised",
                        title: "투표",
                        value: "\(meeting.voteCount ?? 0)표"
                    )
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppConfig.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var fixedRestaurantCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("선택된 음식점")
                .font(.headline)
                .fontWeight(.bold)
            
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(AppConfig.primaryColor)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.selectedRestaurantName ?? "음식점 정보 없음")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("확정된 음식점입니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppConfig.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var rouletteVotingCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("투표하기")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                if isHost && meeting.status == .recruiting {
                    Button("룰렛 돌리기") {
                        spinRoulette()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppConfig.primaryColor)
                    .cornerRadius(12)
                }
            }
            
            if let result = meeting.rouletteResult {
                VStack(alignment: .leading, spacing: 8) {
                    Text("룰렛 결과")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(AppConfig.primaryColor)
                    
                    Text("당첨: \(result.candidates.first(where: { $0.restaurantId == result.selectedRestaurantId })?.restaurantName ?? "알 수 없음")")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            } else if isParticipating {
                VStack(spacing: 8) {
                    Text("후보 음식점들 중 선택해주세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    LazyVStack(spacing: 8) {
                        ForEach(candidates) { restaurant in
                            VotingOptionRow(
                                restaurantName: restaurant.name,
                                isSelected: selectedVote == restaurant.id
                            ) {
                                voteForRestaurant(restaurant.id)
                            }
                        }
                    }
                }
            } else {
                Text("모임에 참여하면 투표할 수 있습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppConfig.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var participantsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("참여자 (\(participants.count)명)")
                .font(.headline)
                .fontWeight(.bold)
            
            if participants.isEmpty {
                Text("참여자가 없습니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(participants) { participant in
                        HStack {
                            Text(participant.profileIcon ?? "👤")
                                .font(.title2)
                            
                            Text(participant.nickname)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            if participant.isHost {
                                Text("HOST")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppConfig.primaryColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(AppConfig.lightPink)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppConfig.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if isHost {
                // 호스트인 경우 - 파토내기 버튼
                Button {
                    showHostOptions = true
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("파토내기")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.red)
                    .cornerRadius(12)
                }
            } else if canJoin {
                // 참여 가능한 경우 - 참여하기 버튼
                Button {
                    joinMeeting()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        } else {
                            Image(systemName: "person.badge.plus")
                            Text("참여하기")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppConfig.primaryColor)
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            } else if isParticipating {
                // 이미 참여한 경우 - 참여 취소 버튼
                Button {
                    leaveMeeting()
                } label: {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.red)
                        } else {
                            Image(systemName: "person.badge.minus")
                            Text("참여 취소")
                        }
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .disabled(isLoading)
            }
        }
    }
    
    private func loadParticipationStatus() async {
        await supabase.loadUserMeetings()
        await MainActor.run {
            isParticipating = supabase.isParticipating(in: meeting)
            print("DEBUG: loadParticipationStatus - isParticipating: \(isParticipating)")
            print("DEBUG: loadParticipationStatus - participatingMeetings count: \(supabase.participatingMeetings.count)")
        }
    }
    
    private func loadParticipants() async {
        do {
            // 참여자 ID 목록 가져오기
            struct ParticipantRecord: Codable {
                let user_id: UUID
            }
            
            let participantEndpoint = "meeting_participants?meeting_id=eq.\(meeting.id.uuidString)&select=user_id"
            let participantRecords: [ParticipantRecord] = try await supabase.makePublicRequest(endpoint: participantEndpoint)
            
            var allParticipants: [MeetingParticipant] = []
            
            // 호스트를 먼저 추가
            let hostEndpoint = "users?id=eq.\(meeting.hostId.uuidString)&select=id,nickname,profile_icon"
            struct UserInfo: Codable {
                let id: UUID
                let nickname: String
                let profile_icon: String?
            }
            let hostInfo: [UserInfo] = try await supabase.makePublicRequest(endpoint: hostEndpoint)
            
            if let host = hostInfo.first {
                let hostParticipant = MeetingParticipant(
                    id: host.id,
                    userId: host.id,
                    nickname: host.nickname,
                    profileIcon: host.profile_icon,
                    isHost: true
                )
                allParticipants.append(hostParticipant)
            }
            
            // 다른 참여자들 추가
            for record in participantRecords {
                // 호스트가 아닌 참여자만 추가
                if record.user_id != meeting.hostId {
                    let userEndpoint = "users?id=eq.\(record.user_id.uuidString)&select=id,nickname,profile_icon"
                    let userInfo: [UserInfo] = try await supabase.makePublicRequest(endpoint: userEndpoint)
                    
                    if let user = userInfo.first {
                        let participant = MeetingParticipant(
                            id: user.id,
                            userId: user.id,
                            nickname: user.nickname,
                            profileIcon: user.profile_icon,
                            isHost: false
                        )
                        allParticipants.append(participant)
                    }
                }
            }
            
            await MainActor.run {
                self.participants = allParticipants
                print("DEBUG: loadParticipants - Loaded \(allParticipants.count) participants")
                for participant in allParticipants {
                    print("  - \(participant.nickname) (Host: \(participant.isHost))")
                }
            }
        } catch {
            print("DEBUG: loadParticipants - Failed to load participants: \(error)")
            await MainActor.run {
                self.participants = []
            }
        }
    }
    
    private func joinMeeting() {
        isLoading = true
        errorMessage = ""
        
        print("DEBUG: MeetingDetail - joinMeeting called")
        print("DEBUG: MeetingDetail - supabase.currentUser = \(String(describing: supabase.currentUser))")
        print("DEBUG: MeetingDetail - supabase.isAuthenticated = \(supabase.isAuthenticated)")
        print("DEBUG: MeetingDetail - meeting.id = \(meeting.id)")
        
        Task {
            do {
                try await supabase.joinMeeting(meetingId: meeting.id)
                
                await MainActor.run {
                    isParticipating = true
                    isLoading = false
                    errorMessage = "참여 완료!"
                }
                
                // 참여 후 상태 다시 로드
                await loadParticipationStatus()
                await loadParticipants()
                
                // 성공 메시지 3초 후 제거
                try await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    errorMessage = ""
                }
                
                print("DEBUG: MeetingDetail - joinMeeting successful, isParticipating = true")
            } catch {
                print("DEBUG: MeetingDetail - joinMeeting failed: \(error)")
                await MainActor.run {
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .notAuthenticated:
                            errorMessage = "로그인이 필요합니다"
                        case .alreadyParticipating:
                            errorMessage = "이미 다른 모임에 참여 중입니다"
                        default:
                            errorMessage = error.localizedDescription
                        }
                    } else {
                        errorMessage = "모임 참여 실패: \(error.localizedDescription)"
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private func leaveMeeting() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                print("DEBUG: MeetingDetail - leaveMeeting called")
                try await supabase.leaveMeeting(meetingId: meeting.id)
                
                await MainActor.run {
                    isParticipating = false
                    isLoading = false
                    errorMessage = "참여 취소 완료!"
                }
                
                // 참여 취소 후 상태 다시 로드
                await loadParticipationStatus()
                await loadParticipants()
                
                // 성공 메시지 2초 후 모달 닫기
                try await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    dismiss()
                }
                
                print("DEBUG: MeetingDetail - leaveMeeting successful")
            } catch {
                print("DEBUG: MeetingDetail - leaveMeeting failed: \(error)")
                await MainActor.run {
                    if let apiError = error as? APIError {
                        switch apiError {
                        case .notAuthenticated:
                            errorMessage = "로그인이 필요합니다"
                        default:
                            errorMessage = "참여 취소 실패: \(error.localizedDescription)"
                        }
                    } else {
                        errorMessage = "참여 취소 실패: \(error.localizedDescription)"
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private func spinRoulette() {
        Task {
            do {
                let winnerId = try await supabase.spinRoulette(meetingId: meeting.id)
                await MainActor.run {
                    rouletteWinner = "맘스터치" // Mock winner name
                    showRouletteResult = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func loadCandidates() async {
        do {
            let fetchedCandidates = try await supabase.getMeetingCandidates(meetingId: meeting.id)
            await MainActor.run {
                self.candidates = fetchedCandidates
                self.selectedVote = supabase.getUserVote(meetingId: meeting.id)
            }
        } catch {
            print("Failed to load candidates: \(error)")
        }
    }
    
    private func voteForRestaurant(_ restaurantId: UUID) {
        Task {
            do {
                try await supabase.vote(meetingId: meeting.id, restaurantId: restaurantId)
                await MainActor.run {
                    selectedVote = restaurantId
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func deleteMeeting() {
        Task {
            do {
                print("DEBUG: MeetingDetail - deleteMeeting called for meetingId: \(meeting.id)")
                print("DEBUG: MeetingDetail - currentUser: \(String(describing: supabase.currentUser?.id))")
                print("DEBUG: MeetingDetail - isHost: \(isHost)")
                
                try await supabase.deleteMeeting(meetingId: meeting.id)
                
                print("DEBUG: MeetingDetail - deleteMeeting successful")
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("DEBUG: MeetingDetail - deleteMeeting failed: \(error)")
                await MainActor.run {
                    errorMessage = "모임 삭제 실패: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(AppConfig.primaryColor)
                .font(.title3)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct VotingOptionRow: View {
    let restaurantName: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(restaurantName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppConfig.primaryColor : .gray)
                    .font(.title3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? AppConfig.lightPink : Color(.systemGray6))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationView {
        MeetingDetailView(meeting: Meeting(
            id: UUID(),
            hostId: UUID(),
            hostNickname: "김철수",
            dateString: "2025-06-29",
            timeString: "18:00:00",
            week: 25,
            type: .roulette,
            status: .recruiting,
            selectedRestaurantId: nil,
            selectedRestaurantName: nil,
            rouletteResult: nil,
            rouletteSpunAt: nil,
            rouletteSpunBy: nil,
            createdAt: Date(),
            participantCount: 3,
            voteCount: 2
        ))
    }
}