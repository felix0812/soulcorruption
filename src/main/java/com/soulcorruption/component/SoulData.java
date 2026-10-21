package com.soulcorruption.component;

import com.mojang.serialization.Codec;
import com.mojang.serialization.codecs.RecordCodecBuilder;
import io.netty.buffer.ByteBuf;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;

/**
 * Daten einer gefangenen Seele, gespeichert als Data Component direkt am ItemStack.
 *
 * @param victimName  Name des Opfers (Spieler- oder Mob-Name)
 * @param lastWords   die letzten Worte des Opfers
 * @param timestamp   Zeitpunkt des Todes (Unix-Millisekunden)
 * @param personality Persönlichkeit, bestimmt die Flüster-Texte
 * @param playerSoul  true, wenn das Opfer ein Spieler war
 * @param reaperName  Name dessen, der die Seele geerntet hat
 */
public record SoulData(
		String victimName,
		String lastWords,
		long timestamp,
		Personality personality,
		boolean playerSoul,
		String reaperName
) {
	public static final Codec<SoulData> CODEC = RecordCodecBuilder.create(instance -> instance.group(
			Codec.STRING.fieldOf("victim").forGetter(SoulData::victimName),
			Codec.STRING.optionalFieldOf("last_words", "...").forGetter(SoulData::lastWords),
			Codec.LONG.optionalFieldOf("timestamp", 0L).forGetter(SoulData::timestamp),
			Personality.CODEC.optionalFieldOf("personality", Personality.SORROWFUL).forGetter(SoulData::personality),
			Codec.BOOL.optionalFieldOf("player", false).forGetter(SoulData::playerSoul),
			Codec.STRING.optionalFieldOf("reaper", "?").forGetter(SoulData::reaperName)
	).apply(instance, SoulData::new));

	public static final StreamCodec<ByteBuf, SoulData> STREAM_CODEC = StreamCodec.composite(
			ByteBufCodecs.STRING_UTF8, SoulData::victimName,
			ByteBufCodecs.STRING_UTF8, SoulData::lastWords,
			ByteBufCodecs.VAR_LONG, SoulData::timestamp,
			Personality.STREAM_CODEC, SoulData::personality,
			ByteBufCodecs.BOOL, SoulData::playerSoul,
			ByteBufCodecs.STRING_UTF8, SoulData::reaperName,
			SoulData::new);
}
