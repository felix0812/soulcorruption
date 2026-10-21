package com.soulcorruption.soul;

import com.soulcorruption.component.ModComponents;
import com.soulcorruption.component.Personality;
import com.soulcorruption.component.SoulData;
import com.soulcorruption.config.ConfigManager;
import com.soulcorruption.config.SoulConfig;
import com.soulcorruption.corruption.CorruptionManager;
import com.soulcorruption.data.PlayerSoulRecord;
import com.soulcorruption.data.SoulStore;
import com.soulcorruption.item.ModItems;
import net.minecraft.ChatFormatting;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.item.ItemEntity;
import net.minecraft.world.item.ItemStack;

import java.time.Duration;

/**
 * Kernlogik des Seelen-Systems: Stehlen, Verlieren, Absorbieren, Abheben.
 * Alle Methoden laufen auf dem Server-Thread.
 */
public final class SoulService {
	private SoulService() {
	}

	// ------------------------------------------------------------------ Items

	/** Erstellt einen Seelen-Orb mit allen Persönlichkeits-Daten. */
	public static ItemStack createSoul(SoulData data) {
		ItemStack stack = new ItemStack(ModItems.SOUL);
		stack.set(ModComponents.SOUL_DATA, data);
		stack.set(DataComponents.CUSTOM_NAME,
				Component.translatable("item.soulcorruption.soul.named", data.victimName())
						.withStyle(style -> style.withItalic(false).withColor(data.personality().color())));
		return stack;
	}

	/** Gibt dem Spieler ein Item; bei vollem Inventar wird es vor ihm gedroppt. */
	public static void give(ServerPlayer player, ItemStack stack) {
		if (!player.getInventory().add(stack) && !stack.isEmpty()) {
			ItemEntity item = new ItemEntity(player.level(), player.getX(), player.getY() + 0.5, player.getZ(), stack);
			item.setNoPickUpDelay();
			player.level().addFreshEntity(item);
		}
	}

	// ------------------------------------------------------------------ Events

	/** Wird nach jedem Tod eines LivingEntity aufgerufen. */
	public static void onEntityDeath(LivingEntity victim, DamageSource source) {
		if (!(victim.level() instanceof ServerLevel level)) {
			return;
		}
		SoulConfig config = ConfigManager.get();
		Entity attacker = source.getEntity();
		ServerPlayer killer = attacker instanceof ServerPlayer p && p != victim ? p : null;

		if (victim instanceof ServerPlayer victimPlayer) {
			handlePlayerDeath(level, victimPlayer, killer);
			return;
		}

		// Starker Mob → Chance auf eine Seele
		if (killer != null && isSoulMob(victim) && level.getRandom().nextDouble() < config.mobSoulChance) {
			SoulData data = new SoulData(
					victim.getName().getString(),
					LastWordsTracker.randomDefault(level.getRandom()),
					System.currentTimeMillis(),
					Personality.random(level.getRandom()),
					false,
					killer.getName().getString());
			harvest(level, killer, victim, data);
		}
	}

	private static void handlePlayerDeath(ServerLevel level, ServerPlayer victim, ServerPlayer killer) {
		SoulConfig config = ConfigManager.get();
		PlayerSoulRecord record = record(victim);
		String lastWords = LastWordsTracker.lastWordsOf(victim, level.getRandom());

		int loss = Math.min(record.souls, config.soulsLostOnDeath);
		boolean stolen = killer != null && config.pvpSoulSteal;
		if (stolen) {
			// Bei PvP verliert das Opfer immer mindestens eine Seele – an den Killer.
			loss = Math.min(record.souls, Math.max(1, loss));
		}
		if (loss <= 0) {
			return;
		}

		record.souls -= loss;
		SoulStore.get().markDirty();

		SoulData data = new SoulData(
				victim.getName().getString(),
				lastWords,
				System.currentTimeMillis(),
				Personality.random(level.getRandom()),
				true,
				killer != null ? killer.getName().getString() : "Tod");

		int remaining = loss;
		if (stolen) {
			harvest(level, killer, victim, data);
			remaining--;
		}
		if (remaining > 0 && config.dropLostSoulsOnDeath) {
			for (int i = 0; i < remaining; i++) {
				ItemEntity item = new ItemEntity(level, victim.getX(), victim.getY() + 0.5, victim.getZ(), createSoul(data));
				item.setDefaultPickUpDelay();
				level.addFreshEntity(item);
			}
		}

		victim.sendSystemMessage(Component.translatable("message.soulcorruption.soul_lost", loss, record.souls)
				.withStyle(ChatFormatting.DARK_RED));
		CorruptionManager.get().markForUpdate(victim);
	}

	/** Übergibt eine Seele an den Killer, inkl. Effekten und Statistik. */
	private static void harvest(ServerLevel level, ServerPlayer killer, LivingEntity victim, SoulData data) {
		give(killer, createSoul(data));

		PlayerSoulRecord record = record(killer);
		record.totalStolen++;
		SoulStore.get().markDirty();

		level.sendParticles(ParticleTypes.SOUL, victim.getX(), victim.getY() + 1.0, victim.getZ(),
				25, 0.3, 0.6, 0.3, 0.03);
		level.playSound(null, victim.getX(), victim.getY(), victim.getZ(),
				SoundEvents.SOUL_ESCAPE, SoundSource.PLAYERS, 1.2f, 0.7f);

		killer.sendSystemMessage(Component.translatable("message.soulcorruption.soul_stolen", data.victimName())
				.withStyle(ChatFormatting.DARK_PURPLE));
		CorruptionManager.get().markForUpdate(killer);
	}

