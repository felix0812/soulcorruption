package com.soulcorruption.corruption;

import com.soulcorruption.SoulCorruption;
import com.soulcorruption.component.ModComponents;
import com.soulcorruption.component.SoulData;
import com.soulcorruption.config.ConfigManager;
import com.soulcorruption.config.CorruptionTier;
import com.soulcorruption.config.SoulConfig;
import com.soulcorruption.config.SoulConfig.EffectEntry;
import com.soulcorruption.data.PlayerSoulRecord;
import com.soulcorruption.network.ModNetworking;
import com.soulcorruption.soul.SoulService;
import net.minecraft.core.Holder;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.effect.MobEffect;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.item.ItemStack;
import org.jetbrains.annotations.Nullable;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;

/**
 * Berechnet die Korruption aller Spieler und wendet Effekte, Flüstern und
 * Halluzinationen an.
 * <p>
 * <b>Performance:</b> Jeder Spieler wird nur einmal pro Sekunde verarbeitet, und die
 * Spieler sind über die 20 Ticks verteilt (UUID-Hash), damit es keine Lastspitzen gibt.
 * Effekt-Holder werden gecacht, Pakete nur bei Änderungen gesendet.
 */
public final class CorruptionManager {
	private static final CorruptionManager INSTANCE = new CorruptionManager();

	/** Effekt-Dauer in Ticks; etwas länger als das Update-Intervall, damit nichts flackert. */
	private static final int EFFECT_DURATION = 20 * 3;
	private static final int PULSE_DURATION = 20 * 6;

	private final Map<UUID, PlayerState> states = new HashMap<>();
	private final Set<UUID> pendingUpdates = new HashSet<>();
	private final Map<String, Optional<Holder<MobEffect>>> effectCache = new HashMap<>();

	private final WhisperManager whispers = new WhisperManager();
	private final HallucinationManager hallucinations = new HallucinationManager();

	private CorruptionManager() {
	}

	public static CorruptionManager get() {
		return INSTANCE;
	}

	/** Zwischengespeicherter Zustand pro Spieler. */
	static final class PlayerState {
		int corruption;
		int tierIndex;
		int souls;
		/** Seelen im Inventar (für Flüster-Auswahl). */
		final List<SoulData> carried = new ArrayList<>();
		long nextWhisperTick;
		boolean synced;
	}

	// ------------------------------------------------------------------ öffentliche API

	/** Erzwingt eine Neuberechnung im nächsten Tick (z.B. nach Kill oder Absorbieren). */
	public void markForUpdate(ServerPlayer player) {
		pendingUpdates.add(player.getUUID());
	}

	public void forget(UUID uuid) {
		states.remove(uuid);
		pendingUpdates.remove(uuid);
	}

	public void clear() {
		states.clear();
		pendingUpdates.clear();
		effectCache.clear();
	}

	/** Leert den Effekt-Cache, z.B. nach {@code /soul reload}. */
	public void onConfigReload() {
		effectCache.clear();
		states.values().forEach(s -> s.synced = false);
	}

	public int corruptionOf(ServerPlayer player) {
		return update(player).corruption;
	}

	public CorruptionTier tierOf(ServerPlayer player) {
		List<CorruptionTier> tiers = ConfigManager.get().tiers;
		return tiers.get(Math.min(update(player).tierIndex, tiers.size() - 1));
	}

	// ------------------------------------------------------------------ Tick

