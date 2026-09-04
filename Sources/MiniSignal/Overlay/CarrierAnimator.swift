import AppKit
import QuartzCore

/// Baut aus einem `Carrier` die Layer und lässt sie einmal über die Bühne laufen.
final class CarrierAnimator {

    private let carrier: Carrier
    private let text: String
    private let sender: String
    private var trailTimer: Timer?
    private weak var stage: CALayer?
    private var unit: CALayer?

    init(carrier: Carrier, text: String, sender: String) {
        self.carrier = carrier
        self.text = text
        self.sender = sender
    }

    /// Startet den Auftritt. `completion` läuft, wenn der Bote den Bildschirm verlassen hat.
    func run(on stage: CALayer, in rect: CGRect, laneOffset: CGFloat = 0,
             completion: @escaping () -> Void) {
        self.stage = stage
        let bounds = rect
        let scale = NSScreen.main?.backingScaleFactor ?? 2

        var spriteImage = Artwork.sprite(for: carrier.art, size: carrier.spriteSize)
        if carrier.mirrored { spriteImage = CarrierAnimator.mirrored(spriteImage) }
        let bannerImage = Artwork.banner(text: text, sender: sender, style: carrier.banner)

        let unit = CALayer()
        unit.bounds = .zero
        unit.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        unit.masksToBounds = false
        unit.opacity = 0
        self.unit = unit

        let sprite = CALayer()
        sprite.contents = spriteImage
        sprite.contentsScale = scale
        sprite.bounds = CGRect(origin: .zero, size: spriteImage.size)
        sprite.position = .zero

        let banner = CALayer()
        banner.contents = bannerImage
        banner.contentsScale = scale
        banner.bounds = CGRect(origin: .zero, size: bannerImage.size)

        let spriteSize = spriteImage.size
        let bannerSize = bannerImage.size

        switch carrier.banner {
        case .bubbleAbove:
            // Die Blase so verschieben, dass ihre Spitze über dem Tier steht.
            banner.position = CGPoint(x: bannerSize.width * 0.5 - Artwork.bubbleTailInset,
                                      y: spriteSize.height * 0.5 + bannerSize.height * 0.5 - 6)
            unit.addSublayer(banner)
            unit.addSublayer(sprite)

        case .onBack:
            banner.position = CGPoint(x: 0,
                                      y: spriteSize.height * 0.28 + bannerSize.height * 0.5)
            unit.addSublayer(banner)
            unit.addSublayer(sprite)

        case .slung:
            let cordLength: CGFloat = 34
            banner.anchorPoint = CGPoint(x: 0.5, y: 1)
            let hangY = -(spriteSize.height * 0.42 + cordLength)
            banner.position = CGPoint(x: 0, y: hangY)

            let cord = CAShapeLayer()
            let cordPath = CGMutablePath()
            cordPath.move(to: CGPoint(x: 0, y: -spriteSize.height * 0.36))
            cordPath.addLine(to: CGPoint(x: 0, y: hangY))
            cord.path = cordPath
            cord.strokeColor = NSColor(calibratedWhite: 0.25, alpha: 0.7).cgColor
            cord.lineWidth = 2
            cord.fillColor = nil

            unit.addSublayer(cord)
            unit.addSublayer(banner)
            unit.addSublayer(sprite)

            let swing = CABasicAnimation(keyPath: "transform.rotation.z")
            swing.fromValue = -0.035
            swing.toValue = 0.035
            swing.duration = 2.4
            swing.autoreverses = true
            swing.repeatCount = .infinity
            swing.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            banner.add(swing, forKey: "swing")

        case .towed:
            let ropeLength: CGFloat = 46
            let towardTail: CGFloat = carrier.travelsRight ? -1 : 1
            banner.anchorPoint = CGPoint(x: carrier.travelsRight ? 1 : 0, y: 0.5)
            let anchorX = towardTail * (spriteSize.width * 0.42 + ropeLength)
            banner.position = CGPoint(x: anchorX, y: -6)

            let rope = CAShapeLayer()
            let ropePath = CGMutablePath()
            ropePath.move(to: CGPoint(x: towardTail * spriteSize.width * 0.34, y: 0))
            ropePath.addLine(to: CGPoint(x: anchorX, y: -6))
            rope.path = ropePath
            rope.strokeColor = NSColor(calibratedWhite: 0.25, alpha: 0.75).cgColor
            rope.lineWidth = 2
            rope.fillColor = nil

            unit.addSublayer(rope)
            unit.addSublayer(banner)
            unit.addSublayer(sprite)

            let wave = CABasicAnimation(keyPath: "transform.rotation.z")
            wave.fromValue = -0.022
            wave.toValue = 0.022
            wave.duration = 1.7
            wave.autoreverses = true
            wave.repeatCount = .infinity
            wave.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            banner.add(wave, forKey: "wave")
        }

        addMotionFlourish(to: sprite)

        let laneY = bounds.minY + 80 + carrier.lane * max(bounds.height - 210, 100) + laneOffset
        let margin = max(spriteSize.width, bannerSize.width) + 260
        let startX = carrier.travelsRight ? bounds.minX - margin : bounds.maxX + margin
        let endX = carrier.travelsRight ? bounds.maxX + margin : bounds.minX - margin

        unit.position = CGPoint(x: startX, y: laneY)
        stage.addSublayer(unit)

        let travel = CAKeyframeAnimation(keyPath: "position")
        travel.path = makePath(from: startX, to: endX, y: laneY, rise: bounds.height * 0.4)
        travel.duration = carrier.duration
        travel.calculationMode = .paced
        travel.timingFunction = CAMediaTimingFunction(name: .linear)
        travel.fillMode = .forwards
        unit.position = CGPoint(x: endX, y: laneY)
        unit.add(travel, forKey: "travel")

        let fadeIn = CABasicAnimation(keyPath: "opacity")
        fadeIn.fromValue = 0
        fadeIn.toValue = 1
        fadeIn.duration = 0.6
        unit.opacity = 1
        unit.add(fadeIn, forKey: "fadeIn")

        if carrier.motion == .slime { startTrail(on: stage, unit: unit, laneY: laneY) }

        DispatchQueue.main.asyncAfter(deadline: .now() + carrier.duration - 0.7) { [weak unit] in
            guard let unit else { return }
            let fadeOut = CABasicAnimation(keyPath: "opacity")
            fadeOut.fromValue = 1
            fadeOut.toValue = 0
            fadeOut.duration = 0.7
            unit.opacity = 0
            unit.add(fadeOut, forKey: "fadeOut")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + carrier.duration + 0.1) { [weak self] in
            self?.finish()
            completion()
        }
    }

