package com.soulcorruption.client;

import com.soulcorruption.network.HallucinationPayload;
import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.commands.arguments.EntityAnchorArgument;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.RandomSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntitySpawnReason;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.EntityTypes;
import net.minecraft.world.phys.Vec3;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;

/**
 * Rein clientseitige Halluzinationen: Fake-Mobs existieren nur in der lokalen Welt
 * des betroffenen Spielers. Der Server weiß nichts von ihnen – sie können nicht
 * angreifen und verschwinden, sobald man sie direkt ansieht.
 */
public final class ClientHallucinations {
	private static final List<FakeMob> FAKE_MOBS = new ArrayList<>();
	/** Negative IDs kollidieren nie mit echten (vom Server vergebenen) Entity-IDs. */
	private static int nextFakeId = -100_000;

	private record FakeMob(Entity entity, int[] ticksLeft) {
	}

	private static final List<EntityType<?>> MOB_TYPES = List.of(
			EntityTypes.ZOMBIE, EntityTypes.SKELETON, EntityTypes.CREEPER, EntityTypes.ENDERMAN, EntityTypes.WITCH);

	private ClientHallucinations() {
	}

	static void trigger(Minecraft mc, HallucinationPayload.Kind kind) {
		LocalPlayer player = mc.player;
		ClientLevel level = mc.level;
		if (player == null || level == null) {
			return;
		}
		switch (kind) {
			case FAKE_MOB -> spawnFakeMob(level, player);
			case PHANTOM_SOUND -> phantomSound(level, player);
			case SCREEN_FLASH -> CorruptionOverlay.flash(10);
		}
	}

	/** Lässt einen Mob hinter dem Spieler erscheinen, der ihn anstarrt. */
	private static void spawnFakeMob(ClientLevel level, LocalPlayer player) {
		RandomSource random = player.getRandom();
		Entity entity = MOB_TYPES.get(random.nextInt(MOB_TYPES.size())).create(level, EntitySpawnReason.LOAD);
		if (entity == null) {
			return;
		}

		// Position: 6–10 Blöcke hinter dem Spieler
		Vec3 behind = player.getLookAngle().multiply(-1, 0, -1).normalize();
		double distance = 6 + random.nextDouble() * 4;
		double x = player.getX() + behind.x * distance + (random.nextDouble() - 0.5) * 3;
		double z = player.getZ() + behind.z * distance + (random.nextDouble() - 0.5) * 3;

		entity.setId(nextFakeId--);
		entity.setPos(x, player.getY(), z);
		entity.lookAt(EntityAnchorArgument.Anchor.EYES, player.getEyePosition());
		entity.setSilent(true);
		entity.noPhysics = true;
		level.addEntity(entity);

		FAKE_MOBS.add(new FakeMob(entity, new int[]{60 + random.nextInt(80)}));
	}

	private static void phantomSound(ClientLevel level, LocalPlayer player) {
		RandomSource random = player.getRandom();
		SoundEvent[] sounds = {
				SoundEvents.CREEPER_PRIMED,
				SoundEvents.ZOMBIE_AMBIENT,
				SoundEvents.ENDERMAN_STARE,
				SoundEvents.WARDEN_HEARTBEAT,
				SoundEvents.SKELETON_AMBIENT,
				SoundEvents.WOODEN_DOOR_OPEN
		};
		SoundEvent sound = sounds[random.nextInt(sounds.length)];
		double angle = random.nextDouble() * Math.PI * 2;
		double x = player.getX() + Math.cos(angle) * 4;
		double z = player.getZ() + Math.sin(angle) * 4;
		level.playLocalSound(x, player.getY(), z, sound, SoundSource.HOSTILE, 1f, 0.8f + random.nextFloat() * 0.3f, false);
	}

	static void tick(Minecraft mc) {
		if (FAKE_MOBS.isEmpty()) {
			return;
		}
		LocalPlayer player = mc.player;
		ClientLevel level = mc.level;
		if (player == null || level == null) {
			FAKE_MOBS.clear();
			return;
		}

		Iterator<FakeMob> it = FAKE_MOBS.iterator();
		while (it.hasNext()) {
			FakeMob mob = it.next();
			Entity entity = mob.entity();
			entity.lookAt(EntityAnchorArgument.Anchor.EYES, player.getEyePosition());

			// Verschwindet, wenn die Zeit abläuft oder der Spieler direkt hinsieht
			Vec3 toMob = entity.position().subtract(player.getEyePosition()).normalize();
			boolean looked = player.getLookAngle().dot(toMob) > 0.96;
			if (--mob.ticksLeft()[0] <= 0 || looked) {
				level.removeEntity(entity.getId(), Entity.RemovalReason.DISCARDED);
				it.remove();
			}
		}
	}

	static void clear(Minecraft mc) {
		if (mc.level != null) {
			for (FakeMob mob : FAKE_MOBS) {
				mc.level.removeEntity(mob.entity().getId(), Entity.RemovalReason.DISCARDED);
			}
		}
		FAKE_MOBS.clear();
	}
}
