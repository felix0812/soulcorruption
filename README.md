# SoulCorruption

Ein dunkles Seelen-System für **Minecraft 26.3** (Fabric).
Stiehl Seelen, höre sie flüstern – und lass dich von ihnen korrumpieren.

## Voraussetzungen

| Komponente   | Version          |
|--------------|------------------|
| Minecraft    | 26.3             |
| Fabric Loader| ≥ 0.19.5         |
| Fabric API   | 0.164.0+26.3     |
| Java         | **25** (Minimum für Minecraft 26.x) |

Bauen: `./gradlew build` → `build/libs/soulcorruption-<version>.jar`
Testen: `./gradlew runClient` bzw. `./gradlew runServer`

> Seit Minecraft 26.1 ist das Spiel unobfuskiert – es gibt keine Yarn-/Mojmap-Mappings mehr,
> der Code nutzt direkt die offiziellen Mojang-Namen. Loom-Plugin-ID: `net.fabricmc.fabric-loom`.

## Features

### Seelen-Orb (`soulcorruption:soul`)
- Eigenes Item mit animierter, leuchtender Orb-Textur.
- Data Component `soulcorruption:soul_data`: Opfer-Name, letzte Worte, Zeitstempel,
  Persönlichkeit (rachsüchtig, trauernd, spöttisch, wahnsinnig, flehend), Spieler/Kreatur, Ernter.
- Tooltip zeigt die komplette "Persönlichkeit" der Seele.
- **Rechtsklick**: Seele absorbieren (+1 eigene Seele).
- **Schleichen + Rechtsklick**: Geist des Opfers als temporären Diener beschwören.
- Stapelbar oder einzeln (Config).

### Seelen-System
- Jeder Spieler startet mit `startingSouls` Seelen.
- **PvP-Kill**: Opfer verliert eine Seele, der Killer erhält sie als Orb (mit den letzten Chat-Worten des Opfers).
- **Starke Mobs** (Liste oder ≥ X Max-HP) hinterlassen mit einer Chance eine Seele.
- **Tod**: Verlust von `soulsLostOnDeath` Seelen – sie droppen als Orbs oder werden vernichtet.
- **0 Seelen**: "Hohl"-Zustand mit starken Debuffs **oder** temporärer Bann (`zeroSoulMode`).

### Flüstern
Mitgeführte Seelen flüstern ihrem Besitzer im Chat oder in der Actionbar – passend zu ihrer Persönlichkeit.
Je mehr Korruption, desto häufiger; ab Stufe 3 werden sie aggressiv.

### Korruption
`Korruption = absorbierte Fremdseelen (über dem Startwert) + Seelen-Orbs im Inventar`

| Stufe     | Ab | Buffs                         | Debuffs / Effekte |
|-----------|----|-------------------------------|-------------------|
| Rein      | 0  | –                             | – |
| Befleckt  | 3  | Speed I                       | Hunger-Pulse, leichte Vignette, Partikel |
| Verdorben | 8  | Speed I, Stärke I             | Glowing, Dunkelheit-Pulse, erste Halluzinationen |
| Besessen  | 15 | Stärke II, Resistenz I, Nachtsicht | Übelkeit/Dunkelheit, Fake-Chat, Fake-Mobs, Teleports |
| Verloren  | 25 | Stärke III, Speed II, Resistenz II | Wither-/Blindheit-Pulse, starke Halluzinationen |

Alle Stufen, Schwellen und Effekte sind frei konfigurierbar.

Clientseitig: pulsierende dunkle Vignette, Seelen-Partikel, Fake-Mobs, die verschwinden,
sobald man sie ansieht, Phantom-Geräusche und rotes Flackern.
Ohne Client-Mod funktioniert der Server trotzdem (nur ohne die Client-Effekte).

### Befehle

| Befehl | Beschreibung |
|--------|--------------|
| `/soul` oder `/soul balance [spieler]` | Seelen, Korruption und Stufe anzeigen |
| `/soul top` | Rangliste |
| `/soul withdraw <anzahl>` | Eigene Seelen als Orbs entnehmen (1 bleibt immer) |
| `/soul shop` | Seelen-Shop (Truhen-GUI) öffnen |
| `/soul admin set\|add <spieler> <anzahl>` | Seelen setzen/ändern (OP) |
| `/soul admin give <spieler> [opfer]` | Seelen-Orb erzeugen (OP) |
| `/soul admin unban <name>` | Seelen-Bann aufheben (OP) |
| `/soul admin reload` | Config neu laden (OP) |

## Config

`config/soulcorruption.json` wird beim ersten Start erzeugt. Alles ist einstellbar: Startseelen,
Caps, Chancen, Mob-Liste, Todesverhalten, Bann-Dauer, Flüster-Texte je Persönlichkeit,
Intervalle, Korruptionsstufen mit Effekten (per Registry-ID, z.B. `minecraft:strength`),
Halluzinations-Chancen, Fake-Chat-Texte, Minion-Werte und Shop-Angebote.

Spielerdaten liegen pro Welt in `<welt>/soulcorruption/souls.json`.

## Projektstruktur

```
src/main/java/com/soulcorruption/
  SoulCorruption.java        ModInitializer + Event-Verdrahtung
  config/                    JSON-Config (Stufen, Shop, Effekte)
  component/                 SoulData (Data Component) + Persönlichkeiten
  item/                      Seelen-Orb
  data/                      Persistente Spielerdaten
  soul/                      Kernlogik (stehlen, sterben, absorbieren)
  corruption/                Korruption, Flüstern, Halluzinationen
  minion/                    Geister-Diener
  shop/                      Truhen-Shop
  command/                   /soul
  network/                   Server→Client-Pakete
src/client/java/com/soulcorruption/client/
                             Overlay, Partikel, Fake-Mobs, Tooltip
```
