import AppKit
import Carbon.HIToolbox

/// Globaler Tastenkürzel-Griff über Carbon — braucht keine Bedienungshilfen-Rechte.
final class Hotkey {

    private static var action: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// ⌃⌥Space
    static let defaultKeyCode = UInt32(kVK_Space)
    static let defaultModifiers = UInt32(controlKey) | UInt32(optionKey)

    init(keyCode: UInt32 = Hotkey.defaultKeyCode,
         modifiers: UInt32 = Hotkey.defaultModifiers,
         action: @escaping () -> Void) {
        Hotkey.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            DispatchQueue.main.async { Hotkey.action?() }
            return noErr
        }, 1, &eventType, nil, &handlerRef)

        let identifier = EventHotKeyID(signature: OSType(0x4D53_4E4C), id: 1)  // 'MSNL'
        RegisterEventHotKey(keyCode, modifiers, identifier, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
