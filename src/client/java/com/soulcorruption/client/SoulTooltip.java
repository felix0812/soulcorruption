package com.soulcorruption.client;

import com.soulcorruption.component.ModComponents;
import com.soulcorruption.component.SoulData;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.ItemStack;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;

/** Zeigt die Persönlichkeit einer Seele im Tooltip an. */
public final class SoulTooltip {
	private static final DateTimeFormatter DATE = DateTimeFormatter.ofPattern("dd.MM.yyyy HH:mm")
			.withZone(ZoneId.systemDefault());

	private SoulTooltip() {
	}

	static void append(ItemStack stack, List<Component> lines) {
		SoulData data = stack.get(ModComponents.SOUL_DATA);
		if (data == null) {
			lines.add(Component.translatable("tooltip.soulcorruption.empty").withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC));
			return;
		}

		lines.add(Component.translatable("tooltip.soulcorruption.victim",
						Component.literal(data.victimName()).withStyle(data.personality().color()))
				.withStyle(ChatFormatting.GRAY));
		lines.add(Component.translatable("tooltip.soulcorruption.personality",
						Component.translatable(data.personality().translationKey()).withStyle(data.personality().color()))
				.withStyle(ChatFormatting.GRAY));
		lines.add(Component.translatable("tooltip.soulcorruption.type",
						Component.translatable(data.playerSoul() ? "tooltip.soulcorruption.type.player" : "tooltip.soulcorruption.type.mob"))
				.withStyle(ChatFormatting.GRAY));
		lines.add(Component.translatable("tooltip.soulcorruption.reaper", data.reaperName()).withStyle(ChatFormatting.GRAY));
		if (data.timestamp() > 0) {
			lines.add(Component.translatable("tooltip.soulcorruption.time",
					DATE.format(Instant.ofEpochMilli(data.timestamp()))).withStyle(ChatFormatting.DARK_GRAY));
		}
		lines.add(Component.empty());
		lines.add(Component.translatable("tooltip.soulcorruption.last_words").withStyle(ChatFormatting.DARK_PURPLE));
		lines.add(Component.literal("  „" + data.lastWords() + "“").withStyle(ChatFormatting.LIGHT_PURPLE, ChatFormatting.ITALIC));
		lines.add(Component.empty());
		lines.add(Component.translatable("tooltip.soulcorruption.hint_absorb").withStyle(ChatFormatting.DARK_GRAY));
		lines.add(Component.translatable("tooltip.soulcorruption.hint_summon").withStyle(ChatFormatting.DARK_GRAY));
	}
}
