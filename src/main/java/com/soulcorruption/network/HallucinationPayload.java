package com.soulcorruption.network;

import com.soulcorruption.SoulCorruption;
import io.netty.buffer.ByteBuf;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.network.protocol.common.custom.CustomPacketPayload;

/** Server → Client: löst eine rein clientseitige Halluzination aus. */
public record HallucinationPayload(Kind kind) implements CustomPacketPayload {

	public enum Kind {
		/** Ein Mob erscheint kurz hinter dem Spieler und verschwindet wieder. */
		FAKE_MOB,
		/** Geräusche, die nicht da sind (Schritte, Creeper-Zischen, ...). */
		PHANTOM_SOUND,
		/** Kurzes rotes Flackern des Bildschirms. */
		SCREEN_FLASH
	}

	public static final Type<HallucinationPayload> TYPE = new Type<>(SoulCorruption.id("hallucination"));

	public static final StreamCodec<ByteBuf, HallucinationPayload> CODEC = ByteBufCodecs.VAR_INT.map(
			i -> new HallucinationPayload(Kind.values()[Math.floorMod(i, Kind.values().length)]),
			p -> p.kind().ordinal());

	@Override
	public Type<? extends CustomPacketPayload> type() {
		return TYPE;
	}
}
