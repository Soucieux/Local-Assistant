import Carbon.HIToolbox
import Foundation

/// Delivers the registered Carbon hotkey on the application's main event loop.
private let quickCallEventHandler: EventHandlerUPP = { _, _, userData in
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let serviceAddress = UInt(bitPattern: userData)
    MainActor.assumeIsolated {
        guard let servicePointer = UnsafeRawPointer(bitPattern: serviceAddress) else {
            return
        }
        let service = Unmanaged<GlobalShortcutService>
            .fromOpaque(servicePointer)
            .takeUnretainedValue()
        service.handleQuickCall()
    }
    return noErr
}

/// Registers one system-wide shortcut while the normal application process is running.
@MainActor
final class GlobalShortcutService {
    private let action: @MainActor () -> Void
    private var eventHandlerReference: EventHandlerRef?
    private var hotKeyReference: EventHotKeyRef?

    /// Creates a quick-call registration owner.
    /// - Parameter action: Main-actor action invoked by the registered shortcut.
    internal init(action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    /// Registers the fixed quick-call combination with the macOS application event target.
    /// - Returns: `true` when both the event handler and hotkey were registered.
    internal func register() -> Bool {
        guard eventHandlerReference == nil, hotKeyReference == nil else { return true }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var installedHandler: EventHandlerRef?
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            quickCallEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &installedHandler
        )
        guard handlerStatus == noErr, let installedHandler else { return false }
        eventHandlerReference = installedHandler

        let hotKeyIdentifier = EventHotKeyID(
            signature: ShortcutConstants.signature,
            id: ShortcutConstants.identifier
        )
        var registeredHotKey: EventHotKeyRef?
        let hotKeyStatus = RegisterEventHotKey(
            ShortcutConstants.keyCode,
            ShortcutConstants.modifiers,
            hotKeyIdentifier,
            GetApplicationEventTarget(),
            0,
            &registeredHotKey
        )
        guard hotKeyStatus == noErr, let registeredHotKey else {
            RemoveEventHandler(installedHandler)
            eventHandlerReference = nil
            return false
        }
        hotKeyReference = registeredHotKey
        return true
    }

    /// Removes the in-process quick-call registration.
    internal func unregister() {
        if let hotKeyReference { UnregisterEventHotKey(hotKeyReference) }
        if let eventHandlerReference { RemoveEventHandler(eventHandlerReference) }
        hotKeyReference = nil
        eventHandlerReference = nil
    }

    /// Invokes the application-owned main-actor quick-call action.
    fileprivate func handleQuickCall() {
        action()
    }
}
