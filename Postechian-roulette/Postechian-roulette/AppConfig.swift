import Foundation

enum AppConfig {
    static let supabaseURL = URL(string: "https://ywuojdghqyozoiaaglbn.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3dW9qZGdocXlvem9pYWFnbGJuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzUzOTI4NzQsImV4cCI6MjA1MDk2ODg3NH0.QfbR_ELGLxJy0JRJ4DQYgNVSTxGNT-FDXFiLZT4nS4g" // Replace with actual anon key
    
    // Profile icons available in the app
    static let profileIcons = ["👤", "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯", "🦁"]
}