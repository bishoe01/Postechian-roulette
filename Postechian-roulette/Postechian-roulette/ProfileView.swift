import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var supabase: SupabaseService
    @State private var showingSignOutAlert = false
    @State private var showingPreferences = false
    @State private var showingHistory = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Compact Profile Header
                    if let user = supabase.currentUser {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                Text(user.profileIcon ?? "👤")
                                    .font(.system(size: 50))
                                    .frame(width: 70, height: 70)
                                    .background(
                                        Circle()
                                            .fill(AppConfig.lightPink)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.nickname)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    
                                    Text("포스테키안 룰렛 멤버")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    // 로그아웃 버튼을 헤더에 작게 추가
                                    Button {
                                        showingSignOutAlert = true
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.right.square")
                                                .font(.caption2)
                                            Text("로그아웃")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(6)
                                    }
                                    .padding(.top, 4)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: AppConfig.primaryColor.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }
                    
                    // Current Meeting Section
                    currentMeetingSection
                    
                    // Menu Items
                    VStack(spacing: 12) {
                        ProfileMenuItem(
                            icon: "heart.fill",
                            title: "내 선호도",
                            subtitle: "음식점별 선호도 관리",
                            color: AppConfig.primaryColor
                        ) {
                            showingPreferences = true
                        }
                        
                        ProfileMenuItem(
                            icon: "clock.fill",
                            title: "참여 기록",
                            subtitle: "지난 모임 참여 내역",
                            color: AppConfig.primaryColor
                        ) {
                            showingHistory = true
                        }
                        
                        ProfileMenuItem(
                            icon: "gearshape.fill",
                            title: "설정",
                            subtitle: "앱 설정 및 알림",
                            color: AppConfig.primaryColor
                        ) {
                            // TODO: Navigate to settings
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 하단 여백 추가 (탭바와 겹치지 않도록)
                    Color.clear.frame(height: 100)
                }
            }
            .navigationTitle("프로필")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemGroupedBackground))
        }
        .alert("로그아웃", isPresented: $showingSignOutAlert) {
            Button("취소", role: .cancel) { }
            Button("로그아웃", role: .destructive) {
                signOut()
            }
        } message: {
            Text("정말 로그아웃하시겠습니까?")
        }
        .sheet(isPresented: $showingPreferences) {
            PreferencesView()
        }
        .sheet(isPresented: $showingHistory) {
            MeetingHistoryView()
        }
        .task {
            await supabase.loadUserMeetings()
        }
        .refreshable {
            await supabase.loadUserMeetings()
        }
    }
    
    private var currentMeetingSection: some View {
        Group {
            if !supabase.participatingMeetings.isEmpty || !supabase.hostedMeetings.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("현재 참여 중인 모임")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppConfig.primaryColor)
                    
                    VStack(spacing: 12) {
                        // 호스팅 중인 모임
                        ForEach(supabase.hostedMeetings.filter { $0.status == .recruiting }) { meeting in
                            CurrentMeetingCard(meeting: meeting, role: .host)
                        }
                        
                        // 참여 중인 모임
                        ForEach(supabase.participatingMeetings) { meeting in
                            CurrentMeetingCard(meeting: meeting, role: .participant)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
    
    private func signOut() {
        Task {
            try? await supabase.signOut()
        }
    }
}

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: color.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

enum MeetingRole {
    case host
    case participant
    
    var displayName: String {
        switch self {
        case .host:
            return "HOST"
        case .participant:
            return "참여자"
        }
    }
    
    var color: Color {
        switch self {
        case .host:
            return AppConfig.primaryColor
        case .participant:
            return .blue
        }
    }
}

struct CurrentMeetingCard: View {
    let meeting: Meeting
    let role: MeetingRole
    @State private var showingMeetingDetail = false
    
    var body: some View {
        Button {
            showingMeetingDetail = true
        } label: {
            HStack(spacing: 12) {
                // Compact icon
                Circle()
                    .fill(role.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: meeting.type == .fixed ? "checkmark.circle.fill" : "shuffle")
                            .foregroundColor(role.color)
                            .font(.caption)
                    )
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(role.displayName)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(role.color)
                            .cornerRadius(4)
                        
                        // 모임 제목 (음식점 이름 또는 투표 모임)
                        if meeting.type == .fixed, let restaurantName = meeting.selectedRestaurantName {
                            Text(restaurantName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        } else {
                            Text("투표 모임")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if role == .participant {
                        Text("by \(meeting.hostNickname ?? "알 수 없음")")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(meeting.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: role.color.opacity(0.1), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingMeetingDetail) {
            NavigationView {
                MeetingDetailView(meeting: meeting)
            }
        }
    }
}