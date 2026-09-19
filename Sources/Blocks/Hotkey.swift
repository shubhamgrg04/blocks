import AppKit
import Carbon

@MainActor
final class Hotkey {
    enum Action: UInt32, CaseIterable { case capture = 1, start = 2, extend = 3 }
    private var references: [Action: EventHotKeyRef] = [:]
    private var handler: EventHandlerRef?
    private var handlerStatus: OSStatus = noErr
    private let perform: (Action) -> Void
    init(perform: @escaping (Action) -> Void) {
        self.perform = perform
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        handlerStatus = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }
            // One handler serves every shortcut; the event names which one fired.
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, let action = Action(rawValue: id.id) else { return OSStatus(eventNotHandledErr) }
            MainActor.assumeIsolated { Unmanaged<Hotkey>.fromOpaque(userData).takeUnretainedValue().perform(action) }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ action: Action, code: UInt32, modifiers: UInt32) -> String? {
        guard handlerStatus == noErr else { return "Could not install the shortcut handler (\(handlerStatus)). Relaunch Blocks." }
        // Carbon only reports a clash with one of Blocks's own shortcuts; a combination already
        // claimed by macOS or another app registers cleanly here and then never fires.
        if let reference = references[action] { UnregisterEventHotKey(reference); references[action] = nil }
        var next: EventHotKeyRef?
        let result = RegisterEventHotKey(code, modifiers, EventHotKeyID(signature: 0x426C6B73, id: action.rawValue),
                                         GetApplicationEventTarget(), 0, &next)
        guard result == noErr else {
            return result == OSStatus(eventHotKeyExistsErr)
                ? "Another Blocks shortcut already uses this combination. Choose another."
                : "This shortcut is unavailable (\(result)). Choose another combination."
        }
        references[action] = next
        return nil
    }
}
