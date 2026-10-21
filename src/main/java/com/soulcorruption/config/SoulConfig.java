package com.soulcorruption.config;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * Komplette Mod-Konfiguration. Wird als {@code config/soulcorruption.json} gespeichert.
 * <p>
 * Alle Felder haben Standardwerte; fehlende Einträge in der Datei werden beim Laden
 * automatisch mit diesen Werten ergänzt.
 */
public final class SoulConfig {

	// ------------------------------------------------------------------ Seelen-Grundsystem

	/** Seelen, mit denen jeder Spieler startet. */
	public int startingSouls = 3;
	/** Obergrenze für die eigene Seelen-Bilanz. */
	public int maxSouls = 200;

	/** Dürfen Seelen-Items gestapelt werden? (Nur identische Seelen stapeln sich.) */
	public boolean soulItemsStackable = false;
	/** Stapelgröße, falls {@link #soulItemsStackable} aktiv ist. */
	public int soulStackSize = 16;

	/** Seelen, die ein Spieler bei jedem Tod verliert. */
	public int soulsLostOnDeath = 1;
	/** true = verlorene Seelen droppen als Item, false = sie werden vernichtet. */
	public boolean dropLostSoulsOnDeath = true;

	/** PvP: Killer erhält eine Seele des Opfers als Item. */
	public boolean pvpSoulSteal = true;

	/** Chance, dass ein "starker" Mob beim Tod eine Seele hinterlässt (0..1). */
	public double mobSoulChance = 0.35;
	/** Mobs mit mindestens so viel Max-HP gelten als stark. */
	public float strongMobMinHealth = 40.0f;
	/** Diese Mobs gelten immer als stark (unabhängig von HP). */
	public List<String> soulMobs = new ArrayList<>(List.of(
			"minecraft:wither", "minecraft:ender_dragon", "minecraft:warden",
			"minecraft:elder_guardian", "minecraft:evoker", "minecraft:ravager",
			"minecraft:piglin_brute", "minecraft:witch", "minecraft:breeze"));

	/** Seele aufnehmen (Rechtsklick) erhöht die eigene Bilanz. */
	public boolean allowAbsorb = true;

	// ------------------------------------------------------------------ 0 Seelen

	public ZeroSoulMode zeroSoulMode = ZeroSoulMode.DEBUFF;
	/** Dauer des temporären Banns in Minuten (Modus TEMP_BAN). */
	public int tempBanMinutes = 30;
	/** Seelen nach Ablauf des Banns. */
	public int soulsAfterBan = 1;
	/** Effekte im "Hohl"-Zustand (Modus DEBUFF). */
	public List<EffectEntry> hollowEffects = new ArrayList<>(List.of(
			new EffectEntry("minecraft:weakness", 1),
			new EffectEntry("minecraft:slowness", 1),
			new EffectEntry("minecraft:mining_fatigue", 1),
			new EffectEntry("minecraft:hunger", 0),
			new EffectEntry("minecraft:darkness", 0)));

	// ------------------------------------------------------------------ Flüstern

	public boolean whispersEnabled = true;
	/** true = Actionbar, false = Chat. */
	public boolean whispersInActionbar = false;
	/** Basisintervall (Sekunden) zwischen zwei Flüstern ohne Korruption. */
	public int whisperBaseIntervalSeconds = 240;
	/** Kürzestes Intervall (Sekunden) bei maximaler Korruption. */
	public int whisperMinIntervalSeconds = 25;
	/** Ab dieser Korruptionsstufe werden Flüstern aggressiv. */
	public int aggressiveWhisperTier = 3;

	/** Platzhalter: {victim} {owner} {lastwords} {killer} */
	public Map<String, List<String>> personalityWhispers = defaultPersonalityWhispers();

	public List<String> aggressiveWhispers = new ArrayList<>(List.of(
			"DU HAST MICH GETÖTET, {owner}.",
			"Ich sehe dich. Immer.",
			"Lass uns raus. LASS UNS RAUS.",
			"Noch eine Seele... dann gehörst du uns.",
			"Dein Herz schlägt zu laut, {owner}.",
			"Erinnerst du dich an meine letzten Worte? \"{lastwords}\""));

