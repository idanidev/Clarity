// Temporary script to clear corrupted UserLearning data
// Run this ONCE to reset the learning data
import Foundation

let defaults = UserDefaults.standard
defaults.removeObject(forKey: "voice_learning_preferences")
defaults.synchronize()

print("✅ UserLearning data cleared!")
print("🔄 Restart the app to use fresh keyword matching")
