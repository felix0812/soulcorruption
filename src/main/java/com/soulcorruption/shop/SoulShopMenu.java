package com.soulcorruption.shop;

import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.Container;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.inventory.ChestMenu;
import net.minecraft.world.inventory.ContainerInput;
import net.minecraft.world.inventory.MenuType;
import net.minecraft.world.item.ItemStack;

/**
 * Truhen-Menü, in dem nichts bewegt werden kann. Ein Klick auf ein Angebot kauft es.
 */
public class SoulShopMenu extends ChestMenu {
	static final int ROWS = 3;
	static final int SIZE = ROWS * 9;

	public SoulShopMenu(int containerId, Inventory playerInventory, Container container) {
		super(MenuType.GENERIC_9x3, containerId, playerInventory, container, ROWS);
	}

	@Override
	public void clicked(int slotId, int button, ContainerInput input, Player player) {
		// Bewusst kein super.clicked(): Items im Shop dürfen nicht verschoben werden.
		if (player instanceof ServerPlayer serverPlayer && slotId >= 0 && slotId < SIZE
				&& input == ContainerInput.PICKUP) {
			SoulShop.purchase(serverPlayer, slotId);
		}
		// Client-Vorhersage zurücksetzen, damit keine "Geister-Items" entstehen.
		sendAllDataToRemote();
	}

	@Override
	public ItemStack quickMoveStack(Player player, int index) {
		return ItemStack.EMPTY;
	}

	@Override
	public boolean stillValid(Player player) {
		return true;
	}
}
