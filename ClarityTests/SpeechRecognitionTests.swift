import AVFoundation
import Speech
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
        let status = SFSpeechRecognizer.authorizationStatus()
        XCTAssertTrue(
            [SFSpeechRecognizerAuthorizationStatus.authorized, .denied, .restricted, .notDetermined]
                .contains(status))
    }

    func testRapidStateChanges() async {
        try? await manager.startRecording()
        manager.stopRecording()
        XCTAssertFalse(manager.isListening)

        try? await manager.startRecording()
        manager.stopRecording()
    }
}
