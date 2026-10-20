import Cocoa

@main struct HeadlessViewWrapperTests {
    static func main() {
        let container = NSView()
        let other = NSView()
        container.addSubview(other)
        let web = NSView()
        let wrapper = HeadlessViewWrapper()

        wrapper.attach(web, to: container)
        precondition(container.subviews.count == 2 && web.superview?.superview === container)

        // A repeated prepare replaces the old wrapper instead of stacking another.
        wrapper.attach(web, to: container)
        precondition(container.subviews.count == 2 && web.superview?.superview === container)

        // The move to a visible view: the web view leaves, the empty wrapper must not stay.
        let visible = NSView()
        visible.addSubview(web)
        wrapper.remove()
        precondition(container.subviews.count == 1 && container.subviews[0] === other)
        precondition(web.superview === visible)

        // Plain dispose, repeated, leaves only the unrelated view.
        wrapper.attach(web, to: container)
        wrapper.remove()
        wrapper.remove()
        precondition(container.subviews.count == 1 && container.subviews[0] === other)

        // No window yet: nothing to add to or remove, and no crash.
        wrapper.attach(NSView(), to: nil)
        wrapper.remove()
    }
}