	/** Letzte Worte, falls ein Spieler nichts gesagt hat bzw. für Mobs. */
	public List<String> defaultLastWords = new ArrayList<>(List.of(
			"Nein... nicht so...",
			"Ich werde zurückkommen.",
			"Es ist so kalt...",
			"Sag ihnen... sag ihnen, dass es mir leid tut.",
			"Warum?",
			"Du wirst dafür bezahlen.",
			"Ich kann das Licht nicht mehr sehen."));

	/** Wie alt (Sekunden) eine Chat-Nachricht maximal sein darf, um als "letzte Worte" zu zählen. */
	public int lastWordsMaxAgeSeconds = 600;

	// ------------------------------------------------------------------ Korruption

	public boolean corruptionEnabled = true;
	/** Stufen, aufsteigend nach Schwelle sortiert. */
	public List<CorruptionTier> tiers = CorruptionTier.defaults();

	/** Fake-Chat-Nachrichten für Halluzinationen. {owner} = Spielername */
	public List<String> fakeChatMessages = new ArrayList<>(List.of(
			"hinter dir",
			"{owner}, ich weiß, was du getan hast",
			"wer ist da bei dir?",
			"hört ihr das auch?",
			"du hättest mich nicht töten sollen",
			"komm in die Höhle, {owner}"));
	/** Maximale Distanz eines Halluzinations-Teleports. */
	public double hallucinationTeleportRange = 4.0;

	// ------------------------------------------------------------------ Minion

	public boolean minionsEnabled = true;
	public int minionDurationSeconds = 60;
	public double minionAttackDamage = 6.0;
	public double minionMaxHealth = 20.0;
	public int maxMinionsPerPlayer = 2;

	// ------------------------------------------------------------------ Shop

	public boolean shopEnabled = true;
	/** Mindestens so viele Seelen müssen nach einem Kauf übrig bleiben. */
	public int shopMinRemainingSouls = 1;
	public List<ShopEntry> shopEntries = ShopEntry.defaults();

	// ------------------------------------------------------------------ Sonstiges

	public int autosaveMinutes = 5;

	// ======================================================================

	public enum ZeroSoulMode {
		/** Starke Debuffs, solange man 0 Seelen hat. */
		DEBUFF,
		/** Temporärer Bann vom Server. */
		TEMP_BAN
	}

	/** Ein Trank-Effekt per Registry-ID, z.B. {@code minecraft:strength} mit Stufe 0 = I. */
	public static final class EffectEntry {
		public String effect = "minecraft:speed";
		public int amplifier = 0;

		public EffectEntry() {
		}

		public EffectEntry(String effect, int amplifier) {
			this.effect = effect;
			this.amplifier = amplifier;
		}
	}

	private static Map<String, List<String>> defaultPersonalityWhispers() {
		Map<String, List<String>> map = new LinkedHashMap<>();
		map.put("VENGEFUL", List.of(
				"Ich werde mich rächen, {owner}.",
				"Jede Nacht sehe ich dein Gesicht.",
				"Du hast mir alles genommen.",
				"{killer} wird bezahlen. Und du auch."));
		map.put("SORROWFUL", List.of(
				"Ich wollte doch nur nach Hause...",
				"Ist es draußen noch hell?",
				"Ich vermisse meine Familie...",
				"\"{lastwords}\" ... das war alles, was ich noch sagen konnte."));
		map.put("MOCKING", List.of(
				"Haha, du schwingst dein Schwert wie ein Kind.",
				"Selbst ein Huhn kämpft besser als du, {owner}.",
				"Wirklich? DAS ist dein Plan?",
				"Ich war mal stärker als du. Peinlich, oder?"));
		map.put("INSANE", List.of(
				"Die Blöcke... sie atmen...",
				"Zähl die Sterne, {owner}. Einer fehlt.",
				"hehehehehehe",
				"Wir sind viele. Wir sind viele. Wir sind viele."));
		map.put("PLEADING", List.of(
				"Bitte... lass mich frei...",
				"Ich tue alles, was du willst. Nur lass mich gehen.",
				"Es tut so weh hier drin, {owner}...",
				"Hab Erbarmen."));
		return map;
	}
}
