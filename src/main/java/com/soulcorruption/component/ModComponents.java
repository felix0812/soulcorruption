package com.soulcorruption.component;

import com.soulcorruption.SoulCorruption;
import net.minecraft.core.Registry;
import net.minecraft.core.component.DataComponentType;
import net.minecraft.core.registries.BuiltInRegistries;

/** Registrierung der eigenen Data Components. */
public final class ModComponents {
	/** Persönlichkeit, Name & letzte Worte einer Seele. Persistiert und zum Client synchronisiert. */
	public static final DataComponentType<SoulData> SOUL_DATA = DataComponentType.<SoulData>builder()
			.persistent(SoulData.CODEC)
			.networkSynchronized(SoulData.STREAM_CODEC)
			.build();

	private ModComponents() {
	}

	public static void register() {
		Registry.register(BuiltInRegistries.DATA_COMPONENT_TYPE, SoulCorruption.id("soul_data"), SOUL_DATA);
	}
}
