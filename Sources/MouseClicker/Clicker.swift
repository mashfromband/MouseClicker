import AppKit
import ApplicationServices
import SwiftUI

enum TriggerButton: Int, CaseIterable, Identifiable {
    case middle = 2
    case back = 3
    case forward = 4
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .middle: return "中ボタン (ホイール押し込み)"
        case .back: return "サイドボタン (戻る)"
        case .forward: return "サイドボタン (進む)"
        }
    }
}

enum ClickButton: String, CaseIterable, Identifiable {
    case left = "左"
    case right = "右"
    var id: String { rawValue }
}

@MainActor
final class Clicker: ObservableObject {
    // Settings
    @Published var count = 100
    @Published var infinite = false
    @Published var intervalMs = 100
    @Published var startDelay = 3
    @Published var button: ClickButton = .left
    @Published var useFixedPoint = false
    @Published var fixedPoint: CGPoint?
    /// Mouse button that toggles start/stop from anywhere (e.g. inside a fullscreen game).
    @Published var triggerEnabled = true
    @Published var trigger: TriggerButton = .middle

    // State
    @Published private(set) var running = false
    @Published private(set) var done = 0
    @Published private(set) var status = "待機中"
    @Published private(set) var trusted = AXIsProcessTrusted()

    private var task: Task<Void, Never>?
    private var monitors: [Any] = []

    init() {
        // Global hotkeys: F6 = start/stop, Esc = stop (works while another app is focused).
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            Task { @MainActor in self?.handleKey(e.keyCode) }
        }) { monitors.append(m) }
        // Mouse trigger: press once to start, press again to stop. No delay, so it works in-game.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .otherMouseDown, handler: { [weak self] e in
            let n = e.buttonNumber
            Task { @MainActor in self?.handleTrigger(n) }
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .otherMouseDown, handler: { [weak self] e in
            let n = e.buttonNumber
            Task { @MainActor in self?.handleTrigger(n) }
            return e
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            Task { @MainActor in self?.handleKey(e.keyCode) }
            return e
        }) { monitors.append(m) }
    }

    private func handleTrigger(_ buttonNumber: Int) {
        guard triggerEnabled, buttonNumber == trigger.rawValue else { return }
        if running { stop() } else { start(skipDelay: true, promptForPermission: false) }
    }

    private func handleKey(_ code: UInt16) {
        switch code {
        case 97: toggle()                  // F6
        case 53: if running { stop() }     // Esc
        default: break
        }
    }

    func requestPermission() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(opts)
    }

    func toggle() { running ? stop() : start() }

    func start(skipDelay: Bool = false, promptForPermission: Bool = true) {
        trusted = AXIsProcessTrusted()
        guard trusted else {
            if promptForPermission { requestPermission() }
            status = "アクセシビリティ権限が必要です (ウィンドウの「許可する」から設定)"
            return
        }
        guard !running else { return }
        running = true
        done = 0
        let total = infinite ? Int.max : max(count, 1)
        let interval = UInt64(max(intervalMs, 1)) * 1_000_000
        let delay = skipDelay ? 0 : max(startDelay, 0)

        task = Task { [weak self] in
            guard let self else { return }
            for s in stride(from: delay, to: 0, by: -1) {
                self.status = "\(s) 秒後に開始…"
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { return }
            }
            self.status = "実行中 (トリガー / F6 / Esc で停止)"
            while self.done < total && !Task.isCancelled {
                self.click()
                self.done += 1
                try? await Task.sleep(nanoseconds: interval)
            }
            if !Task.isCancelled {
                self.running = false
                self.status = "完了 (\(self.done) 回)"
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        running = false
        status = "停止 (\(done) 回)"
    }

    /// Records the cursor position after a short countdown.
    func captureFixedPoint() {
        Task {
            for s in stride(from: 3, to: 0, by: -1) {
                status = "\(s) 秒後にマウス位置を記録…"
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            fixedPoint = CGEvent(source: nil)?.location
            useFixedPoint = fixedPoint != nil
            status = "位置を記録しました"
        }
    }

    private func click() {
        guard let pos = useFixedPoint ? fixedPoint : CGEvent(source: nil)?.location else { return }
        let (down, up, btn): (CGEventType, CGEventType, CGMouseButton) = button == .left
            ? (.leftMouseDown, .leftMouseUp, .left)
            : (.rightMouseDown, .rightMouseUp, .right)
        CGEvent(mouseEventSource: nil, mouseType: down, mouseCursorPosition: pos, mouseButton: btn)?.post(tap: .cghidEventTap)
        CGEvent(mouseEventSource: nil, mouseType: up, mouseCursorPosition: pos, mouseButton: btn)?.post(tap: .cghidEventTap)
    }
}
