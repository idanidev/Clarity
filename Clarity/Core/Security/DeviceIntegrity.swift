// DeviceIntegrity.swift
// Capa 2 de seguridad — detección de jailbreak y entornos comprometidos.

import Foundation
import MachO

enum DeviceIntegrity {

    struct IntegrityReport: Sendable {
        let jailbreakPaths: Bool
        let sandboxViolation: Bool
        let suspiciousDylibs: Bool
        let debuggerAttached: Bool

        var isCompromised: Bool {
            jailbreakPaths || sandboxViolation || suspiciousDylibs || debuggerAttached
        }

        var summary: String {
            guard isCompromised else { return "Dispositivo íntegro" }
            var reasons: [String] = []
            if jailbreakPaths    { reasons.append("rutas de jailbreak detectadas") }
            if sandboxViolation  { reasons.append("violación de sandbox") }
            if suspiciousDylibs  { reasons.append("librerías sospechosas cargadas") }
            if debuggerAttached  { reasons.append("depurador adjunto") }
            return "Entorno comprometido: \(reasons.joined(separator: ", "))"
        }
    }

    static func check() -> IntegrityReport {
#if targetEnvironment(simulator)
        return IntegrityReport(
            jailbreakPaths: false,
            sandboxViolation: false,
            suspiciousDylibs: false,
            debuggerAttached: false
        )
#else
        return IntegrityReport(
            jailbreakPaths: checkJailbreakPaths(),
            sandboxViolation: checkSandbox(),
            suspiciousDylibs: checkDylibs(),
            debuggerAttached: checkDebugger()
        )
#endif
    }

    // MARK: - Private checks

    private static func checkJailbreakPaths() -> Bool {
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/usr/bin/ssh",
            "/var/lib/cydia",
            "/var/cache/apt",
            "/private/var/stash",
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    private static func checkSandbox() -> Bool {
        do {
            let testPath = "/private/jailbreak_\(UUID().uuidString).tmp"
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true // Wrote outside sandbox — jailbroken
        } catch {
            return false // Expected failure — sandbox intact
        }
    }

    private static func checkDylibs() -> Bool {
        let suspiciousNames = ["MobileSubstrate", "cycript", "SSLKillSwitch", "FridaGadget", "cynject"]
        let count = _dyld_image_count()
        for i in 0..<count {
            guard let rawName = _dyld_get_image_name(i) else { continue }
            let name = String(cString: rawName)
            if suspiciousNames.contains(where: { name.contains($0) }) { return true }
        }
        return false
    }

    private static func checkDebugger() -> Bool {
#if DEBUG
        return false
#else
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, 4, &info, &size, nil, 0)
        return (info.kp_proc.p_flag & P_TRACED) != 0
#endif
    }
}
