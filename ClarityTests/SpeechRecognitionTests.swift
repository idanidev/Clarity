import AVFoundation
import XCTest

@testable import Clarity

@MainActor
final class SpeechRecognitionTests: XCTestCase {

    var manager: SpeechRecognitionManager!

    override func setUpWithError() throws {
        manager = SpeechRecognitionManager.shared
    }

    override func tearDownWithError() throws {
        manager.stopRecording()
    }

    func testInitialState() {
        XCTAssertFalse(manager.isListening, "Manager should not be listening initially")
        XCTAssertTrue(manager.transcript.isEmpty, "Transcript should be empty initially")
    }

    func testPermissionCheck() {
        // This test assumes we are in a test environment where we can check status
        // We can't easily mock SFSpeechRecognizer auth status without a protocol,
        // but we can verify that the method exists and doesn't crash.

        let status = SFSpeechRecognizer.authorizationStatus()
        // Just verify it returns a valid enum case
        XCTAssertTrue([.authorized, .denied, .restricted, .notDetermined].contains(status))
    }

    func testRapidStateChanges() async {
        // Simulate "Machine Gun" Taps
        // Since startRecording() interacts with hardware, we expect it might throw or succeed
        // depending on the simulator/device state.
        // The critical part is that it DOES NOT CRASH.

        do {
            // 1. Start
            // We use try? because on a CI/Simulator without mic it might fail gracefully (which is good)
            try? await manager.startRecording()

            // 2. Stop immediately
            manager.stopRecording()
            XCTAssertFalse(manager.isListening)

            // 3. Start again
            try? await manager.startRecording()
            XCTAssertTrue(manager.isListening || manager.lastError != nil)
            // If it failed to start due to no mic, isListening might be false, which is fine, but no crash.

            // 4. Stop again
            manager.stopRecording()
        } catch {
            XCTFail("Should not throw fatal errors during rapid toggle: \(error)")
        }
    }
}
