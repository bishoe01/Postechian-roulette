import SwiftUI

struct MeetingDetailView: View {
    let meeting: Meeting
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseService.shared
    
    @State private var isParticipating = false
    @State private var selectedRestaurant: UUID?
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showRouletteResult = false
    @State private var rouletteWinner: String?
    
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
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                        .background(Color.red.opacity(0.1))
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
        }
        .alert("룰렛 결과", isPresented: $showRouletteResult) {
            Button("확인") { }
        } message: {
            if let winner = rouletteWinner {
                Text("당첨된 음식점: \(winner)")
            }
        }
    }
    
    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: meeting.type == .fixed ? "checkmark.circle.fill" : "shuffle")
                            .foregroundColor(meeting.type == .fixed ? .green : AppConfig.primaryColor)
                            .font(.title2)
                        
                        Text(meeting.type.displayName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(meeting.type == .fixed ? .green : AppConfig.primaryColor)
                    }
                    
                    Text("by \(meeting.hostNickname ?? "알 수 없음")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                StatusBadge(status: meeting.status)
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
                    
                    // Mock voting options - in real app, load from meeting candidates
                    LazyVStack(spacing: 8) {
                        ForEach(["순이", "맘스터치", "상해교자"], id: \.self) { restaurant in
                            VotingOptionRow(
                                restaurantName: restaurant,
                                isSelected: false
                            ) {
                                // Vote for restaurant
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
            Text("참여자 (\(meeting.participantCount ?? 0)명)")
                .font(.headline)
                .fontWeight(.bold)
            
            // Mock participants
            LazyVStack(spacing: 8) {
                ForEach(0..<(meeting.participantCount ?? 0), id: \.self) { index in
                    HStack {
                        Text(AppConfig.profileIcons.randomElement() ?? "👤")
                            .font(.title2)
                        
                        Text("참여자 \(index + 1)")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if index == 0 {
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
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: AppConfig.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if canJoin {
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
                            Text("모임 참여하기")
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
                Button {
                    leaveMeeting()
                } label: {
                    HStack {
                        Image(systemName: "person.badge.minus")
                        Text("참여 취소")
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func loadParticipationStatus() async {
        await supabase.loadUserMeetings()
        await MainActor.run {
            isParticipating = supabase.isParticipating(in: meeting)
        }
    }
    
    private func joinMeeting() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await supabase.joinMeeting(meetingId: meeting.id)
                await MainActor.run {
                    isParticipating = true
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func leaveMeeting() {
        Task {
            do {
                try await supabase.leaveMeeting(meetingId: meeting.id)
                await MainActor.run {
                    isParticipating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
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
            date: Date(),
            time: Date(),
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