package com.soulcorruption.item;

import com.soulcorruption.SoulCorruption;
import com.soulcorruption.config.ConfigManager;
import com.soulcorruption.config.SoulConfig;
import net.fabricmc.fabric.api.creativetab.v1.CreativeModeTabEvents;
import net.minecraft.core.Registry;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.Rarity;

/** Registrierung der Mod-Items. */
public final class ModItems {
	public static final ResourceKey<Item> SOUL_KEY = ResourceKey.create(Registries.ITEM, SoulCorruption.id("soul"));

	public static Item SOUL;

	private ModItems() {
	}

	public static void register() {
		SoulConfig config = ConfigManager.get();
		int stackSize = config.soulItemsStackable ? config.soulStackSize : 1;

		SOUL = Registry.register(BuiltInRegistries.ITEM, SOUL_KEY, new SoulItem(new Item.Properties()
				.setId(SOUL_KEY)
				.stacksTo(stackSize)
				.rarity(Rarity.EPIC)
				.fireResistant()
				// Dauerhafter Verzauberungsglanz → "leuchtender" Orb
				.component(DataComponents.ENCHANTMENT_GLINT_OVERRIDE, true)));

		CreativeModeTabEvents.modifyOutputEvent(CreativeModeTabs.INGREDIENTS)
				.register(output -> output.accept(SOUL));
	}
}
