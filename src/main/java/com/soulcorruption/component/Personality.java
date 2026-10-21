package com.soulcorruption.component;

import com.mojang.serialization.Codec;
import io.netty.buffer.ByteBuf;
import net.minecraft.ChatFormatting;
import net.minecraft.network.codec.ByteBufCodecs;
import net.minecraft.network.codec.StreamCodec;
import net.minecraft.util.RandomSource;
import net.minecraft.util.StringRepresentable;

/** Die Persönlichkeit einer gefangenen Seele – bestimmt, wie sie flüstert. */
public enum Personality implements StringRepresentable {
	VENGEFUL("vengeful", ChatFormatting.RED),
	SORROWFUL("sorrowful", ChatFormatting.BLUE),
	MOCKING("mocking", ChatFormatting.GOLD),
	INSANE("insane", ChatFormatting.LIGHT_PURPLE),
	PLEADING("pleading", ChatFormatting.AQUA);

	public static final Codec<Personality> CODEC = StringRepresentable.fromEnum(Personality::values);
	public static final StreamCodec<ByteBuf, Personality> STREAM_CODEC =
			ByteBufCodecs.VAR_INT.map(i -> values()[Math.floorMod(i, values().length)], Personality::ordinal);

	private final String serializedName;
	private final ChatFormatting color;

	Personality(String serializedName, ChatFormatting color) {
		this.serializedName = serializedName;
		this.color = color;
	}

	public ChatFormatting color() {
		return color;
	}

	/** Übersetzungsschlüssel für den Anzeigenamen. */
	public String translationKey() {
		return "personality.soulcorruption." + serializedName;
	}

	@Override
	public String getSerializedName() {
		return serializedName;
	}

	public static Personality random(RandomSource random) {
		return values()[random.nextInt(values().length)];
	}
}
