import AppKit
import Combine
import CoreAudio
import Darwin
import DynamicIslandCore
@preconcurrency import CoreFoundation

enum SystemHUDKind: Equatable {
    case volume
    case brightness
    case bluetooth(BluetoothBannerPayload)
}

struct SystemHUDState: Equatable {
    let kind: SystemHUDKind
    let level: Double
    let muted: Bool
}

@MainActor
final class SystemHUDService: ObservableObject {
    @Published private(set) var hud: SystemHUDState?

    private var hideWorkItem: DispatchWorkItem?
    private var brightnessTimer: DispatchSourceTimer?
    private var suppressionTimer: DispatchSourceTimer?
    private var lastBrightness: Float = -1
    private var pausedOSDHelper = false

    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private var displayServicesGetBrightness: GetBrightnessFn?
    private var displayServicesSetBrightness: SetBrightnessFn?

    private var defaultDeviceListenerInstalled = false
    private var currentDeviceID: AudioDeviceID = 0

    private var eventTap: CFMachPort?
    private var tapRunLoopSource: CFRunLoopSource?
    private var tapRunLoop: CFRunLoop?
    private var tapThread: Thread?

    private var launchObserver: NSObjectProtocol?

    private var tapRetryTimer: DispatchSourceTimer?

    init() {
        // Defer AX prompt — calling synchronously during init can deadlock on some macOS versions.
        DispatchQueue.main.async { [weak self] in self?.requestAccessibilityIfNeeded() }
        setupBrightnessPolling()
        setupVolumeListener()
        attemptInstallMediaKeyTap()
    }

    private func requestAccessibilityIfNeeded() {
        let key = "AXTrustedCheckOptionPrompt" as CFString
        let opts = [key: kCFBooleanTrue as Any] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(opts)
        NSLog("[HUD] AX trusted: \(trusted)")
    }

