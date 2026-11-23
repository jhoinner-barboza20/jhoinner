import Cocoa
import QuartzCore
// Cronómetro de Seraf Clips: solo aparece mientras hay una marca (⌃⌥M) y se oculta al cortar (⌃⌥C).
let home = NSHomeDirectory()
let markPath = home + "/Desktop/Clips/.marca"
let vodPath = home + "/Desktop/Clips/.vodmarca"
let namePath = home + "/Desktop/Clips/.nombre"
let pink = NSColor(red: 1.0, green: 0.16, blue: 0.55, alpha: 1)
let purple = NSColor(red: 0.42, green: 0.12, blue: 0.75, alpha: 1)
let cyan = NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1)
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var card: NSView!
    var gradient: CAGradientLayer!
    var dot: NSView!
    var caption: NSTextField!
    var time: NSTextField!
    var visible = false
    func makeLabel(_ size: CGFloat, _ weight: NSFont.Weight, mono: Bool) -> NSTextField {
        let l = NSTextField(labelWithString: "")
        l.font = mono ? NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight) : NSFont.systemFont(ofSize: size, weight: weight)
        l.textColor = .white
        l.lineBreakMode = .byTruncatingTail
        return l
    }
    func applicationDidFinishLaunching(_ n: Notification) {
        let w: CGFloat = 260, h: CGFloat = 72
        let s = NSScreen.main!.visibleFrame
        window = NSWindow(contentRect: NSRect(x: s.maxX - w - 24, y: s.maxY - h - 24, width: w, height: h), styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        card = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
        card.wantsLayer = true
        card.layer?.cornerRadius = 20
        card.layer?.masksToBounds = true
        card.layer?.borderWidth = 2
        card.layer?.borderColor = cyan.cgColor
        gradient = CAGradientLayer()
        gradient.frame = card.bounds
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.colors = [pink.cgColor, purple.cgColor]
        card.layer?.addSublayer(gradient)
        dot = NSView(frame: NSRect(x: 20, y: (h - 16) / 2, width: 16, height: 16))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 8
        dot.layer?.backgroundColor = NSColor.white.cgColor
        card.addSubview(dot)
        caption = makeLabel(11, .heavy, mono: false)
        caption.frame = NSRect(x: 48, y: 42, width: w - 60, height: 16)
        caption.textColor = NSColor(white: 1, alpha: 0.9)
        card.addSubview(caption)
        time = makeLabel(30, .bold, mono: true)
        time.frame = NSRect(x: 46, y: 6, width: w - 58, height: 38)
        card.addSubview(time)
        window.contentView = card
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in self.tick() }
        tick()
    }
    func show() {
        visible = true
        let a = CABasicAnimation(keyPath: "opacity")
        a.fromValue = 1.0
        a.toValue = 0.25
        a.duration = 0.6
        a.autoreverses = true
        a.repeatCount = .infinity
        dot.layer?.add(a, forKey: "pulse")
        window.alphaValue = 0
        window.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.window.animator().alphaValue = 1
        }
    }
    func hide() {
        visible = false
        dot.layer?.removeAnimation(forKey: "pulse")
        window.orderOut(nil)
    }
    func tick() {
        let now = Date().timeIntervalSince1970
        var start: Double? = nil
        var vod = false
        if let t = try? String(contentsOfFile: markPath, encoding: .utf8),
           let v = Double(t.trimmingCharacters(in: .whitespacesAndNewlines)) {
            start = v
        } else if let attrs = try? FileManager.default.attributesOfItem(atPath: vodPath),
                  let m = attrs[.modificationDate] as? Date {
            start = m.timeIntervalSince1970 - 20
            vod = true
        }
        guard let st = start, now - st < 1800 else {
            if visible { hide() }
            return
        }
        let raw = (try? String(contentsOfFile: namePath, encoding: .utf8)) ?? ""
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let tag = vod ? "  ·  VOD" : (name.isEmpty ? "" : "  ·  " + name)
        let e = max(0, Int(now - st))
        time.stringValue = String(format: "%02d:%02d", e / 60, e % 60)
        caption.stringValue = "✂︎ MARCANDO CLIP" + tag
        if !visible { show() }
    }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
