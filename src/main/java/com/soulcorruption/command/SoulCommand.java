package com.soulcorruption.command;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.IntegerArgumentType;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.exceptions.CommandSyntaxException;
import com.soulcorruption.component.Personality;
import com.soulcorruption.component.SoulData;
import com.soulcorruption.config.ConfigManager;
import com.soulcorruption.config.CorruptionTier;
import com.soulcorruption.corruption.CorruptionManager;
import com.soulcorruption.data.PlayerSoulRecord;
import com.soulcorruption.data.SoulStore;
import com.soulcorruption.shop.SoulShop;
import com.soulcorruption.soul.LastWordsTracker;
import com.soulcorruption.soul.SoulService;
import net.minecraft.ChatFormatting;
import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.arguments.EntityArgument;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.server.level.ServerPlayer;

import java.util.List;

import static net.minecraft.commands.Commands.argument;
import static net.minecraft.commands.Commands.literal;

/**
 * {@code /soul} – alle Befehle des Mods.
 * <pre>
 * /soul balance [spieler]       Seelen & Korruption anzeigen
 * /soul top                     Rangliste
 * /soul withdraw &lt;anzahl&gt;       eigene Seelen in Orbs umwandeln
 * /soul shop                    Seelen-Shop öffnen
 * /soul admin set|add &lt;spieler&gt; &lt;anzahl&gt;
 * /soul admin give &lt;spieler&gt; [opfer]
 * /soul admin unban &lt;spieler&gt;
 * /soul admin reload
 * </pre>
 */
public final class SoulCommand {
	private SoulCommand() {
	}

	public static void register(CommandDispatcher<CommandSourceStack> dispatcher) {
		dispatcher.register(literal("soul")
				.executes(ctx -> balance(ctx.getSource(), ctx.getSource().getPlayerOrException()))
				.then(literal("balance")
						.executes(ctx -> balance(ctx.getSource(), ctx.getSource().getPlayerOrException()))
						.then(argument("player", EntityArgument.player())
								.executes(ctx -> balance(ctx.getSource(), EntityArgument.getPlayer(ctx, "player")))))
				.then(literal("top")
						.executes(ctx -> top(ctx.getSource())))
				.then(literal("withdraw")
						.then(argument("amount", IntegerArgumentType.integer(1, 64))
								.executes(SoulCommand::withdraw)))
				.then(literal("shop")
						.executes(ctx -> {
							SoulShop.open(ctx.getSource().getPlayerOrException());
							return 1;
						}))
				.then(literal("admin")
						.requires(Commands.hasPermission(Commands.LEVEL_GAMEMASTERS))
						.then(literal("set")
								.then(argument("player", EntityArgument.player())
										.then(argument("amount", IntegerArgumentType.integer(0))
												.executes(ctx -> setSouls(ctx, false)))))
						.then(literal("add")
								.then(argument("player", EntityArgument.player())
										.then(argument("amount", IntegerArgumentType.integer())
												.executes(ctx -> setSouls(ctx, true)))))
						.then(literal("give")
								.then(argument("player", EntityArgument.player())
										.executes(ctx -> giveSoul(ctx, "Unbekannte Seele"))
										.then(argument("victim", StringArgumentType.greedyString())
												.executes(ctx -> giveSoul(ctx, StringArgumentType.getString(ctx, "victim"))))))
						.then(literal("unban")
								.then(argument("player", StringArgumentType.word())
										.executes(SoulCommand::unban)))
						.then(literal("reload")
								.executes(SoulCommand::reload))));
	}

	private static int balance(CommandSourceStack source, ServerPlayer target) {
		PlayerSoulRecord record = SoulService.record(target);
		int corruption = CorruptionManager.get().corruptionOf(target);
		CorruptionTier tier = CorruptionManager.get().tierOf(target);

		source.sendSuccess(() -> Component.translatable("command.soulcorruption.balance",
				target.getDisplayName(),
				Component.literal(String.valueOf(record.souls)).withStyle(ChatFormatting.LIGHT_PURPLE),
				Component.literal(String.valueOf(corruption)).withStyle(ChatFormatting.DARK_RED),
				tierName(tier),
				record.totalStolen).withStyle(ChatFormatting.GRAY), false);
		return record.souls;
	}

