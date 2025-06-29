import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var supabase = SupabaseService.shared
    
    @State private var restaurants: [Restaurant] = []
    @State private var preferences: [UUID: Float] = [:]
    @State private var searchText = ""
    @State private var selectedCategory = "전체"
    @State private var showOnlyRated = false
    @State private var isLoading = true
    
    private let categories = ["전체", "한식", "중식", "일식", "양식", "분식", "치킨", "피자", "햄버거", "면류", "카페"]
    
    private var filteredRestaurants: [Restaurant] {
        var filtered = restaurants
        
        // 검색 필터
        if !searchText.isEmpty {
            filtered = filtered.filter { restaurant in
                restaurant.name.localizedCaseInsensitiveContains(searchText) ||
                (restaurant.category?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // 카테고리 필터
        if selectedCategory != "전체" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        // 평가 여부 필터
        if showOnlyRated {
            filtered = filtered.filter { preferences[$0.id] != nil }
        }
        
        return filtered.sorted { lhs, rhs in
            let lhsRating = preferences[lhs.id]
            let rhsRating = preferences[rhs.id]
            
            // 평가한 것들을 먼저, 그 다음 높은 점수 순
            if lhsRating != nil && rhsRating == nil {
                return true
            } else if lhsRating == nil && rhsRating != nil {
                return false
            } else if let l = lhsRating, let r = rhsRating {
                return l > r
            } else {
                return lhs.name < rhs.name
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filters
                searchAndFilterSection
                
                // Content
                if isLoading {
                    Spacer()
                    ProgressView("음식점 목록을 불러오는 중...")
                    Spacer()
                } else {
                    restaurantGrid
                }
            }
            .navigationTitle("내 선호도")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                    .foregroundColor(AppConfig.primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showOnlyRated.toggle() }) {
                            Label(showOnlyRated ? "전체 보기" : "평가한 것만", 
                                  systemImage: showOnlyRated ? "eye" : "star.fill")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppConfig.primaryColor)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 16) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("음식점 검색...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        CategoryChip(
                            title: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 16)
        .background(Color(.systemGroupedBackground))
    }
    
    private var restaurantGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 16) {
                ForEach(filteredRestaurants) { restaurant in
                    RestaurantPreferenceCard(
                        restaurant: restaurant,
                        rating: preferences[restaurant.id]
                    ) { newRating in
                        updatePreference(for: restaurant, rating: newRating)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private func loadData() async {
        do {
            let fetchedRestaurants = try await supabase.loadSampleData()
            await MainActor.run {
                self.restaurants = fetchedRestaurants
                self.isLoading = false
                
                // Mock preferences for demo
                for restaurant in fetchedRestaurants.prefix(3) {
                    preferences[restaurant.id] = Float.random(in: 3.0...5.0)
                }
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func updatePreference(for restaurant: Restaurant, rating: Float?) {
        preferences[restaurant.id] = rating
        
        // TODO: Save to backend
        Task {
            // await supabase.updatePreference(restaurantId: restaurant.id, rating: rating)
        }
    }
}

struct CategoryChip: View {
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

struct RestaurantPreferenceCard: View {
    let restaurant: Restaurant
    let rating: Float?
    let onRatingChanged: (Float?) -> Void
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Restaurant Image Placeholder
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [AppConfig.secondaryColor.opacity(0.3), AppConfig.lightPink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 120)
                .cornerRadius(12)
                .overlay(
                    VStack {
                        Image(systemName: "fork.knife")
                            .font(.title)
                            .foregroundColor(AppConfig.primaryColor)
                        Text(restaurant.name.prefix(2))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppConfig.primaryColor)
                    }
                )
            
            // Restaurant Info
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let category = restaurant.category {
                    Text(category)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Rating Section
            VStack(spacing: 8) {
                StarRatingView(rating: rating) { newRating in
                    onRatingChanged(newRating)
                }
                
                if let rating = rating {
                    Text(String(format: "%.1f점", rating))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppConfig.primaryColor)
                } else {
                    Text("평가하기")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
        .scaleEffect(isExpanded ? 1.05 : 1.0)
        .animation(.spring(response: 0.3), value: isExpanded)
        .onTapGesture {
            withAnimation {
                isExpanded.toggle()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isExpanded = false
                }
            }
        }
    }
}

struct StarRatingView: View {
    let rating: Float?
    let onRatingChanged: (Float?) -> Void
    
    private let maxRating = 5
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { index in
                Button {
                    let newRating = Float(index)
                    if rating == newRating {
                        onRatingChanged(nil) // Remove rating if same star tapped
                    } else {
                        onRatingChanged(newRating)
                    }
                } label: {
                    Image(systemName: starIcon(for: index))
                        .foregroundColor(starColor(for: index))
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    private func starIcon(for index: Int) -> String {
        guard let rating = rating else { return "star" }
        return Float(index) <= rating ? "star.fill" : "star"
    }
    
    private func starColor(for index: Int) -> Color {
        guard let rating = rating else { return .gray }
        if Float(index) <= rating {
            switch Int(rating) {
            case 1...2:
                return .red
            case 3:
                return .orange
            case 4:
                return .yellow
            case 5:
                return AppConfig.primaryColor
            default:
                return .gray
            }
        }
        return .gray
    }
}

#Preview {
    PreferencesView()
}