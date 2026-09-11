import SpriteKit
import SwiftUI

/// The yard. Every being gets a sprite that wanders, stops to think, bumps
/// into the others, and says a word or two when it does something. Pure
/// animation: nothing here changes the town, it only shows it.
final class YardScene: SKScene {

    var onTap: ((UUID) -> Void)?

    private final class Sprite {
        let node = SKNode()
        let face = SKLabelNode()
        let name = SKLabelNode()
        let badge = SKLabelNode()
        let bars = SKLabelNode()
        let bubble = SKNode()
        let bubbleText = SKLabelNode()
        let bubbleBox = SKShapeNode()
        var x = 0.5, y = 0.5, vx = 0.0, vy = 0.0
        var bob = 0.0
        var restUntil: TimeInterval = 0
        var bubbleUntil: TimeInterval = 0
        var jailed = false
    }

    private var sprites: [UUID: Sprite] = [:]
    private var last: TimeInterval = 0
    private var dice = Dice(seed: 7)
    private var built = false

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(UI.grass)
        scaleMode = .resizeFill
        if !built { buildGround() }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard size.width > 1 else { return }
        childNode(withName: "ground")?.removeFromParent()
        buildGround()
    }

    /// Mown stripes and a few flowers. It is a lawn.
    private func buildGround() {
        built = true
        let ground = SKNode()
        ground.name = "ground"
        ground.zPosition = -10
        let stripes = 7
        for i in 0..<stripes where i % 2 == 0 {
            let h = size.height / CGFloat(stripes)
            let s = SKSpriteNode(color: UIColor(UI.grassDark), size: CGSize(width: size.width, height: h))
            s.anchorPoint = .zero
            s.position = CGPoint(x: 0, y: CGFloat(i) * h)
            ground.addChild(s)
        }
        var d = Dice(seed: 3)
        for _ in 0..<9 {
            let f = SKLabelNode(text: d.pick(["🌼", "🌸", "🍄", "🌷", "🪨"]))
            f.fontSize = 14
            f.position = CGPoint(x: CGFloat(d.roll(10, Int(max(11, size.width - 10)))),
                                 y: CGFloat(d.roll(10, Int(max(11, size.height - 10)))))
            f.alpha = 0.85
            ground.addChild(f)
        }
        addChild(ground)
    }

    // MARK: sync with the town

    func apply(_ town: Town) {
        let live = Set(town.beings.map(\.id))
        for (id, s) in sprites where !live.contains(id) {
            s.node.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
            sprites[id] = nil
        }
        for b in town.beings {
            let s = sprites[b.id] ?? make(b)
            s.face.text = b.face
            s.name.text = b.name
            s.name.fontColor = UIColor(hue: CGFloat(b.hue / 360), saturation: 0.75, brightness: 0.35, alpha: 1)
            s.badge.text = b.seat?.badge ?? ""
            s.jailed = b.isJailed(at: town.tick)
            s.bars.isHidden = !s.jailed
            s.node.alpha = s.jailed ? 0.75 : 1
        }
    }

    private func make(_ b: Being) -> Sprite {
        let s = Sprite()
        s.x = Double(dice.roll(8, 92)) / 100
        s.y = Double(dice.roll(15, 85)) / 100
        s.vx = Double(dice.roll(-40, 40)) / 10000
        s.vy = Double(dice.roll(-20, 20)) / 10000
        s.bob = Double(dice.roll(0, 628)) / 100

        s.face.fontSize = 34
        s.face.verticalAlignmentMode = .center
        s.name.fontName = "AvenirNext-Bold"
        s.name.fontSize = 10
        s.name.position = CGPoint(x: 0, y: -30)
        s.badge.fontSize = 16
        s.badge.position = CGPoint(x: 16, y: 16)
        s.bars.text = "🔒"
        s.bars.fontSize = 18
        s.bars.position = CGPoint(x: -16, y: 16)
        s.bars.isHidden = true

        s.bubbleBox.fillColor = UIColor(UI.paper)
        s.bubbleBox.strokeColor = UIColor(UI.ink)
        s.bubbleBox.lineWidth = 1.5
        s.bubbleText.fontName = "AvenirNext-Bold"
        s.bubbleText.fontSize = 11
        s.bubbleText.fontColor = UIColor(UI.ink)
        s.bubbleText.verticalAlignmentMode = .center
        s.bubble.addChild(s.bubbleBox)
        s.bubble.addChild(s.bubbleText)
        s.bubble.position = CGPoint(x: 0, y: 36)
        s.bubble.alpha = 0
        s.bubble.zPosition = 5

        s.node.addChild(s.face)
        s.node.addChild(s.name)
        s.node.addChild(s.badge)
        s.node.addChild(s.bars)
        s.node.addChild(s.bubble)
        s.node.zPosition = 1
        s.node.setScale(0.2)
        s.node.run(.scale(to: 1, duration: 0.35))
        addChild(s.node)
        sprites[b.id] = s
        return s
    }

    /// Somebody did something: a word over their head.
    func show(_ deed: Deed, town: Town) {
        guard let b = town.being(named: deed.actor), let s = sprites[b.id] else { return }
        let text = Words.bark(for: deed.kind, &dice)
        s.bubbleText.text = text
        let w = CGFloat(text.count) * 6.6 + 16
        s.bubbleBox.path = CGPath(roundedRect: CGRect(x: -w / 2, y: -10, width: w, height: 20),
                                  cornerWidth: 6, cornerHeight: 6, transform: nil)
        s.bubble.removeAllActions()
        s.bubble.alpha = 1
        s.bubble.run(.sequence([.wait(forDuration: 1.8), .fadeOut(withDuration: 0.3)]))
        s.node.run(.sequence([.scale(to: 1.18, duration: 0.08), .scale(to: 1, duration: 0.12)]))
        s.restUntil = last + 1.2
        if !deed.target.isEmpty, let t = town.being(named: deed.target), let ts = sprites[t.id] {
            // Walk toward whoever it happened to.
            ts.restUntil = last + 1.0
            s.vx = (ts.x - s.x) * 0.01
            s.vy = (ts.y - s.y) * 0.01
            s.restUntil = 0
        }
    }

    // MARK: animation

    override func update(_ now: TimeInterval) {
        let dt = last == 0 ? 16.0 : min(64, (now - last) * 1000)
        last = now
        let list = Array(sprites.values)

        for s in list {
            s.bob += dt * 0.006
            if s.jailed {
                s.vx = 0; s.vy = 0
            } else if now >= s.restUntil {
                s.x += s.vx * (dt / 16)
                s.y += s.vy * (dt / 16)
                if dice.chance(0.012) {
                    s.vx = Double(dice.roll(-30, 30)) / 10000
                    s.vy = Double(dice.roll(-15, 15)) / 10000
                }
                if dice.chance(0.004) { s.restUntil = now + 0.7 + Double(dice.roll(0, 22)) / 10 }
            }
            if s.x < 0.06 { s.x = 0.06; s.vx = abs(s.vx) }
            if s.x > 0.94 { s.x = 0.94; s.vx = -abs(s.vx) }
            if s.y < 0.12 { s.y = 0.12; s.vy = abs(s.vy) }
            if s.y > 0.86 { s.y = 0.86; s.vy = -abs(s.vy) }
            if s.vx != 0 { s.face.xScale = s.vx > 0 ? 1 : -1 }
        }

        // Bumping into each other is where the personality comes from.
        for i in 0..<list.count {
            for j in (i + 1)..<list.count {
                let a = list[i], b = list[j]
                let dx = a.x - b.x, dy = (a.y - b.y) * 0.5
                if dx * dx + dy * dy < 0.0035 {
                    a.vx = -a.vx; b.vx = -b.vx
                    a.restUntil = now + 0.5; b.restUntil = now + 0.5
                }
            }
        }

        for s in list {
            let hop = sin(s.bob) * 2
            // Further down the yard is nearer the camera, so it draws on top.
            s.node.zPosition = 1 + CGFloat(1 - s.y) * 5
            s.node.position = CGPoint(x: s.x * size.width, y: s.y * size.height + hop)
        }
    }

    // MARK: input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let p = touches.first?.location(in: self) else { return }
        var best: (UUID, CGFloat)?
        for (id, s) in sprites {
            let d = hypot(s.node.position.x - p.x, s.node.position.y - p.y)
            if d < 40, best == nil || d < best!.1 { best = (id, d) }
        }
        if let (id, _) = best { onTap?(id) }
    }
}

/// Keeps one scene alive across SwiftUI body evaluations.
final class YardHolder: ObservableObject {
    let scene = YardScene()
}

struct YardView: View {
    @EnvironmentObject private var model: TownModel
    @StateObject private var holder = YardHolder()
    var onTap: (UUID) -> Void

    var body: some View {
        SpriteView(scene: holder.scene, options: [.ignoresSiblingOrder])
            .onAppear {
                holder.scene.onTap = onTap
                if let t = model.town { holder.scene.apply(t) }
            }
            .onChange(of: model.town) { _, t in
                if let t { holder.scene.apply(t) }
            }
            .onChange(of: model.latest) { _, d in
                if let d, let t = model.town { holder.scene.show(d, town: t) }
            }
            .accessibilityLabel("The yard")
    }
}
