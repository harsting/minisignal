import AppKit

/// Wie sich ein Bote über den Bildschirm bewegt.
enum MotionStyle {
    case crawl      // gemächlich, leichtes Wippen
    case slime      // wie crawl, aber mit Schleimspur
    case glide      // gleichmäßig, ganz leichtes Auf und Ab
    case zigzag     // Wellenflug mit Flügelschlag
    case bounce     // hüpfend, schnell
    case sidestep   // seitwärts, ruckelig
    case waddle     // watschelnd, kippt bei jedem Schritt
    case hop        // echte Sprungbögen über den Boden
    case float      // steigt langsam auf und driftet dabei
}

/// Wo die Nachricht am Boten hängt.
enum BannerStyle {
    case bubbleAbove    // Sprechblase über dem Tier
    case onBack         // Schild direkt auf dem Rücken/Panzer
    case towed          // Schleppbanner hinter Flugzeug/Hubschrauber
    case slung          // hängt an einer Schnur darunter
}

/// Ein Bote ist reine Beschreibung — die Animation baut daraus die Layer.
struct Carrier {
    let id: String
    let art: CarrierArt
    let label: String
    let duration: CFTimeInterval
    let spriteSize: CGFloat
    let motion: MotionStyle
    let banner: BannerStyle
    /// Bewegungsrichtung über den Bildschirm.
    let travelsRight: Bool
    /// true, wenn das Sprite gespiegelt werden muss, damit es in Laufrichtung schaut.
    /// Bei den Emoji-Boten stimmt stattdessen `travelsRight` mit der Blickrichtung
    /// des jeweiligen Apple-Emojis überein — die meisten schauen nach links,
    /// 🐌 und 🐕 nach rechts, 🦋 🎈 sind symmetrisch.
    let mirrored: Bool
    /// Höhe der Laufbahn, 0 = unterer Bildschirmrand, 1 = oberer.
    let lane: CGFloat

    var emoji: String? {
        if case .emoji(let e) = art { return e }
        return nil
    }
}

/// Das Aussehen eines Boten: v1 nutzt Emoji, später können hier Bilddateien stehen.
enum CarrierArt {
    case emoji(String)
    case image(name: String)
}

enum Carriers {

    // MARK: - Am Boden

    static let turtle = Carrier(
        id: "turtle", art: .emoji("🐢"), label: "Schildkröte",
        duration: 14, spriteSize: 96, motion: .crawl, banner: .onBack,
        travelsRight: false, mirrored: false, lane: 0.06
    )

    static let snail = Carrier(
        id: "snail", art: .emoji("🐌"), label: "Schnecke",
        duration: 16, spriteSize: 88, motion: .slime, banner: .onBack,
        travelsRight: true, mirrored: false, lane: 0.04
    )

    static let cat = Carrier(
        id: "cat", art: .emoji("🐈"), label: "Katze",
        duration: 10, spriteSize: 90, motion: .crawl, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.06
    )

    static let dog = Carrier(
        id: "dog", art: .emoji("🐕"), label: "Hund",
        duration: 7, spriteSize: 92, motion: .bounce, banner: .bubbleAbove,
        travelsRight: true, mirrored: false, lane: 0.07
    )

    static let rabbit = Carrier(
        id: "rabbit", art: .emoji("🐇"), label: "Hase",
        duration: 6.5, spriteSize: 84, motion: .hop, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.05
    )

    static let squirrel = Carrier(
        id: "squirrel", art: .emoji("🐿️"), label: "Eichhörnchen",
        duration: 8, spriteSize: 78, motion: .hop, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.05
    )

    static let hedgehog = Carrier(
        id: "hedgehog", art: .emoji("🦔"), label: "Igel",
        duration: 9.5, spriteSize: 76, motion: .bounce, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.04
    )

    static let penguin = Carrier(
        id: "penguin", art: .emoji("🐧"), label: "Pinguin",
        duration: 11, spriteSize: 86, motion: .waddle, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.05
    )

    static let duck = Carrier(
        id: "duck", art: .emoji("🦆"), label: "Ente",
        duration: 10, spriteSize: 82, motion: .waddle, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.05
    )

    static let crab = Carrier(
        id: "crab", art: .emoji("🦀"), label: "Krabbe",
        duration: 11, spriteSize: 84, motion: .sidestep, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.09
    )

    static let dino = Carrier(
        id: "dino", art: .emoji("🦕"), label: "Dino",
        duration: 12, spriteSize: 112, motion: .bounce, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.06
    )

    static let sloth = Carrier(
        id: "sloth", art: .emoji("🦥"), label: "Faultier",
        duration: 20, spriteSize: 100, motion: .crawl, banner: .onBack,
        travelsRight: false, mirrored: false, lane: 0.55
    )

    // MARK: - In der Luft

    static let bird = Carrier(
        id: "bird", art: .emoji("🐦"), label: "Vogel",
        duration: 8, spriteSize: 72, motion: .zigzag, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.62
    )

    static let bee = Carrier(
        id: "bee", art: .emoji("🐝"), label: "Biene",
        duration: 7, spriteSize: 62, motion: .zigzag, banner: .bubbleAbove,
        travelsRight: false, mirrored: false, lane: 0.38
    )

    static let butterfly = Carrier(
        id: "butterfly", art: .emoji("🦋"), label: "Schmetterling",
        duration: 12, spriteSize: 74, motion: .zigzag, banner: .bubbleAbove,
        travelsRight: true, mirrored: false, lane: 0.48
    )

    static let balloon = Carrier(
        id: "balloon", art: .emoji("🎈"), label: "Luftballon",
        duration: 13, spriteSize: 82, motion: .float, banner: .slung,
        travelsRight: true, mirrored: false, lane: 0.20
    )

    static let helicopter = Carrier(
        id: "helicopter", art: .emoji("🚁"), label: "Hubschrauber",
        duration: 11, spriteSize: 86, motion: .glide, banner: .towed,
        travelsRight: false, mirrored: false, lane: 0.74
    )

    static let plane = Carrier(
        id: "plane", art: .emoji("✈️"), label: "Flugzeug",
        duration: 9, spriteSize: 84, motion: .glide, banner: .towed,
        travelsRight: true, mirrored: false, lane: 0.92
    )

    static let all: [Carrier] = [
        turtle, snail, cat, dog, rabbit, squirrel,
        hedgehog, penguin, duck, crab, dino, sloth,
        bird, bee, butterfly, balloon, helicopter, plane
    ]

    static func random() -> Carrier { all.randomElement() ?? turtle }

    static func with(id: String?) -> Carrier {
        guard let id else { return random() }
        return all.first { $0.id == id } ?? random()
    }
}
