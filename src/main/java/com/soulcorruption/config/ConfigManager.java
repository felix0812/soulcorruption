package com.soulcorruption.config;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.soulcorruption.SoulCorruption;
import net.fabricmc.loader.api.FabricLoader;

import java.io.IOException;
import java.io.Reader;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;

/**
 * Lädt und speichert {@link SoulConfig} als JSON.
 * <p>
 * Nach jedem Laden wird die Datei neu geschrieben, damit neue Optionen
 * (z.B. nach einem Mod-Update) automatisch in der Datei auftauchen.
 */
public final class ConfigManager {
	private static final Gson GSON = new GsonBuilder()
			.setPrettyPrinting()
			.disableHtmlEscaping()
			.create();

	private static SoulConfig config = new SoulConfig();

	private ConfigManager() {
	}

	public static SoulConfig get() {
		return config;
	}

	public static Path path() {
		return FabricLoader.getInstance().getConfigDir().resolve(SoulCorruption.MOD_ID + ".json");
	}

	/** Lädt die Config (oder erstellt sie mit Standardwerten). */
	public static void load() {
		Path path = path();
		SoulConfig loaded = null;

		if (Files.exists(path)) {
			try (Reader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8)) {
				loaded = GSON.fromJson(reader, SoulConfig.class);
			} catch (Exception e) {
				SoulCorruption.LOGGER.error("Config {} ist ungültig – verwende Standardwerte.", path, e);
			}
		}

		config = loaded != null ? loaded : new SoulConfig();
		sanitize(config);
		save();
	}

	public static void save() {
		try {
			Files.createDirectories(path().getParent());
			try (Writer writer = Files.newBufferedWriter(path(), StandardCharsets.UTF_8)) {
				GSON.toJson(config, writer);
			}
		} catch (IOException e) {
			SoulCorruption.LOGGER.error("Config konnte nicht gespeichert werden", e);
		}
	}

	/** Korrigiert offensichtlich ungültige Werte, damit der Rest des Codes sich darauf verlassen kann. */
	private static void sanitize(SoulConfig c) {
		c.startingSouls = Math.max(0, c.startingSouls);
		c.maxSouls = Math.max(1, c.maxSouls);
		c.soulStackSize = Math.clamp(c.soulStackSize, 1, 99);
		c.soulsLostOnDeath = Math.max(0, c.soulsLostOnDeath);
		c.mobSoulChance = Math.clamp(c.mobSoulChance, 0.0, 1.0);
		c.whisperBaseIntervalSeconds = Math.max(5, c.whisperBaseIntervalSeconds);
		c.whisperMinIntervalSeconds = Math.clamp(c.whisperMinIntervalSeconds, 5, c.whisperBaseIntervalSeconds);
		c.minionDurationSeconds = Math.max(1, c.minionDurationSeconds);
		c.autosaveMinutes = Math.max(1, c.autosaveMinutes);

		if (c.tiers == null || c.tiers.isEmpty()) {
			c.tiers = CorruptionTier.defaults();
		}
		c.tiers.sort(Comparator.comparingInt(t -> t.threshold));
		if (c.shopEntries == null) {
			c.shopEntries = ShopEntry.defaults();
		}
		if (c.shopEntries.size() > 27) {
			c.shopEntries = c.shopEntries.subList(0, 27);
		}
	}
}
