package com.soulcorruption.config;

import java.util.ArrayList;
import java.util.List;

/** Ein Angebot im Seelen-Shop: {@link #count}x {@link #item} für {@link #price} Seelen. */
public final class ShopEntry {
	public String item = "minecraft:diamond";
	public int count = 1;
	public int price = 1;

	public ShopEntry() {
	}

	public ShopEntry(String item, int count, int price) {
		this.item = item;
		this.count = count;
		this.price = price;
	}

	static List<ShopEntry> defaults() {
		return new ArrayList<>(List.of(
				new ShopEntry("minecraft:golden_apple", 2, 1),
				new ShopEntry("minecraft:ender_pearl", 8, 1),
				new ShopEntry("minecraft:diamond", 4, 2),
				new ShopEntry("minecraft:experience_bottle", 32, 2),
				new ShopEntry("minecraft:totem_of_undying", 1, 5),
				new ShopEntry("minecraft:enchanted_golden_apple", 1, 8),
				new ShopEntry("minecraft:netherite_ingot", 1, 10),
				new ShopEntry("minecraft:soul_lantern", 4, 1),
				new ShopEntry("minecraft:echo_shard", 2, 3)));
	}
}
