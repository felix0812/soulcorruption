package com.soulcorruption.soul;

import com.soulcorruption.config.ConfigManager;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.util.RandomSource;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

/** Merkt sich die letzte Chat-Nachricht jedes Spielers – das werden seine "letzten Worte". */
public final class LastWordsTracker {
	private static final Map<UUID, Entry> LAST_MESSAGES = new HashMap<>();

	private record Entry(String message, long time) {
	}

	private LastWordsTracker() {
	}

	public static void record(ServerPlayer player, String message) {
		String trimmed = message.length() > 120 ? message.substring(0, 117) + "..." : message;
		LAST_MESSAGES.put(player.getUUID(), new Entry(trimmed, System.currentTimeMillis()));
	}

	/** Letzte Worte eines Spielers, oder ein zufälliger Standardsatz, wenn er (zu lange) nichts gesagt hat. */
	public static String lastWordsOf(ServerPlayer player, RandomSource random) {
		Entry entry = LAST_MESSAGES.remove(player.getUUID());
		long maxAge = ConfigManager.get().lastWordsMaxAgeSeconds * 1000L;
		if (entry != null && System.currentTimeMillis() - entry.time() <= maxAge) {
			return entry.message();
		}
		return randomDefault(random);
	}

	public static String randomDefault(RandomSource random) {
		List<String> defaults = ConfigManager.get().defaultLastWords;
		return defaults.isEmpty() ? "..." : defaults.get(random.nextInt(defaults.size()));
	}

	public static void clear() {
		LAST_MESSAGES.clear();
	}
}
