import SwiftUI

struct CreateMeetingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var supabase: SupabaseService
    
    @State private var selectedType: MeetingType = .fixed
    @State private var selectedDate = Date()
    @State private var selectedTime = Date()
    @State private var selectedRestaurant: Restaurant?
    @State private var selectedCandidates: Set<Restaurant> = []
    @State private var restaurants: [Restaurant] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showRestaurantPicker = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("새 모임 만들기")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("친구들과 함께할 맛있는 식사를 계획해보세요")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 16)
                    
                    // Meeting Type Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("모임 타입")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            TypeSelectionCard(
                                type: .fixed,
                                title: "음식점 미리 정하기",
                                subtitle: "맛있는 음식점을 선택하고 사람들을 모아보세요",
                                icon: "checkmark.circle.fill",
                                color: .green,
                                isSelected: selectedType == .fixed
                            ) {
                                selectedType = .fixed
                                selectedCandidates = []
                            }
                            
                            TypeSelectionCard(
                                type: .roulette,
                                title: "투표로 함께 결정하기",
                                subtitle: "여러 후보 중 투표로 공정하게 선택해보세요",
                                icon: "shuffle",
                                color: AppConfig.primaryColor,
                                isSelected: selectedType == .roulette
                            ) {
                                selectedType = .roulette
                                selectedRestaurant = nil
                            }
                        }
                    }
                    
                    // Date and Time Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text("일시 선택")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppConfig.primaryColor)
                                DatePicker("날짜", selection: $selectedDate, displayedComponents: .date)
                                    .datePickerStyle(CompactDatePickerStyle())
                            }
                            .padding()
                            .background(AppConfig.lightPink)
                            .cornerRadius(12)
                            
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(AppConfig.primaryColor)
                                DatePicker("시간", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(CompactDatePickerStyle())
                            }
                            .padding()
                            .background(AppConfig.lightPink)
                            .cornerRadius(12)
                        }
                    }
                    
                    // Restaurant Selection
                    VStack(alignment: .leading, spacing: 16) {
                        Text(selectedType == .fixed ? "음식점 선택" : "후보 음식점 선택")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if selectedType == .fixed {
                            fixedRestaurantSection
                        } else {
                            rouletteCandidatesSection
                        }
                    }
                    
                    // Warning Message
                    if !supabase.canCreateMeeting {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("모임 생성 제한")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                            }
                            
                            Text("이미 참여 중이거나 호스팅 중인 모임이 있어 새로운 모임을 만들 수 없습니다.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Error Message
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(AppConfig.primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("만들기") {
                        createMeeting()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(canCreateMeeting ? AppConfig.primaryColor : Color.gray)
                    .cornerRadius(20)
                    .disabled(!canCreateMeeting || isLoading)
                }
            }
        }
        .task {
            await loadRestaurants()
        }
        .sheet(isPresented: $showRestaurantPicker) {
            RestaurantPickerView(
                restaurants: restaurants,
                selectedRestaurants: selectedType == .fixed ? 
                    (selectedRestaurant.map { Set([$0]) } ?? []) : 
                    selectedCandidates,
                allowMultipleSelection: selectedType == .roulette
            ) { selection in
                if selectedType == .fixed {
                    selectedRestaurant = selection.first
                } else {
                    selectedCandidates = selection
                }
                showRestaurantPicker = false
            }
        }
    }
    
    private var fixedRestaurantSection: some View {
        Button {
            showRestaurantPicker = true
        } label: {
            HStack {
                Image(systemName: "fork.knife")
                    .foregroundColor(AppConfig.primaryColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedRestaurant?.name ?? "음식점을 선택하세요")
                        .font(.subheadline)
                        .foregroundColor(selectedRestaurant == nil ? .secondary : .primary)
                    
                    if let category = selectedRestaurant?.category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(AppConfig.lightPink)
            .cornerRadius(12)
        }
    }
    
    private var rouletteCandidatesSection: some View {
        VStack(spacing: 12) {
            Button {
                showRestaurantPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundColor(AppConfig.primaryColor)
                    
                    Text("후보 음식점 추가하기")
                        .font(.subheadline)
                        .foregroundColor(AppConfig.primaryColor)
                    
                    Spacer()
                    
                    if !selectedCandidates.isEmpty {
                        Text("\(selectedCandidates.count)개")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppConfig.primaryColor)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(AppConfig.lightPink)
                .cornerRadius(12)
            }
            
            if !selectedCandidates.isEmpty {
                LazyVStack(spacing: 8) {
                    ForEach(Array(selectedCandidates), id: \.id) { restaurant in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(restaurant.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if let category = restaurant.category {
                                    Text(category)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button {
                                selectedCandidates.remove(restaurant)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        switch selectedType {
        case .fixed:
            return selectedRestaurant != nil
        case .roulette:
            return selectedCandidates.count >= 2
        }
    }
    
    private var canCreateMeeting: Bool {
        return isFormValid && supabase.canCreateMeeting
    }
    
    private func loadRestaurants() async {
        do {
            let fetchedRestaurants = try await supabase.fetchRestaurants()
            await MainActor.run {
                self.restaurants = fetchedRestaurants
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "음식점 목록을 불러올 수 없습니다."
            }
        }
    }
    
    private func createMeeting() {
        guard let userId = supabase.currentUser?.id else { 
            errorMessage = "로그인이 필요합니다."
            return 
        }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                // Calculate week
                let calendar = Calendar.current
                let week = calendar.component(.weekOfYear, from: selectedDate)
                
                // Create meeting using Supabase
                let _ = try await supabase.createMeeting(
                    date: selectedDate,
                    time: selectedTime,
                    week: week,
                    type: selectedType,
                    selectedRestaurantId: selectedType == .fixed ? selectedRestaurant?.id : nil
                )
                
                // Add candidates for roulette meetings
                if selectedType == .roulette && !selectedCandidates.isEmpty {
                    // TODO: Add candidates to meeting_candidates table
                    // This would need a new API call
                }
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

struct TypeSelectionCard: View {
    let type: MeetingType
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? color : .gray)
                    .font(.title3)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RestaurantPickerView: View {
    let restaurants: [Restaurant]
    let selectedRestaurants: Set<Restaurant>
    let allowMultipleSelection: Bool
    let onSelectionChanged: (Set<Restaurant>) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<Restaurant>
    @State private var searchText = ""
    
    init(restaurants: [Restaurant], selectedRestaurants: Set<Restaurant>, allowMultipleSelection: Bool, onSelectionChanged: @escaping (Set<Restaurant>) -> Void) {
        self.restaurants = restaurants
        self.selectedRestaurants = selectedRestaurants
        self.allowMultipleSelection = allowMultipleSelection
        self.onSelectionChanged = onSelectionChanged
        self._selection = State(initialValue: selectedRestaurants)
    }
    
    var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty {
            return restaurants
        } else {
            return restaurants.filter { restaurant in
                restaurant.name.localizedCaseInsensitiveContains(searchText) ||
                (restaurant.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredRestaurants) { restaurant in
                    RestaurantPickerRow(
                        restaurant: restaurant,
                        isSelected: selection.contains(restaurant)
                    ) {
                        toggleSelection(restaurant)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "음식점 검색")
            .navigationTitle(allowMultipleSelection ? "후보 선택" : "음식점 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                    .foregroundColor(AppConfig.primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        onSelectionChanged(selection)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selection.isEmpty ? Color.gray : AppConfig.primaryColor)
                    .cornerRadius(20)
                    .disabled(selection.isEmpty)
                }
            }
        }
    }
    
    private func toggleSelection(_ restaurant: Restaurant) {
        if allowMultipleSelection {
            if selection.contains(restaurant) {
                selection.remove(restaurant)
            } else {
                selection.insert(restaurant)
            }
        } else {
            selection = [restaurant]
        }
    }
}

struct RestaurantPickerRow: View {
    let restaurant: Restaurant
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let category = restaurant.category {
                        Text(category)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let description = restaurant.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? AppConfig.primaryColor : .gray)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CreateMeetingView()
}