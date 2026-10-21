package com.soulcorruption.corruption;

import com.soulcorruption.component.SoulData;
import com.soulcorruption.config.ConfigManager;
import com.soulcorruption.config.SoulConfig;
import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;
import net.minecraft.network.protocol.game.ClientboundSetActionBarTextPacket;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.util.RandomSource;

import java.util.List;

/**
 * Lässt mitgeführte Seelen ihrem Besitzer zuflüstern.
 * Je höher die Korruption, desto häufiger – und ab einer Stufe aggressiver.
 */
final class WhisperManager {

	void tick(ServerPlayer player, CorruptionManager.PlayerState state, long tick) {
		if (state.carried.isEmpty() && state.corruption <= 0) {
			return;
		}
		if (state.nextWhisperTick == 0) {
			state.nextWhisperTick = tick + nextInterval(player.getRandom(), state);
			return;
		}
		if (tick < state.nextWhisperTick) {
			return;
		}
		state.nextWhisperTick = tick + nextInterval(player.getRandom(), state);
		whisper(player, state);
	}

	/** Intervall in Ticks: sinkt mit steigender Korruption von base bis min, plus Zufall. */
	private long nextInterval(RandomSource random, CorruptionManager.PlayerState state) {
		SoulConfig config = ConfigManager.get();
		double factor = 1.0 / (1.0 + state.corruption * 0.15);
		double seconds = Math.max(config.whisperMinIntervalSeconds, config.whisperBaseIntervalSeconds * factor);
		seconds *= 0.75 + random.nextDouble() * 0.5;
		return (long) (seconds * 20);
	}

	private void whisper(ServerPlayer player, CorruptionManager.PlayerState state) {
		SoulConfig config = ConfigManager.get();
		RandomSource random = player.getRandom();

		SoulData soul = state.carried.isEmpty() ? null : state.carried.get(random.nextInt(state.carried.size()));
		boolean aggressive = state.tierIndex >= config.aggressiveWhisperTier && random.nextFloat() < 0.6f;

		String template;
		if (aggressive || soul == null) {
			template = pick(random, config.aggressiveWhispers);
		} else {
			template = pick(random, config.personalityWhispers.get(soul.personality().name()));
		}
		if (template == null) {
			return;
		}

		String victim = soul != null ? soul.victimName() : "???";
		String text = template
				.replace("{victim}", victim)
				.replace("{owner}", player.getName().getString())
				.replace("{lastwords}", soul != null ? soul.lastWords() : "...")
				.replace("{killer}", soul != null ? soul.reaperName() : player.getName().getString());

		ChatFormatting color = soul != null ? soul.personality().color() : ChatFormatting.DARK_RED;
		MutableComponent message = Component.literal("☠ ").withStyle(ChatFormatting.DARK_GRAY)
				.append(Component.literal(victim).withStyle(color, ChatFormatting.ITALIC))
				.append(Component.literal(" flüstert: ").withStyle(ChatFormatting.DARK_GRAY, ChatFormatting.ITALIC))
				.append(Component.literal(text).withStyle(aggressive
						? new ChatFormatting[]{ChatFormatting.DARK_RED, ChatFormatting.BOLD}
						: new ChatFormatting[]{ChatFormatting.GRAY, ChatFormatting.ITALIC}));

		if (config.whispersInActionbar) {
			player.connection.send(new ClientboundSetActionBarTextPacket(message));
		} else {
			player.sendSystemMessage(message);
		}
	}

	private static String pick(RandomSource random, List<String> list) {
		return list == null || list.isEmpty() ? null : list.get(random.nextInt(list.size()));
	}
}