    func finish() {
        trailTimer?.invalidate()
        trailTimer = nil
        unit?.removeAllAnimations()
        unit?.removeFromSuperlayer()
        unit = nil
    }

    // MARK: - Bewegung

    private func makePath(from startX: CGFloat, to endX: CGFloat,
                          y: CGFloat, rise: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: startX, y: y))

        switch carrier.motion {
        case .zigzag:
            let steps = 6
            let dx = (endX - startX) / CGFloat(steps)
            var current = CGPoint(x: startX, y: y)
            for step in 0..<steps {
                let up = step % 2 == 0
                let next = CGPoint(x: startX + dx * CGFloat(step + 1), y: y + (up ? 68 : -68))
                path.addCurve(
                    to: next,
                    control1: CGPoint(x: current.x + dx * 0.45, y: current.y + (up ? 52 : -52)),
                    control2: CGPoint(x: next.x - dx * 0.45, y: next.y)
                )
                current = next
            }

        case .hop:
            let hops = 8
            let dx = (endX - startX) / CGFloat(hops)
            var current = CGPoint(x: startX, y: y)
            for hop in 0..<hops {
                let next = CGPoint(x: startX + dx * CGFloat(hop + 1), y: y)
                path.addQuadCurve(to: next,
                                  control: CGPoint(x: current.x + dx * 0.5, y: y + 200))
                current = next
            }

        case .float:
            let steps = 5
            let dx = (endX - startX) / CGFloat(steps)
            var current = CGPoint(x: startX, y: y)
            for step in 0..<steps {
                let fraction = CGFloat(step + 1) / CGFloat(steps)
                let next = CGPoint(x: startX + dx * CGFloat(step + 1), y: y + rise * fraction)
                let drift: CGFloat = step % 2 == 0 ? 34 : -14
                path.addCurve(
                    to: next,
                    control1: CGPoint(x: current.x + dx * 0.4, y: current.y + drift),
                    control2: CGPoint(x: next.x - dx * 0.4, y: next.y - drift)
                )
                current = next
            }

        default:
            path.addLine(to: CGPoint(x: endX, y: y))
        }

        return path
    }

    private func addMotionFlourish(to sprite: CALayer) {
        let animation: CABasicAnimation
        switch carrier.motion {
        case .crawl:
            animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = -0.05
            animation.toValue = 0.05
            animation.duration = 1.3
        case .slime:
            animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = -0.03
            animation.toValue = 0.03
            animation.duration = 2.2
        case .glide:
            animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = -6
            animation.toValue = 6
            animation.duration = 2.6
        case .zigzag:
            animation = CABasicAnimation(keyPath: "transform.scale.y")
            animation.fromValue = 1.0
            animation.toValue = 0.78
            animation.duration = 0.26
        case .bounce:
            animation = CABasicAnimation(keyPath: "transform.translation.y")
            animation.fromValue = 0
            animation.toValue = 26
            animation.duration = 0.38
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        case .sidestep:
            animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = -7
            animation.toValue = 7
            animation.duration = 0.3
        case .waddle:
            animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = -0.11
            animation.toValue = 0.11
            animation.duration = 0.5
        case .hop:
            animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = -0.07
            animation.toValue = 0.07
            animation.duration = 0.55
        case .float:
            animation = CABasicAnimation(keyPath: "transform.rotation.z")
            animation.fromValue = -0.05
            animation.toValue = 0.05
            animation.duration = 3.0
        }
        animation.autoreverses = true
        animation.repeatCount = .infinity
        if animation.timingFunction == nil {
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        }
        sprite.add(animation, forKey: "flourish")
    }

    /// Schleimspur der Schnecke: kleine Tropfen, die langsam verblassen.
    private func startTrail(on stage: CALayer, unit: CALayer, laneY: CGFloat) {
        trailTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak stage, weak unit] _ in
            guard let stage, let unit,
                  let x = unit.presentation()?.position.x else { return }

            let drop = CALayer()
            let size: CGFloat = CGFloat.random(in: 7...12)
            drop.bounds = CGRect(x: 0, y: 0, width: size, height: size * 0.55)
            drop.position = CGPoint(x: x, y: laneY - 24 + CGFloat.random(in: -3...3))
            drop.cornerRadius = size * 0.275
            drop.backgroundColor = NSColor(calibratedRed: 0.72, green: 0.92, blue: 0.78, alpha: 0.55).cgColor
            stage.insertSublayer(drop, at: 0)

            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 3.5
            drop.opacity = 0
            drop.add(fade, forKey: "fade")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { drop.removeFromSuperlayer() }
        }
    }

    private static func mirrored(_ image: NSImage) -> NSImage {
        let size = image.size
        return NSImage(size: size, flipped: false) { rect in
            let transform = NSAffineTransform()
            transform.translateX(by: size.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
            image.draw(in: NSRect(origin: .zero, size: size))
            return true
        }
    }
}