    private func attemptInstallMediaKeyTap() {
        installMediaKeyTap()
        if eventTap == nil {
            // Permission likely missing or pending — retry every 2s.
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + 2.0, repeating: 2.0)
            timer.setEventHandler { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if self.eventTap != nil {
                        self.tapRetryTimer?.cancel()
                        self.tapRetryTimer = nil
                        return
                    }
                    if AXIsProcessTrusted() {
                        self.installMediaKeyTap()
                        if self.eventTap != nil {
                            self.tapRetryTimer?.cancel()
                            self.tapRetryTimer = nil
                        }
                    }
                }
            }
            timer.activate()
            tapRetryTimer = timer
        }
    }

    deinit {
        hideWorkItem?.cancel()
        brightnessTimer?.cancel()
        suppressionTimer?.cancel()
        tapRetryTimer?.cancel()
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let src = tapRunLoopSource, let rl = tapRunLoop {
            CFRunLoopRemoveSource(rl, src, .commonModes)
            CFRunLoopStop(rl)
        }
        if let obs = launchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
    }

    // MARK: - Media key interception (Accessibility-based)

    private func installMediaKeyTap() {
        let mask: CGEventMask = 1 << 14 // NSEvent.EventType.systemDefined
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        // Use session-level tap (not HID-level) so a busy main thread never blocks system-wide input.
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: SystemHUDService.tapCallback,
            userInfo: refcon
        ) else {
            NSLog("[HUD] CGEventTap install FAILED — Accessibility permission not granted")
            return
        }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        // Run on a dedicated thread — keeps tap processing off main run loop entirely.
        let sema = DispatchSemaphore(value: 0)
        var capturedRL: CFRunLoop?
        let thread = Thread {
            capturedRL = CFRunLoopGetCurrent()
            CFRunLoopAddSource(CFRunLoopGetCurrent()!, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            sema.signal()
            CFRunLoopRun()
        }
        thread.name = "com.notchly.eventtap"
        thread.qualityOfService = .userInteractive
        thread.start()
        sema.wait()

        tapThread = thread
        tapRunLoop = capturedRL
        tapRunLoopSource = source
        eventTap = tap
        NSLog("[HUD] CGEventTap installed on dedicated thread")
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
        // Re-enable tap if disabled (timeout / user interrupt).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let refcon {
                let svc = Unmanaged<SystemHUDService>.fromOpaque(refcon).takeUnretainedValue()
                if let tap = svc.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            }
            return nil
        }
        guard type.rawValue == 14 else { return Unmanaged.passUnretained(event) }
        guard let nsEvent = NSEvent(cgEvent: event), nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }
        let data1 = nsEvent.data1
        let keyCode = (data1 & 0xFFFF0000) >> 16
        let keyFlags = data1 & 0x0000FFFF
        let keyState = ((keyFlags & 0xFF00) >> 8) == 0x0A // 0x0A = key down
        NSLog("[HUD] mediakey kc=\(keyCode) down=\(keyState)")
        guard keyState else { return nil } // consume key-up too
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let svc = Unmanaged<SystemHUDService>.fromOpaque(refcon).takeUnretainedValue()
        let consume: Bool
        switch keyCode {
        case 0: // NX_KEYTYPE_SOUND_UP
            DispatchQueue.main.async { svc.adjustVolume(delta: 1.0/16.0) }
            consume = true
        case 1: // NX_KEYTYPE_SOUND_DOWN
            DispatchQueue.main.async { svc.adjustVolume(delta: -1.0/16.0) }
            consume = true
        case 7: // NX_KEYTYPE_MUTE
            DispatchQueue.main.async { svc.toggleMute() }
            consume = true
        case 2: // NX_KEYTYPE_BRIGHTNESS_UP
            DispatchQueue.main.async { svc.adjustBrightness(delta: 1.0/16.0) }
            consume = true
        case 3: // NX_KEYTYPE_BRIGHTNESS_DOWN
            DispatchQueue.main.async { svc.adjustBrightness(delta: -1.0/16.0) }
            consume = true
        default:
            consume = false
        }
        return consume ? nil : Unmanaged.passUnretained(event)
    }

    private func adjustVolume(delta: Float) {
        let current = currentVolume()
        let next = max(0, min(1, current + delta))
        setVolume(next)
        let muted = currentMuted()
        show(SystemHUDState(kind: .volume, level: Double(next), muted: muted))
    }

    private func toggleMute() {
        let muted = !currentMuted()
        setMute(muted)
        show(SystemHUDState(kind: .volume, level: Double(currentVolume()), muted: muted))
    }

    private func setVolume(_ value: Float) {
        guard currentDeviceID != 0 else { return }
        var v = value
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        let size = UInt32(MemoryLayout<Float>.size)
        if AudioObjectHasProperty(currentDeviceID, &addr) {
            AudioObjectSetPropertyData(currentDeviceID, &addr, 0, nil, size, &v)
            return
        }
        addr.mElement = 1
        AudioObjectSetPropertyData(currentDeviceID, &addr, 0, nil, size, &v)
        addr.mElement = 2
        AudioObjectSetPropertyData(currentDeviceID, &addr, 0, nil, size, &v)
    }

    private func setMute(_ value: Bool) {
        guard currentDeviceID != 0 else { return }
        var v: UInt32 = value ? 1 : 0
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(currentDeviceID, &addr) else { return }
        let size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectSetPropertyData(currentDeviceID, &addr, 0, nil, size, &v)
    }

    private func adjustBrightness(delta: Float) {
        guard let getFn = displayServicesGetBrightness,
              let setFn = displayServicesSetBrightness else { return }
        var current: Float = 0
        _ = getFn(CGMainDisplayID(), &current)
        let next = max(0, min(1, current + delta))
        _ = setFn(CGMainDisplayID(), next)
        lastBrightness = next
        show(SystemHUDState(kind: .brightness, level: Double(next), muted: false))
    }

    // MARK: - Brightness

    private func setupBrightnessPolling() {
        let path = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
        guard let handle = dlopen(path, RTLD_NOW) else { return }
        if let sym = dlsym(handle, "DisplayServicesGetBrightness") {
            displayServicesGetBrightness = unsafeBitCast(sym, to: GetBrightnessFn.self)
        }
        if let sym = dlsym(handle, "DisplayServicesSetBrightness") {
            displayServicesSetBrightness = unsafeBitCast(sym, to: SetBrightnessFn.self)
        }
        var initial: Float = 0
        _ = displayServicesGetBrightness?(CGMainDisplayID(), &initial)
        lastBrightness = initial
    }

    // MARK: - Volume

    private func setupVolumeListener() {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            DispatchQueue.main
        ) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.installListenerOnCurrentDevice() }
        }
        installListenerOnCurrentDevice()
    }

    private func installListenerOnCurrentDevice() {
        currentDeviceID = currentDefaultOutputDevice()
        guard currentDeviceID != 0 else { return }
        var volAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(currentDeviceID, &volAddr, DispatchQueue.main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.handleVolumeChange() }
        }
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectAddPropertyListenerBlock(currentDeviceID, &muteAddr, DispatchQueue.main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.handleVolumeChange() }
        }
    }

    private func currentDefaultOutputDevice() -> AudioDeviceID {
        var deviceID: AudioDeviceID = 0
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &addr,
            0, nil,
            &size, &deviceID
        )
        return deviceID
    }

    private func handleVolumeChange() {
        let level = currentVolume()
        let muted = currentMuted()
        show(SystemHUDState(kind: .volume, level: Double(level), muted: muted))
    }

    private func currentVolume() -> Float {
        guard currentDeviceID != 0 else { return 0 }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<Float>.size)
        if AudioObjectHasProperty(currentDeviceID, &addr) {
            var v: Float = 0
            AudioObjectGetPropertyData(currentDeviceID, &addr, 0, nil, &size, &v)
            return v
        }
        // Per-channel fallback.
        var l: Float = 0, r: Float = 0
        addr.mElement = 1
        AudioObjectGetPropertyData(currentDeviceID, &addr, 0, nil, &size, &l)
        addr.mElement = 2
        AudioObjectGetPropertyData(currentDeviceID, &addr, 0, nil, &size, &r)
        return (l + r) / 2
    }

    private func currentMuted() -> Bool {
        guard currentDeviceID != 0 else { return false }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(currentDeviceID, &addr) else { return false }
        var v: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(currentDeviceID, &addr, 0, nil, &size, &v)
        return v != 0
    }

    // MARK: - HUD show / auto-hide

    func showBluetoothBanner(_ payload: BluetoothBannerPayload) {
        let state = SystemHUDState(
            kind: .bluetooth(payload),
            level: 0,
            muted: false
        )
        show(state)
    }

    private func show(_ state: SystemHUDState) {
        hud = state
        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hud = nil
            self?.hideWorkItem = nil
        }
        hideWorkItem = work
        let delay: TimeInterval
        switch state.kind {
        case .bluetooth: delay = 3.0
        case .volume, .brightness: delay = 1.5
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}