	public void tick(MinecraftServer server) {
		long tick = server.getTickCount();
		SoulConfig config = ConfigManager.get();

		for (ServerPlayer player : server.getPlayerList().getPlayers()) {
			UUID uuid = player.getUUID();
			boolean scheduled = Math.floorMod(uuid.hashCode(), 20) == tick % 20;
			boolean forced = pendingUpdates.remove(uuid);
			if (!scheduled && !forced) {
				continue;
			}

			PlayerState state = update(player);
			if (!player.isAlive() || player.isSpectator()) {
				continue;
			}

			if (state.souls <= 0 && config.zeroSoulMode == SoulConfig.ZeroSoulMode.DEBUFF) {
				applyEffects(player, config.hollowEffects, EFFECT_DURATION);
			}

			if (scheduled && config.corruptionEnabled) {
				CorruptionTier tier = config.tiers.get(Math.min(state.tierIndex, config.tiers.size() - 1));
				applyTier(player, tier);
				hallucinations.tick(player, tier, state);
			}

			if (scheduled && config.whispersEnabled) {
				whispers.tick(player, state, tick);
			}
		}
	}

	/** Berechnet Korruption & Stufe neu und synchronisiert bei Änderungen zum Client. */
	private PlayerState update(ServerPlayer player) {
		SoulConfig config = ConfigManager.get();
		PlayerState state = states.computeIfAbsent(player.getUUID(), id -> new PlayerState());
		PlayerSoulRecord record = SoulService.record(player);

		state.carried.clear();
		int carriedCount = 0;
		Inventory inventory = player.getInventory();
		for (int i = 0; i < inventory.getContainerSize(); i++) {
			ItemStack stack = inventory.getItem(i);
			SoulData data = stack.get(ModComponents.SOUL_DATA);
			if (data != null) {
				carriedCount += stack.getCount();
				state.carried.add(data);
			}
		}

		// Korruption = absorbierte Fremdseelen (über dem Startwert) + mitgeführte Seelen-Orbs
		int corruption = Math.max(0, record.souls - config.startingSouls) + carriedCount;
		int tierIndex = 0;
		for (int i = 0; i < config.tiers.size(); i++) {
			if (corruption >= config.tiers.get(i).threshold) {
				tierIndex = i;
			}
		}

		boolean changed = !state.synced
				|| state.corruption != corruption
				|| state.tierIndex != tierIndex
				|| state.souls != record.souls;
		state.corruption = corruption;
		state.tierIndex = tierIndex;
		state.souls = record.souls;

		if (changed) {
			CorruptionTier tier = config.tiers.get(tierIndex);
			ModNetworking.sendSync(player, record.souls, corruption, tierIndex, tier);
			state.synced = true;
		}
		return state;
	}

	private void applyTier(ServerPlayer player, CorruptionTier tier) {
		applyEffects(player, tier.buffs, EFFECT_DURATION);
		applyEffects(player, tier.debuffs, EFFECT_DURATION);

		if (!tier.pulseDebuffs.isEmpty() && player.getRandom().nextDouble() < tier.pulseChance) {
			EffectEntry pulse = tier.pulseDebuffs.get(player.getRandom().nextInt(tier.pulseDebuffs.size()));
			applyEffect(player, pulse, PULSE_DURATION, true);
		}
	}

	private void applyEffects(ServerPlayer player, List<EffectEntry> entries, int duration) {
		for (EffectEntry entry : entries) {
			applyEffect(player, entry, duration, false);
		}
	}

	private void applyEffect(ServerPlayer player, EffectEntry entry, int duration, boolean visible) {
		Holder<MobEffect> effect = resolve(entry.effect);
		if (effect == null) {
			return;
		}
		// ambient=true, Partikel aus, Icon an – wirkt "natürlich" und nicht wie ein Trank
		player.addEffect(new MobEffectInstance(effect, duration, entry.amplifier, true, visible, true));
	}

	@Nullable
	private Holder<MobEffect> resolve(String id) {
		return effectCache.computeIfAbsent(id, key -> {
			Identifier identifier = Identifier.tryParse(key);
			Optional<Holder<MobEffect>> holder = identifier == null
					? Optional.empty()
					: BuiltInRegistries.MOB_EFFECT.get(identifier).map(h -> (Holder<MobEffect>) h);
			if (holder.isEmpty()) {
				SoulCorruption.LOGGER.warn("Unbekannter Effekt in der Config: {}", key);
			}
			return holder;
		}).orElse(null);
	}
}
