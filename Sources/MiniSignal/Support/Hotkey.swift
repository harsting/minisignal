import AppKit
import Carbon.HIToolbox

/// Globaler Kurzbefehl über Carbon — braucht keine Bedienungshilfen-Rechte.
/// Lässt sich jederzeit neu belegen oder ganz abschalten.
final class HotkeyManager {

    private static var action: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(action: @escaping () -> Void) {
        HotkeyManager.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ -> OSStatus in
            DispatchQueue.main.async { HotkeyManager.action?() }
            return noErr
        }, 1, &eventType, nil, &handlerRef)

        apply()
    }

    /// Übernimmt die aktuelle Belegung aus den Einstellungen.
    /// Gibt false zurück, wenn die Kombination nicht registriert werden konnte —
    /// meist, weil sie schon von macOS oder einer anderen App belegt ist.
    @discardableResult
    func apply() -> Bool {
        unregister()
        guard Settings.shared.hotkeyEnabled else { return true }

        let identifier = EventHotKeyID(signature: OSType(0x4D53_4E4C), id: 1)  // 'MSNL'
        let status = RegisterEventHotKey(Settings.shared.hotkeyKeyCode,
                                         Settings.shared.hotkeyModifiers,
                                         identifier,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)

        if status == noErr {
            NSLog("MiniSignal: Kurzbefehl \(Settings.shared.hotkeyDisplay) registriert")
            return true
        }
        NSLog("MiniSignal: Kurzbefehl \(Settings.shared.hotkeyDisplay) abgelehnt (Status \(status))")
        hotKeyRef = nil
        return false
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    // MARK: - Umrechnung zwischen AppKit und Carbon

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// Lesbare Form wie "⌃⌥Leertaste" — wird zusammen mit der Belegung gesichert.
    static func describe(keyCode: UInt16, flags: NSEvent.ModifierFlags,
                         characters: String?) -> String {
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option)  { text += "⌥" }
        if flags.contains(.shift)   { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        return text + keyName(keyCode: keyCode, characters: characters)
    }

    private static func keyName(keyCode: UInt16, characters: String?) -> String {
        switch Int(keyCode) {
        case kVK_Space:        return "Leertaste"
        case kVK_Return:       return "Return"
        case kVK_Tab:          return "Tab"
        case kVK_Escape:       return "Esc"
        case kVK_Delete:       return "Rückschritt"
        case kVK_LeftArrow:    return "←"
        case kVK_RightArrow:   return "→"
        case kVK_UpArrow:      return "↑"
        case kVK_DownArrow:    return "↓"
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            let text = (characters ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "Taste \(keyCode)" : text.uppercased()
        }
    }
}
