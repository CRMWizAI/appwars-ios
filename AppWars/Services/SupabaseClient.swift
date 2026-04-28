import Foundation
import Supabase

enum AppConfig {
    static let supabaseURL = URL(string: "https://pibomuscvcvprscqepgz.supabase.co")!
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBpYm9tdXNjdmN2cHJzY3FlcGd6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzczODIwNzYsImV4cCI6MjA5Mjk1ODA3Nn0.MU4GQbZMAsmz97XQzBZAP5i7HkJybtEkJjDVW693SXg"
}

let supabase = SupabaseClient(
    supabaseURL: AppConfig.supabaseURL,
    supabaseKey: AppConfig.supabaseAnonKey
)
