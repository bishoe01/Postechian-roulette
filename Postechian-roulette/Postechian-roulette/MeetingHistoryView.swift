import SwiftUI

struct MeetingHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseService.shared
    
    @State private var historyMeetings: [Meeting] = []
    @State private var selectedFilter = "전체"
    @State private var isLoading = true
    
    private let filters = ["전체", "호스트", "참여자", "완료", "취소"]
    
    private var filteredMeetings: [Meeting] {
        var filtered = historyMeetings
        
        switch selectedFilter {
        case "호스트":
            filtered = filtered.filter { $0.hostId == supabase.currentUser?.id }
        case "참여자":
            filtered = filtered.filter { $0.hostId != supabase.currentUser?.id }
        case "완료":
            filtered = filtered.filter { $0.status == .completed }
        case "취소":
            filtered = filtered.filter { $0.status == .closed }
        default:
            break
        }
        
        return filtered.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Section
                filterSection
                
                if isLoading {
                    Spacer()
                    ProgressView("기록을 불러오는 중...")
                    Spacer()
                } else if filteredMeetings.isEmpty {
                    emptyStateView
                } else {
                    // History List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredMeetings) { meeting in
                                HistoryMeetingCard(meeting: meeting)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("참여 기록")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundColor(AppConfig.primaryColor)
                }
            }
        }
        .task {
            await loadHistory()
        }
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(filters, id: \.self) { filter in
                    FilterChip(
                        title: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(AppConfig.secondaryColor)
            
            VStack(spacing: 8) {
                Text("참여 기록이 없어요")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text("모임에 참여하면 기록이 여기에 나타납니다")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func loadHistory() async {
        // Mock history data
        let mockHistory = [
            Meeting(
                id: UUID(),
                hostId: UUID(),
                hostNickname: "김철수",
                date: Date().addingTimeInterval(-86400 * 7), // 1주 전
                time: Date(),
                week: 25,
                type: .fixed,
                status: .completed,
                selectedRestaurantId: UUID(),
                selectedRestaurantName: "맘스터치",
                rouletteResult: nil,
                rouletteSpunAt: nil,
                rouletteSpunBy: nil,
                createdAt: Date().addingTimeInterval(-86400 * 8),
                participantCount: 4,
                voteCount: 0
            ),
            Meeting(
                id: UUID(),
                hostId: supabase.currentUser?.id ?? UUID(),
                hostNickname: supabase.currentUser?.nickname ?? "나",
                date: Date().addingTimeInterval(-86400 * 14), // 2주 전
                time: Date(),
                week: 24,
                type: .roulette,
                status: .completed,
                selectedRestaurantId: nil,
                selectedRestaurantName: nil,
                rouletteResult: nil,
                rouletteSpunAt: nil,
                rouletteSpunBy: nil,
                createdAt: Date().addingTimeInterval(-86400 * 15),
                participantCount: 3,
                voteCount: 6
            ),
            Meeting(
                id: UUID(),
                hostId: UUID(),
                hostNickname: "이영희",
                date: Date().addingTimeInterval(-86400 * 21), // 3주 전
                time: Date(),
                week: 23,
                type: .fixed,
                status: .closed,
                selectedRestaurantId: UUID(),
                selectedRestaurantName: "순이",
                rouletteResult: nil,
                rouletteSpunAt: nil,
                rouletteSpunBy: nil,
                createdAt: Date().addingTimeInterval(-86400 * 22),
                participantCount: 2,
                voteCount: 0
            )
        ]
        
        await MainActor.run {
            self.historyMeetings = mockHistory
            self.isLoading = false
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : AppConfig.primaryColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? AppConfig.primaryColor : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppConfig.primaryColor, lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct HistoryMeetingCard: View {
    let meeting: Meeting
    @StateObject private var supabase = SupabaseService.shared
    
    private var isHost: Bool {
        meeting.hostId == supabase.currentUser?.id
    }
    
    private var roleText: String {
        isHost ? "HOST" : "참여자"
    }
    
    private var roleColor: Color {
        isHost ? AppConfig.primaryColor : .blue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(roleText)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(roleColor)
                            .cornerRadius(8)
                        
                        Image(systemName: meeting.type == .fixed ? "checkmark.circle.fill" : "shuffle")
                            .foregroundColor(meeting.type == .fixed ? .green : AppConfig.primaryColor)
                            .font(.caption)
                        
                        Text(meeting.type.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(meeting.type == .fixed ? .green : AppConfig.primaryColor)
                    }
                    
                    if !isHost {
                        Text("by \(meeting.hostNickname ?? "알 수 없음")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    StatusBadge(status: meeting.status)
                    
                    Text(timeAgoString(from: meeting.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Meeting Details
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(AppConfig.primaryColor)
                        .font(.caption)
                    Text(meeting.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.subheadline)
                    
                    Image(systemName: "person.3")
                        .foregroundColor(AppConfig.primaryColor)
                        .font(.caption)
                        .padding(.leading, 12)
                    Text("\(meeting.participantCount ?? 0)명")
                        .font(.subheadline)
                }
                
                if meeting.type == .fixed, let restaurantName = meeting.selectedRestaurantName {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(AppConfig.primaryColor)
                            .font(.caption)
                        Text(restaurantName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                } else if meeting.type == .roulette {
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundColor(AppConfig.primaryColor)
                            .font(.caption)
                        Text("\(meeting.voteCount ?? 0)표 참여")
                            .font(.subheadline)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        let days = Int(timeInterval / 86400)
        
        if days == 0 {
            return "오늘"
        } else if days < 7 {
            return "\(days)일 전"
        } else if days < 30 {
            let weeks = days / 7
            return "\(weeks)주 전"
        } else {
            let months = days / 30
            return "\(months)개월 전"
        }
    }
}

#Preview {
    MeetingHistoryView()
}