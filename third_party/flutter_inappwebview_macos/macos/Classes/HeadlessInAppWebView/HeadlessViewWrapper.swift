import Cocoa

/// Daily #235: the zero-frame wrapper a headless web view adds to the window's
/// content view. It owns that one wrapper and removes only it, so a repeated
/// attach, a move to a visible view and a plain dispose leave nothing behind
/// and never touch other views.
final class HeadlessViewWrapper {
    private var wrapper: NSView?

    func attach(_ view: NSView, to container: NSView?) {
        remove()
        let wrapper = NSView() // wrapper view with frame zero
        wrapper.addSubview(view, positioned: .below, relativeTo: nil)
        container?.addSubview(wrapper, positioned: .below, relativeTo: nil)
        self.wrapper = wrapper
    }

    func remove() {
        wrapper?.removeFromSuperview()
        wrapper = nil
    }
}
