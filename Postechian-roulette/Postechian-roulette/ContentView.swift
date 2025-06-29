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
        .accentColor(.orange)
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
                        .foregroundColor(.orange)
                    
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
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading || nickname.isEmpty || password.isEmpty)
                    
                    Button("계정이 없으신가요? 회원가입") {
                        showSignUp = true
                    }
                    .foregroundColor(.orange)
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
                                .background(selectedIcon == icon ? Color.orange.opacity(0.2) : Color.clear)
                                .overlay(
                                    Circle()
                                        .stroke(selectedIcon == icon ? Color.orange : Color.gray.opacity(0.3), lineWidth: 2)
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
                            .background(Color.orange)
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
    @State private var meetings: [Meeting] = []
    
    var body: some View {
        NavigationView {
            VStack {
                Text("모임 목록")
                    .font(.title)
                    .padding()
                
                if meetings.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("아직 모임이 없어요")
                            .font(.headline)
                        Text("첫 번째 모임을 만들어보세요!")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(meetings) { meeting in
                        Text(meeting.hostNickname ?? "모임")
                    }
                }
            }
            .navigationTitle("모임")
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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                if let user = supabase.currentUser {
                    VStack(spacing: 16) {
                        Text(user.profileIcon ?? "👤")
                            .font(.system(size: 80))
                        
                        Text(user.nickname)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .padding(.top, 40)
                }
                
                Spacer()
                
                Button {
                    Task {
                        try? await supabase.signOut()
                    }
                } label: {
                    Text("로그아웃")
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
        }
    }
}

#Preview {
    ContentView()
}