	private static int top(CommandSourceStack source) {
		List<PlayerSoulRecord> top = SoulStore.get().top(10);
		MutableComponent message = Component.translatable("command.soulcorruption.top_header")
				.withStyle(ChatFormatting.DARK_PURPLE, ChatFormatting.BOLD);
		int rank = 1;
		for (PlayerSoulRecord record : top) {
			message.append(Component.literal("\n" + rank++ + ". ").withStyle(ChatFormatting.DARK_GRAY))
					.append(Component.literal(record.name).withStyle(ChatFormatting.GRAY))
					.append(Component.literal(" – " + record.souls + " ☠").withStyle(ChatFormatting.LIGHT_PURPLE));
		}
		if (top.isEmpty()) {
			message.append(Component.literal("\n–").withStyle(ChatFormatting.DARK_GRAY));
		}
		source.sendSuccess(() -> message, false);
		return top.size();
	}

	private static int withdraw(CommandContext<CommandSourceStack> ctx) throws CommandSyntaxException {
		ServerPlayer player = ctx.getSource().getPlayerOrException();
		int amount = IntegerArgumentType.getInteger(ctx, "amount");
		int done = SoulService.withdraw(player, amount);
		if (done <= 0) {
			ctx.getSource().sendFailure(Component.translatable("command.soulcorruption.withdraw_failed"));
			return 0;
		}
		ctx.getSource().sendSuccess(() -> Component.translatable("command.soulcorruption.withdrawn",
				done, SoulService.record(player).souls).withStyle(ChatFormatting.DARK_PURPLE), false);
		return done;
	}

	private static int setSouls(CommandContext<CommandSourceStack> ctx, boolean add) throws CommandSyntaxException {
		ServerPlayer player = EntityArgument.getPlayer(ctx, "player");
		int amount = IntegerArgumentType.getInteger(ctx, "amount");
		int value = add ? SoulService.record(player).souls + amount : amount;
		SoulService.setSouls(player, value);
		int result = SoulService.record(player).souls;
		ctx.getSource().sendSuccess(() -> Component.translatable("command.soulcorruption.set",
				player.getDisplayName(), result), true);
		return result;
	}

	private static int giveSoul(CommandContext<CommandSourceStack> ctx, String victim) throws CommandSyntaxException {
		ServerPlayer player = EntityArgument.getPlayer(ctx, "player");
		SoulService.give(player, SoulService.createSoul(new SoulData(
				victim,
				LastWordsTracker.randomDefault(player.getRandom()),
				System.currentTimeMillis(),
				Personality.random(player.getRandom()),
				false,
				ctx.getSource().getTextName())));
		ctx.getSource().sendSuccess(() -> Component.translatable("command.soulcorruption.given",
				player.getDisplayName(), victim), true);
		return 1;
	}

	private static int unban(CommandContext<CommandSourceStack> ctx) {
		String name = StringArgumentType.getString(ctx, "player");
		for (PlayerSoulRecord record : SoulStore.get().top(Integer.MAX_VALUE)) {
			if (record.name.equalsIgnoreCase(name) && record.bannedUntil != 0) {
				record.bannedUntil = System.currentTimeMillis() - 1;
				SoulStore.get().markDirty();
				ctx.getSource().sendSuccess(() -> Component.translatable("command.soulcorruption.unbanned", record.name), true);
				return 1;
			}
		}
		ctx.getSource().sendFailure(Component.translatable("command.soulcorruption.not_banned", name));
		return 0;
	}

	private static int reload(CommandContext<CommandSourceStack> ctx) {
		ConfigManager.load();
		CorruptionManager.get().onConfigReload();
		ctx.getSource().sendSuccess(() -> Component.translatable("command.soulcorruption.reloaded"), true);
		return 1;
	}

	private static Component tierName(CorruptionTier tier) {
		ChatFormatting color = ChatFormatting.GRAY;
		for (ChatFormatting formatting : ChatFormatting.values()) {
			if (formatting.isColor() && formatting.name().equalsIgnoreCase(tier.color)) {
				color = formatting;
			}
		}
		return Component.literal(tier.name).withStyle(color);
	}
}
