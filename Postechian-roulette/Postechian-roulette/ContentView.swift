import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var supabase: SupabaseService
    
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
    @EnvironmentObject private var supabase: SupabaseService
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
    @EnvironmentObject private var supabase: SupabaseService
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

#Preview {
    ContentView()
}