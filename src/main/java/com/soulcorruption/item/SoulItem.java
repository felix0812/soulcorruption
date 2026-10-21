package com.soulcorruption.item;

import com.soulcorruption.minion.MinionManager;
import com.soulcorruption.soul.SoulService;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;

/**
 * Der Seelen-Orb.
 * <ul>
 *     <li>Rechtsklick: Seele absorbieren (+1 eigene Seele, erhöht Korruption)</li>
 *     <li>Schleichen + Rechtsklick: Geist des Opfers als temporären Diener beschwören</li>
 * </ul>
 * Die Persönlichkeits-Infos werden clientseitig als Tooltip angezeigt
 * (siehe {@code SoulTooltip} im Client-Sourceset).
 */
public class SoulItem extends Item {
	public SoulItem(Properties properties) {
		super(properties);
	}

	@Override
	public InteractionResult use(Level level, Player player, InteractionHand hand) {
		if (!(player instanceof ServerPlayer serverPlayer)) {
			// Client: sofortiges Feedback (Hand-Animation), Server entscheidet.
			return InteractionResult.SUCCESS;
		}

		ItemStack stack = player.getItemInHand(hand);
		boolean success = player.isShiftKeyDown()
				? MinionManager.get().summon(serverPlayer, stack)
				: SoulService.absorb(serverPlayer, stack);

		if (success) {
			stack.shrink(1);
			return InteractionResult.SUCCESS;
		}
		return InteractionResult.FAIL;
	}
}
