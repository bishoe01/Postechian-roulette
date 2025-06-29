import SwiftUI

struct RestaurantListView: View {
    @EnvironmentObject private var supabase: SupabaseService
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
            let fetchedRestaurants = try await supabase.fetchRestaurants()
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