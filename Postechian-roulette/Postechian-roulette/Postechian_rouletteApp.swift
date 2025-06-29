import SwiftUI

@main
struct PostechianRouletteApp: App {
    @StateObject private var supabaseService = SupabaseService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(supabaseService)
        }
    }
}
