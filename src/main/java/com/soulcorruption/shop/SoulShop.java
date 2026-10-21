package com.soulcorruption.shop;

import com.soulcorruption.config.ConfigManager;
import com.soulcorruption.config.ShopEntry;
import com.soulcorruption.config.SoulConfig;
import com.soulcorruption.soul.SoulService;
import net.minecraft.ChatFormatting;
import net.minecraft.core.component.DataComponents;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.Identifier;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.SimpleContainer;
import net.minecraft.world.SimpleMenuProvider;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraft.world.item.component.ItemLore;

import java.util.List;

/**
 * Einfacher Seelen-Shop als Server-GUI (Truhen-Menü).
 * Funktioniert ohne Client-Mod, da nur Vanilla-Menüs verwendet werden.
 */
public final class SoulShop {
	private SoulShop() {
	}

	public static void open(ServerPlayer player) {
		SoulConfig config = ConfigManager.get();
		if (!config.shopEnabled) {
			player.sendSystemMessage(Component.translatable("message.soulcorruption.shop_disabled").withStyle(ChatFormatting.GRAY));
			return;
		}

		SimpleContainer container = new SimpleContainer(SoulShopMenu.SIZE);
		for (int i = 0; i < config.shopEntries.size() && i < SoulShopMenu.SIZE; i++) {
			container.setItem(i, displayStack(config.shopEntries.get(i)));
		}

		player.openMenu(new SimpleMenuProvider(
				(id, inventory, p) -> new SoulShopMenu(id, inventory, container),
				Component.translatable("gui.soulcorruption.shop", SoulService.record(player).souls)));
	}

	private static ItemStack displayStack(ShopEntry entry) {
		Item item = resolve(entry.item);
		ItemStack stack = new ItemStack(item == null ? Items.BARRIER : item, Math.clamp(entry.count, 1, 99));
		stack.set(DataComponents.LORE, new ItemLore(List.of(
				Component.translatable("gui.soulcorruption.price", entry.price)
						.withStyle(style -> style.withItalic(false).withColor(ChatFormatting.DARK_PURPLE)),
				Component.translatable("gui.soulcorruption.click_to_buy")
						.withStyle(style -> style.withItalic(true).withColor(ChatFormatting.DARK_GRAY)))));
		return stack;
	}

	/** Wird vom Menü aufgerufen, wenn ein Angebot angeklickt wurde. */
	static void purchase(ServerPlayer player, int index) {
		List<ShopEntry> entries = ConfigManager.get().shopEntries;
		if (index < 0 || index >= entries.size()) {
			return;
		}
		ShopEntry entry = entries.get(index);
		Item item = resolve(entry.item);
		if (item == null) {
			return;
		}

		if (!SoulService.trySpend(player, entry.price)) {
			player.sendSystemMessage(Component.translatable("message.soulcorruption.shop_too_poor",
					entry.price, ConfigManager.get().shopMinRemainingSouls).withStyle(ChatFormatting.RED));
			playSound(player, SoundEvents.VILLAGER_NO, 0.8f);
			return;
		}

		SoulService.give(player, new ItemStack(item, Math.clamp(entry.count, 1, 99)));
		playSound(player, SoundEvents.SOUL_ESCAPE.value(), 1.2f);
		player.sendSystemMessage(Component.translatable("message.soulcorruption.shop_bought",
				entry.count, item.getName(), entry.price, SoulService.record(player).souls)
				.withStyle(ChatFormatting.DARK_PURPLE));
	}

	private static void playSound(ServerPlayer player, SoundEvent sound, float pitch) {
		player.level().playSound(null, player.getX(), player.getY(), player.getZ(), sound, SoundSource.PLAYERS, 1f, pitch);
	}

	private static Item resolve(String id) {
		Identifier identifier = Identifier.tryParse(id);
		if (identifier == null || !BuiltInRegistries.ITEM.containsKey(identifier)) {
			return null;
		}
		return BuiltInRegistries.ITEM.getValue(identifier);
	}
}
