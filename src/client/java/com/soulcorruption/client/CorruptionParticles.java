package com.soulcorruption.client;

import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.ClientLevel;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.util.RandomSource;

/** Seelen-Partikel, die um korrumpierte Spieler aufsteigen (nur lokal, kostet keinen Netzwerkverkehr). */
public final class CorruptionParticles {
	private CorruptionParticles() {
	}

	static void tick(Minecraft mc) {
		LocalPlayer player = mc.player;
		ClientLevel level = mc.level;
		float density = ClientSoulState.particleDensity();
		if (player == null || level == null || density <= 0 || mc.isPaused()) {
			return;
		}

		RandomSource random = player.getRandom();
		// density 0..1 → erwartete Partikel pro Tick
		int count = (int) density + (random.nextFloat() < density % 1f ? 1 : 0);
		for (int i = 0; i < count; i++) {
			double x = player.getX() + (random.nextDouble() - 0.5) * 1.2;
			double y = player.getY() + random.nextDouble() * player.getBbHeight();
			double z = player.getZ() + (random.nextDouble() - 0.5) * 1.2;

			if (ClientSoulState.tier() >= 3 && random.nextFloat() < 0.3f) {
				level.addParticle(ParticleTypes.SCULK_SOUL, x, y, z, 0, 0.03, 0);
			} else if (random.nextFloat() < 0.5f) {
				level.addParticle(ParticleTypes.SOUL, x, y, z, 0, 0.02, 0);
			} else {
				level.addParticle(ParticleTypes.SMOKE, x, y, z, 0, 0.01, 0);
			}
		}
	}
}
