import Foundation

// CRITICAL: Run this script ONCE to clear corrupted UserLearning data
// This will reset the learning database that's preventing keyword detection

let defaults = UserDefaults.standard

// Clear the corrupted learning data
defaults.removeObject(forKey: "voice_learning_preferences")
defaults.synchronize()

print("✅ UserLearning data CLEARED!")
print("🔄 Now restart the app - keywords will work correctly")
print("")
print("📝 What this fixes:")
print("   - Removes 'Añade Mercadona' and other corrupted entries")
print("   - Allows keyword matching to run properly")
print("   - Categories will be detected from GlobalKeywords")
