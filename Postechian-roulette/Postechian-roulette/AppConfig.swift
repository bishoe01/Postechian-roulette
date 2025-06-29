import Foundation
import SwiftUI

enum AppConfig {
    static let supabaseURL = URL(string: "https://ywuojdghqyozoiaaglbn.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3dW9qZGdocXlvem9pYWFnbGJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzUzOTI4NzQsImV4cCI6MjA1MDk2ODg3NH0.QfbR_ELGLxJy0JRJ4DQYgNVSTxGNT-FDXFiLZT4nS4g" // Replace with actual anon key
    
    // Theme colors
    static let primaryColor = Color(hex: "#B52C5E")
    static let secondaryColor = Color(hex: "#E8A4C2")
    static let lightPink = Color(hex: "#F5E6ED")
    
    // Profile icons available in the app
    static let profileIcons = ["👤", "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁"]
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}