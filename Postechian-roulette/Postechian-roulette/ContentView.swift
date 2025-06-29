import SwiftUI

struct ContentView: View {
    @StateObject private var supabase = SupabaseService.shared
    
    var body: some View {
        Group {
            if supabase.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            MeetingListView()
                .tabItem {
                    Image(systemName: "calendar")
                    Text("모임")
                }
            
            RestaurantListView()
                .tabItem {
                    Image(systemName: "fork.knife")
                    Text("음식점")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("프로필")
                }
        }
        .accentColor(AppConfig.primaryColor)
    }
}

struct LoginView: View {
    @StateObject private var supabase = SupabaseService.shared
    @State private var nickname = ""
    @State private var password = ""
    @State private var selectedIcon = AppConfig.profileIcons.first ?? "👤"
    @State private var isLoading = false
    @State private var showSignUp = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(AppConfig.primaryColor)
                    
                    Text("포스테키안 룰렛")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("함께 맛있는 식사를 선택해보세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                // Login Form
                VStack(spacing: 20) {
                    TextField("닉네임", text: $nickname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    SecureField("비밀번호", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button {
                        login()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                            } else {
                                Text("로그인")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(AppConfig.primaryColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || nickname.isEmpty || password.isEmpty)
                    
                    Button("계정이 없으신가요? 회원가입") {
                        showSignUp = true
                    }
                    .foregroundColor(AppConfig.primaryColor)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
    }
    
    private func login() {
        isLoading = true
        Task {
            try? await supabase.signIn(nickname: nickname, password: password)
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseService.shared
    @State private var nickname = ""
    @State private var password = ""
    @State private var selectedIcon = AppConfig.profileIcons.first ?? "👤"
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("회원가입")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Icon Selection
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(AppConfig.profileIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                        } label: {
                            Text(icon)
                                .font(.title)
                                .frame(width: 50, height: 50)
                                .background(selectedIcon == icon ? AppConfig.secondaryColor.opacity(0.3) : Color.clear)
                                .overlay(
                                    Circle()
                                        .stroke(selectedIcon == icon ? AppConfig.primaryColor : Color.gray.opacity(0.3), lineWidth: 2)
                                )
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal)
                
                VStack(spacing: 16) {
                    TextField("닉네임", text: $nickname)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    SecureField("비밀번호", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button {
                        signUp()
                    } label: {
                        Text("가입하기")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(AppConfig.primaryColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(nickname.isEmpty || password.isEmpty || isLoading)
                }
                .padding(.horizontal, 32)
                
                Spacer()
            }
            .padding(.top, 40)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") { dismiss() }
                }
            }
        }
    }
    
    private func signUp() {
        isLoading = true
        Task {
            try? await supabase.signUp(nickname: nickname, password: password, profileIcon: selectedIcon)
            await MainActor.run {
                isLoading = false
                dismiss()
            }
        }
    }
}

struct MeetingListView: View {
    @StateObject private var supabase = SupabaseService.shared
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
                date: Date(),
                time: Date(),
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
                participantCount: 5,
                voteCount: 3
            )
        ]
        
        await MainActor.run {
            self.fixedMeetings = mockFixedMeetings
            self.rouletteMeetings = mockRouletteMeetings
            self.isLoading = false
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
                VStack(alignment: .leading, spacing: 4) {
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
                    
                    Text(meeting.hostNickname ?? "알 수 없음")
                        .font(.headline)
                        .fontWeight(.bold)
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
                
                if meeting.type == .fixed, let restaurantName = meeting.selectedRestaurantName {
                    HStack {
                        Image(systemName: "fork.knife")
                            .foregroundColor(AppConfig.primaryColor)
                            .font(.caption)
                        Text(restaurantName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
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

struct RestaurantListView: View {
    @StateObject private var supabase = SupabaseService.shared
    @State private var restaurants: [Restaurant] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("음식점 목록을 불러오는 중...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if restaurants.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("음식점 목록이 없어요")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(restaurants) { restaurant in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(restaurant.name)
                                .font(.headline)
                            if let category = restaurant.category {
                                Text(category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("음식점")
            .task {
                await loadRestaurants()
            }
        }
    }
    
    private func loadRestaurants() async {
        do {
            let fetchedRestaurants = try await supabase.loadSampleData()
            await MainActor.run {
                self.restaurants = fetchedRestaurants
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct ProfileView: View {
    @StateObject private var supabase = SupabaseService.shared
    @State private var showingSignOutAlert = false
    @State private var showingPreferences = false
    @State private var showingHistory = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Profile Header
                if let user = supabase.currentUser {
                    VStack(spacing: 20) {
                        Text(user.profileIcon ?? "👤")
                            .font(.system(size: 100))
                            .frame(width: 140, height: 140)
                            .background(
                                Circle()
                                    .fill(AppConfig.lightPink)
                            )
                        
                        VStack(spacing: 8) {
                            Text(user.nickname)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("포스테키안 룰렛 멤버")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 40)
                }
                
                // Current Meeting Section
                currentMeetingSection
                
                // Menu Items
                VStack(spacing: 16) {
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
                
                Spacer()
                
                // Sign Out Button
                Button {
                    showingSignOutAlert = true
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.square")
                        Text("로그아웃")
                    }
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationTitle("프로필")
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
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(20)
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
            HStack(spacing: 16) {
                // Glow effect circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [role.color.opacity(0.8), role.color.opacity(0.3)],
                            center: .center,
                            startRadius: 8,
                            endRadius: 20
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: meeting.type == .fixed ? "checkmark.circle.fill" : "shuffle")
                            .foregroundColor(.white)
                            .font(.title3)
                    )
                    .shadow(color: role.color.opacity(0.5), radius: 8, x: 0, y: 4)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(role.displayName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(role.color)
                            .cornerRadius(8)
                        
                        Text(meeting.type.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(meeting.type == .fixed ? .green : AppConfig.primaryColor)
                    }
                    
                    if role == .participant {
                        Text("by \(meeting.hostNickname ?? "알 수 없음")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(AppConfig.primaryColor)
                            .font(.caption)
                        Text(meeting.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    Text("자세히")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [role.color.opacity(0.1), role.color.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(role.color.opacity(0.3), lineWidth: 1)
                    )
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

#Preview {
    ContentView()
}