	private static boolean isSoulMob(LivingEntity entity) {
		SoulConfig config = ConfigManager.get();
		String id = BuiltInRegistries.ENTITY_TYPE.getKey(entity.getType()).toString();
		return config.soulMobs.contains(id) || entity.getMaxHealth() >= config.strongMobMinHealth;
	}

	public static void onJoin(ServerPlayer player) {
		SoulConfig config = ConfigManager.get();
		PlayerSoulRecord record = record(player);

		if (record.isBanned()) {
			long minutes = Math.max(1, Duration.ofMillis(record.bannedUntil - System.currentTimeMillis()).toMinutes());
			player.connection.disconnect(Component.translatable("message.soulcorruption.banned", minutes)
					.withStyle(ChatFormatting.DARK_RED));
			return;
		}
		if (record.bannedUntil != 0) {
			// Bann abgelaufen → mit wenigen Seelen zurück ins Leben.
			record.bannedUntil = 0;
			record.souls = Math.max(record.souls, config.soulsAfterBan);
			SoulStore.get().markDirty();
			player.sendSystemMessage(Component.translatable("message.soulcorruption.ban_over")
					.withStyle(ChatFormatting.GRAY, ChatFormatting.ITALIC));
		}
		CorruptionManager.get().markForUpdate(player);
	}

	public static void onRespawn(ServerPlayer player) {
		PlayerSoulRecord record = record(player);
		if (record.souls > 0) {
			CorruptionManager.get().markForUpdate(player);
			return;
		}

		SoulConfig config = ConfigManager.get();
		if (config.zeroSoulMode == SoulConfig.ZeroSoulMode.TEMP_BAN && config.tempBanMinutes > 0) {
			record.bannedUntil = System.currentTimeMillis() + config.tempBanMinutes * 60_000L;
			SoulStore.get().markDirty();
			SoulStore.get().save();
			player.connection.disconnect(Component.translatable("message.soulcorruption.banned", config.tempBanMinutes)
					.withStyle(ChatFormatting.DARK_RED));
		} else {
			player.sendSystemMessage(Component.translatable("message.soulcorruption.hollow")
					.withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC));
			CorruptionManager.get().markForUpdate(player);
		}
	}

	// ------------------------------------------------------------------ Aktionen

	/** Absorbiert einen Seelen-Orb: +1 eigene Seele. */
	public static boolean absorb(ServerPlayer player, ItemStack stack) {
		SoulConfig config = ConfigManager.get();
		if (!config.allowAbsorb) {
			return false;
		}
		PlayerSoulRecord record = record(player);
		if (record.souls >= config.maxSouls) {
			player.sendSystemMessage(Component.translatable("message.soulcorruption.max_souls", config.maxSouls)
					.withStyle(ChatFormatting.RED));
			return false;
		}
		record.souls++;
		SoulStore.get().markDirty();

		SoulData data = stack.get(ModComponents.SOUL_DATA);
		String victim = data != null ? data.victimName() : "?";
		ServerLevel level = (ServerLevel) player.level();
		level.sendParticles(ParticleTypes.SCULK_SOUL, player.getX(), player.getY() + 1.0, player.getZ(),
				20, 0.4, 0.6, 0.4, 0.02);
		level.playSound(null, player.getX(), player.getY(), player.getZ(),
				SoundEvents.SCULK_SHRIEKER_SHRIEK, SoundSource.PLAYERS, 0.6f, 1.6f);
		player.sendSystemMessage(Component.translatable("message.soulcorruption.absorbed", victim, record.souls)
				.withStyle(ChatFormatting.DARK_PURPLE));
		CorruptionManager.get().markForUpdate(player);
		return true;
	}

	/** Wandelt eigene Seelen in Orbs um. Mindestens eine Seele bleibt immer übrig. */
	public static int withdraw(ServerPlayer player, int amount) {
		PlayerSoulRecord record = record(player);
		int possible = Math.min(amount, record.souls - 1);
		if (possible <= 0) {
			return 0;
		}
		record.souls -= possible;
		SoulStore.get().markDirty();

		for (int i = 0; i < possible; i++) {
			give(player, createSoul(new SoulData(
					player.getName().getString(),
					"Ich bin ein Teil von dir.",
					System.currentTimeMillis(),
					Personality.SORROWFUL,
					true,
					player.getName().getString())));
		}
		CorruptionManager.get().markForUpdate(player);
		return possible;
	}

	/** Setzt die Seelen eines Spielers (Admin). */
	public static void setSouls(ServerPlayer player, int souls) {
		PlayerSoulRecord record = record(player);
		record.souls = Math.clamp(souls, 0, ConfigManager.get().maxSouls);
		SoulStore.get().markDirty();
		CorruptionManager.get().markForUpdate(player);
	}

	/** Zieht Seelen ab, falls genug vorhanden sind (Shop). */
	public static boolean trySpend(ServerPlayer player, int price) {
		PlayerSoulRecord record = record(player);
		if (record.souls - price < ConfigManager.get().shopMinRemainingSouls) {
			return false;
		}
		record.souls -= price;
		SoulStore.get().markDirty();
		CorruptionManager.get().markForUpdate(player);
		return true;
	}

	public static PlayerSoulRecord record(ServerPlayer player) {
		return SoulStore.get().getOrCreate(player.getUUID(), player.getName().getString());
	}
}
