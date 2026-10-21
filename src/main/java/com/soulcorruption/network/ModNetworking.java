package com.soulcorruption.network;

import com.soulcorruption.config.CorruptionTier;
import net.fabricmc.fabric.api.networking.v1.PayloadTypeRegistry;
import net.fabricmc.fabric.api.networking.v1.ServerPlayNetworking;
import net.minecraft.server.level.ServerPlayer;

/**
 * Netzwerk-Registrierung und Sende-Helfer.
 * <p>
 * Pakete werden nur an Clients geschickt, die den Mod installiert haben – Vanilla-Clients
 * können also trotzdem joinen (sie sehen dann nur die serverseitigen Effekte).
 */
public final class ModNetworking {
	private ModNetworking() {
	}

	public static void registerPayloads() {
		PayloadTypeRegistry.playS2C().register(SoulSyncPayload.TYPE, SoulSyncPayload.CODEC);
		PayloadTypeRegistry.playS2C().register(HallucinationPayload.TYPE, HallucinationPayload.CODEC);
	}

	public static void sendSync(ServerPlayer player, int souls, int corruption, int tierIndex, CorruptionTier tier) {
		if (ServerPlayNetworking.canSend(player, SoulSyncPayload.TYPE)) {
			ServerPlayNetworking.send(player, new SoulSyncPayload(
					souls, corruption, tierIndex, tier.particleDensity, tier.overlayStrength));
		}
	}

	public static void sendHallucination(ServerPlayer player, HallucinationPayload.Kind kind) {
		if (ServerPlayNetworking.canSend(player, HallucinationPayload.TYPE)) {
			ServerPlayNetworking.send(player, new HallucinationPayload(kind));
		}
	}
}
