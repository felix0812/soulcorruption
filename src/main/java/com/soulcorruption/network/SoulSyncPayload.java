package com.soulcorruption.network;

import com.soulcorruption.SoulCorruption;
import io.netty.buffer.ByteBuf;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;

/**
 * Server → Client: aktueller Seelen-/Korruptionsstand für clientseitige Effekte.
 *
 * @param souls           eigene Seelen
 * @param corruption      Korruptionswert
 * @param tier            Index der Korruptionsstufe
 * @param particleDensity Partikel-Dichte der Stufe
 * @param overlayStrength Overlay-Stärke der Stufe
 */
public record SoulSyncPayload(int souls, int corruption, int tier, float particleDensity, float overlayStrength)
		implements CustomPacketPayload {

	public static final Type<SoulSyncPayload> TYPE = new Type<>(SoulCorruption.id("sync"));

	public static final StreamCodec<ByteBuf, SoulSyncPayload> CODEC = StreamCodec.composite(
			ByteBufCodecs.VAR_INT, SoulSyncPayload::souls,
			ByteBufCodecs.VAR_INT, SoulSyncPayload::corruption,
			ByteBufCodecs.VAR_INT, SoulSyncPayload::tier,
			ByteBufCodecs.FLOAT, SoulSyncPayload::particleDensity,
			ByteBufCodecs.FLOAT, SoulSyncPayload::overlayStrength,
			SoulSyncPayload::new);

	@Override
	public Type<? extends CustomPacketPayload> type() {
		return TYPE;
	}
}
