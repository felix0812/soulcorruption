package com.soulcorruption.minion;

import com.soulcorruption.component.ModComponents;
import com.soulcorruption.component.SoulData;
import com.soulcorruption.config.ConfigManager;
import com.soulcorruption.config.SoulConfig;
import net.minecraft.ChatFormatting;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.network.chat.Component;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.ai.attributes.AttributeInstance;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.monster.Vex;
import net.minecraft.world.item.ItemStack;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;

/**
 * Beschwört den Geist eines Opfers (ein gezähmter Vex) als temporären Diener.
 * <p>
 * Der Geist folgt seinem Beschwörer, greift an, was der Beschwörer angreift
 * (oder was ihn angreift), kann dem Beschwörer nicht schaden und löst sich
 * nach Ablauf der Zeit in Seelenfeuer auf.
 */
public final class MinionManager {
	private static final MinionManager INSTANCE = new MinionManager();
	/** Markierung, um verwaiste Geister nach einem Neustart zu erkennen. */
	public static final String MINION_TAG = "soulcorruption.minion";

	private final Map<UUID, Minion> minions = new HashMap<>();

	private record Minion(Vex entity, UUID owner) {
	}

	private MinionManager() {
	}

	public static MinionManager get() {
		return INSTANCE;
	}

	/** @return true, wenn ein Geist beschworen wurde (Item wird dann verbraucht). */
	public boolean summon(ServerPlayer player, ItemStack stack) {
		SoulConfig config = ConfigManager.get();
		if (!config.minionsEnabled) {
			player.sendSystemMessage(Component.translatable("message.soulcorruption.minion_disabled")
					.withStyle(ChatFormatting.GRAY));
			return false;
		}
		long owned = minions.values().stream().filter(m -> m.owner().equals(player.getUUID())).count();
		if (owned >= config.maxMinionsPerPlayer) {
			player.sendSystemMessage(Component.translatable("message.soulcorruption.minion_limit", config.maxMinionsPerPlayer)
					.withStyle(ChatFormatting.RED));
			return false;
		}

		ServerLevel level = (ServerLevel) player.level();
		Vex vex = EntityType.VEX.create(level, EntitySpawnReason.MOB_SUMMONED);
		if (vex == null) {
			return false;
		}

		SoulData data = stack.get(ModComponents.SOUL_DATA);
		String name = data != null ? data.victimName() : "Namenlos";
		ChatFormatting color = data != null ? data.personality().color() : ChatFormatting.GRAY;

		vex.setPos(player.getX(), player.getY() + 1.5, player.getZ());
		vex.setCustomName(Component.translatable("entity.soulcorruption.ghost", name).withStyle(color));
		vex.setCustomNameVisible(true);
		vex.setGlowingTag(true);
		vex.setLimitedLife(config.minionDurationSeconds * 20);
		vex.setBoundOrigin(player.blockPosition());
		vex.addTag(MINION_TAG);
		setAttribute(vex.getAttribute(Attributes.MAX_HEALTH), config.minionMaxHealth);
		setAttribute(vex.getAttribute(Attributes.ATTACK_DAMAGE), config.minionAttackDamage);
		vex.setHealth(vex.getMaxHealth());

		level.addFreshEntity(vex);
		minions.put(vex.getUUID(), new Minion(vex, player.getUUID()));

		level.sendParticles(ParticleTypes.SOUL_FIRE_FLAME, vex.getX(), vex.getY(), vex.getZ(), 30, 0.4, 0.4, 0.4, 0.05);
		level.playSound(null, vex.getX(), vex.getY(), vex.getZ(), SoundEvents.EVOKER_PREPARE_SUMMON, SoundSource.PLAYERS, 1f, 0.6f);
		player.sendSystemMessage(Component.translatable("message.soulcorruption.minion_summoned", name)
				.withStyle(ChatFormatting.DARK_PURPLE));
		return true;
	}

	private static void setAttribute(AttributeInstance attribute, double value) {
		if (attribute != null) {
			attribute.setBaseValue(value);
		}
	}

	/** Lenkt die Geister jeden Tick: Ziel = Gegner des Besitzers, Bewegungsanker = Besitzer. */
	public void tick(MinecraftServer server) {
		if (minions.isEmpty()) {
			return;
		}
		Iterator<Minion> it = minions.values().iterator();
		while (it.hasNext()) {
			Minion minion = it.next();
			Vex vex = minion.entity();
			ServerPlayer owner = server.getPlayerList().getPlayer(minion.owner());

			if (!vex.isAlive() || owner == null || owner.level() != vex.level()) {
				vanish(vex);
				it.remove();
				continue;
			}

			vex.setBoundOrigin(owner.blockPosition().above(2));
			LivingEntity desired = pickTarget(owner, vex);
			if (vex.getTarget() != desired) {
				vex.setTarget(desired);
			}
		}
	}

	private static LivingEntity pickTarget(ServerPlayer owner, Vex vex) {
		LivingEntity target = owner.getLastHurtMob();
		if (!isValidTarget(target, owner, vex)) {
			target = owner.getLastHurtByMob();
		}
		return isValidTarget(target, owner, vex) ? target : null;
	}

	private static boolean isValidTarget(LivingEntity target, ServerPlayer owner, Vex vex) {
		return target != null
				&& target.isAlive()
				&& target != owner
				&& !target.getTags().contains(MINION_TAG)
				&& target.level() == vex.level()
				&& target.distanceToSqr(owner) < 32 * 32;
	}

	/** Geister verletzen niemals ihren Beschwörer. */
	public boolean allowDamage(LivingEntity entity, DamageSource source, float amount) {
		Entity attacker = source.getEntity();
		if (attacker != null && attacker.getTags().contains(MINION_TAG)) {
			Minion minion = minions.get(attacker.getUUID());
			return minion == null || !minion.owner().equals(entity.getUUID());
		}
		return true;
	}

	/** Entfernt Geister, die nach einem Neustart ohne Besitzer geladen werden. */
	public void onEntityLoad(Entity entity, ServerLevel level) {
		if (entity.getTags().contains(MINION_TAG) && !minions.containsKey(entity.getUUID())) {
			entity.discard();
		}
	}

	public void dismissOwnedBy(UUID owner) {
		minions.values().removeIf(m -> {
			if (m.owner().equals(owner)) {
				vanish(m.entity());
				return true;
			}
			return false;
		});
	}

	public void dismissAll() {
		minions.values().forEach(m -> m.entity().discard());
		minions.clear();
	}

	private static void vanish(Vex vex) {
		if (vex.isAlive() && vex.level() instanceof ServerLevel level) {
			level.sendParticles(ParticleTypes.SOUL, vex.getX(), vex.getY() + 0.5, vex.getZ(), 15, 0.3, 0.3, 0.3, 0.02);
		}
		vex.discard();
	}
}
