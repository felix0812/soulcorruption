package com.soulcorruption.data;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.reflect.TypeToken;
import com.soulcorruption.SoulCorruption;
import com.soulcorruption.config.ConfigManager;
import net.minecraft.server.MinecraftServer;
import net.minecraft.world.level.storage.LevelResource;
import org.jetbrains.annotations.Nullable;

import java.io.IOException;
import java.io.Reader;
import java.io.Writer;
import java.lang.reflect.Type;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/**
 * Persistente Seelen-Daten aller Spieler (auch offline – nötig für {@code /soul top}).
 * <p>
 * Gespeichert wird pro Welt unter {@code <welt>/soulcorruption/souls.json}.
 * Geschrieben wird nur, wenn sich etwas geändert hat (Autosave + beim Stoppen),
 * und zwar atomar über eine temporäre Datei.
 */
public final class SoulStore {
	private static final SoulStore INSTANCE = new SoulStore();
	private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();
	private static final Type MAP_TYPE = new TypeToken<HashMap<UUID, PlayerSoulRecord>>() {}.getType();

	private final Map<UUID, PlayerSoulRecord> records = new HashMap<>();
	@Nullable
	private Path file;
	private boolean dirty;
	private long ticksSinceSave;

	private SoulStore() {
	}

	public static SoulStore get() {
		return INSTANCE;
	}

	public void load(MinecraftServer server) {
		records.clear();
		file = server.getWorldPath(LevelResource.ROOT).resolve(SoulCorruption.MOD_ID).resolve("souls.json");

		if (Files.exists(file)) {
			try (Reader reader = Files.newBufferedReader(file, StandardCharsets.UTF_8)) {
				Map<UUID, PlayerSoulRecord> loaded = GSON.fromJson(reader, MAP_TYPE);
				if (loaded != null) {
					records.putAll(loaded);
				}
			} catch (Exception e) {
				SoulCorruption.LOGGER.error("Seelen-Daten konnten nicht geladen werden: {}", file, e);
			}
		}
		dirty = false;
		SoulCorruption.LOGGER.info("{} Seelen-Datensätze geladen.", records.size());
	}

	public void save() {
		if (file == null || !dirty) {
			return;
		}
		try {
			Files.createDirectories(file.getParent());
			Path tmp = file.resolveSibling("souls.json.tmp");
			try (Writer writer = Files.newBufferedWriter(tmp, StandardCharsets.UTF_8)) {
				GSON.toJson(records, MAP_TYPE, writer);
			}
			Files.move(tmp, file, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
			dirty = false;
		} catch (IOException e) {
			SoulCorruption.LOGGER.error("Seelen-Daten konnten nicht gespeichert werden", e);
		}
	}

	public void tickAutosave(MinecraftServer server) {
		if (++ticksSinceSave >= ConfigManager.get().autosaveMinutes * 60L * 20L) {
			ticksSinceSave = 0;
			save();
		}
	}

	/** Liefert den Datensatz eines Spielers und legt ihn bei Bedarf mit Startseelen an. */
	public PlayerSoulRecord getOrCreate(UUID uuid, String name) {
		PlayerSoulRecord record = records.computeIfAbsent(uuid, id -> {
			dirty = true;
			PlayerSoulRecord r = new PlayerSoulRecord();
			r.souls = ConfigManager.get().startingSouls;
			return r;
		});
		if (!name.equals(record.name)) {
			record.name = name;
			dirty = true;
		}
		return record;
	}

	@Nullable
	public PlayerSoulRecord find(UUID uuid) {
		return records.get(uuid);
	}

	public void markDirty() {
		dirty = true;
	}

	/** Die Spieler mit den meisten Seelen, absteigend sortiert. */
	public List<PlayerSoulRecord> top(int limit) {
		List<PlayerSoulRecord> list = new ArrayList<>(records.values());
		list.sort(Comparator.comparingInt((PlayerSoulRecord r) -> r.souls).reversed()
				.thenComparing(r -> r.name));
		return list.subList(0, Math.min(limit, list.size()));
	}
}
