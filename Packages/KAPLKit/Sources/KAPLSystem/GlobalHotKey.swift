import Carbon.HIToolbox
import os

/// A system-wide keyboard shortcut, delivered whichever app is in front.
///
/// Uses Carbon's `RegisterEventHotKey`, which, unlike a global event
/// monitor, needs no Accessibility permission. The shortcut only ever locks:
/// unlocking always takes authentication.
@MainActor
public final class GlobalHotKey {
    /// ⌘Esc.
    public static let lockShortcut = (keyCode: UInt32(kVK_Escape), modifiers: UInt32(cmdKey))

    private let action: @MainActor () -> Void
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?

    private static let log = Logger(subsystem: "io.github.salemjanabil.KAPL", category: "hotkey")

    /// Meant to live as long as the app: the Carbon handler points back to it.
    public init(keyCode: UInt32, modifiers: UInt32, action: @escaping @MainActor () -> Void) {
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                // Carbon delivers hot key events on the main thread.
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { hotKey.action() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )

        let id = EventHotKeyID(signature: OSType(0x4B41_504C), id: 1) // "KAPL"
        let hotKeyStatus = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKey)

        if handlerStatus != noErr || hotKeyStatus != noErr {
            // Most likely another app already owns the shortcut. The menu
            // still works, so this is not fatal.
            Self.log.error("hot key not registered: handler \(handlerStatus), hot key \(hotKeyStatus)")
        }
    }
}
