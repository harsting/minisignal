# MiniSignal

Eine kleine Nachrichten-App für genau zwei Macs im selben WLAN.
Wer etwas schreibt, schickt kein Notification-Fenster los, sondern ein Tier: die
Nachricht wird über den Desktop des anderen getragen — von einer Schildkröte, einem
hüpfenden Hasen, einem watschelnden Pinguin, einem Luftballon mit Zettel an der
Schnur oder einem Flugzeug mit Schleppbanner. 18 Boten stehen zur Auswahl, 🎲 würfelt
jedes Mal neu.

Dazu gibt es einen SOS-Knopf: der lässt beim anderen sofort den ganzen Bildschirm
rot blinken.

Kein Server, kein Account, kein Internet. Die beiden Macs reden direkt miteinander.

---

## Installation (auf **jedem** der beiden Macs einmal)

Vorausgesetzt sind nur die Command Line Tools (`xcode-select --install`), kein Xcode.

```bash
./build.sh
open MiniSignal.app
```

Beim ersten Start öffnet sich die Einrichtung:

- **Name** — wie du beim anderen angezeigt wirst.
- **Paar-Code** — muss auf beiden Macs **exakt gleich** sein. Er verschlüsselt die
  Nachrichten und sorgt dafür, dass niemand sonst im WLAN mitlesen oder euch
  etwas schicken kann. Denkt euch etwas aus, das nur ihr kennt.
- Optional: Töne und Start bei der Anmeldung.

Danach fragt macOS einmal, ob MiniSignal **nach Geräten im lokalen Netzwerk suchen**
darf. Das muss erlaubt werden — sonst finden sich die beiden Macs nie.
Nachträglich änderbar unter *Systemeinstellungen → Datenschutz & Sicherheit →
Lokales Netzwerk*.

Damit die App nach dem Neustart wieder da ist: in der Einrichtung
„Beim Anmelden starten" ankreuzen.

## Bedienung

| | |
|---|---|
| 💌 in der Menüleiste | Fenster zum Schreiben öffnen |
| ⌃⌥Leertaste | dasselbe, ohne Maus |
| Emoji-Reihe | Boten wählen; 🎲 würfelt jedes Mal neu |
| ⏎ | losschicken |
| 🚨 SOS | rot blinkendes Overlay beim anderen |
| Rechtsklick aufs Icon | Einstellungen, letzte Nachrichten, Testnachricht an mich, Beenden |

Die Statuszeile oben im Fenster zeigt, ob der andere Mac gerade erreichbar ist.
Ist er das nicht (zugeklappt, anderes WLAN), kommt sofort eine ehrliche Fehlermeldung —
Nachrichten werden **nicht** aufgehoben und später zugestellt.

Nachdem ein Bote durchgelaufen ist, taucht unten rechts kurz ein Antwortfeld auf.
Wer nicht antwortet, wird es nach ein paar Sekunden wieder los.

Beim SOS blinkt der Bildschirm des anderen so lange rot, bis er klickt oder ESC
drückt — dann steht bei dir „✓ … hat das SOS gesehen". Nach 20 Sekunden hört es
von selbst auf.

## Die Boten

| Am Boden | | In der Luft | |
|---|---|---|---|
| 🐢 Schildkröte | kriecht, Schild auf dem Panzer | 🐦 Vogel | Wellenflug |
| 🐌 Schnecke | am langsamsten, mit Schleimspur | 🐝 Biene | schneller Zickzack |
| 🐈 Katze | schlendert | 🦋 Schmetterling | gemächliches Flattern |
| 🐕 Hund | rennt und hüpft | 🎈 Luftballon | steigt auf, Zettel an der Schnur |
| 🐇 Hase | echte Sprungbögen | 🚁 Hubschrauber | mit Schleppbanner |
| 🐿️ Eichhörnchen | kleine schnelle Sprünge | ✈️ Flugzeug | mit Schleppbanner |
| 🦔 Igel | trippelt | | |
| 🐧 Pinguin | watschelt | | |
| 🦆 Ente | watschelt | | |
| 🦀 Krabbe | seitwärts | | |
| 🦕 Dino | schwere Schritte | | |
| 🦥 Faultier | hängt am Ast, 20 Sekunden | | |

## Technik in drei Sätzen

Jede Instanz meldet sich per Bonjour als `_minisignal._tcp` im lokalen Netz an und
sucht gleichzeitig nach der Gegenstelle. Nachrichten gehen über eine direkte
TCP-Verbindung, jede einzelne mit AES-GCM verschlüsselt; der Schlüssel wird per
HKDF aus dem gemeinsamen Paar-Code abgeleitet, und Sendungen, die sich nicht
entschlüsseln lassen oder älter als zwei Minuten sind, werden verworfen.
Die Overlays sind randlose, mausdurchlässige Fenster über allen Spaces, deren
Animation komplett in Core Animation läuft — der Desktop bleibt bedienbar und der
Akku unbeeindruckt.

## Beide Rollen auf einem Mac testen

```bash
open -n --env MINISIGNAL_SUITE=a --env MINISIGNAL_NAME=Anna \
        --env MINISIGNAL_CODE=testcode MiniSignal.app
open -n --env MINISIGNAL_SUITE=b --env MINISIGNAL_NAME=Marvin \
        --env MINISIGNAL_CODE=testcode MiniSignal.app
```

`MINISIGNAL_SUITE` trennt die Einstellungen, sodass zwei unabhängige Instanzen
nebeneinander laufen. Weitere Test-Schalter: `MINISIGNAL_DEMO=<boten-id|sos>`
zeigt einen Auftritt lokal, `MINISIGNAL_MUTE=1` schaltet Töne ab.

## Neue Tiere

`Sources/MiniSignal/Overlay/Carriers.swift` — ein Bote sind zehn Zeilen: Emoji,
Dauer, Bewegungsstil, wo die Nachricht hängt, auf welcher Höhe er läuft.
Statt `.emoji("🐢")` geht auch `.image(name: "fuchs.png")`; solche Dateien kommen
nach `Resources/Carriers/` und landen beim nächsten `./build.sh` im Bundle.

**Achtung Blickrichtung:** Apple-Emoji schauen nicht alle in dieselbe Richtung —
🐢 und 🐦 nach links, 🐌 und 🐕 nach rechts. `travelsRight` muss dazu passen, sonst
läuft das Tier rückwärts. Zum Nachsehen:

```bash
MINISIGNAL_SPRITESHEET=/tmp/boten.png ./MiniSignal.app/Contents/MacOS/MiniSignal
open /tmp/boten.png
```

Das rendert alle Boten nebeneinander mit ihrer eingestellten Laufrichtung.
Für eigene Bilddateien gibt es alternativ `mirrored: true`, das spiegelt das Sprite.

## Wenn es klemmt

- **„Niemand gefunden", obwohl beide Macs laufen** — meistens die Freigabe für das
  lokale Netzwerk. Prüfen unter *Systemeinstellungen → Datenschutz & Sicherheit →
  Lokales Netzwerk*. Nach einem Neubau der App kann die Frage erneut kommen, weil
  macOS die Freigabe an die Signatur bindet.
- **Gastnetz oder Hotel-WLAN** — viele Router trennen die Geräte voneinander
  („Client Isolation"). Dann geht es nur im eigenen Heimnetz.
- **„MiniSignal kann nicht geöffnet werden"** — passiert, wenn die fertige App vom
  anderen Mac kopiert wurde. Am saubersten ist, `./build.sh` einmal auf jedem Mac
  laufen zu lassen. Alternativ: `xattr -dr com.apple.quarantine MiniSignal.app`.
