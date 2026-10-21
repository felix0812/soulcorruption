package com.soulcorruption.corruption;

import com.soulcorruption.SoulCorruption;
import com.soulcorruption.component.SoulData;
import com.soulcorruption.config.ConfigManager;
import com.soulcorruption.config.CorruptionTier;
import com.soulcorruption.config.SoulConfig;
import com.soulcorruption.network.HallucinationPayload;
import com.soulcorruption.network.ModNetworking;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.util.RandomSource;

import java.util.ArrayList;
import java.util.List;

/**
 * Halluzinationen bei starker Korruption.
 * <ul>
 *     <li>Serverseitig: Fake-Chat-Nachrichten, kleine Teleports</li>
 *     <li>Clientseitig (per Paket ausgelöst): Fake-Mobs, Phantom-Geräusche, Bildschirm-Flackern</li>
 * </ul>
 */
final class HallucinationManager {

	void tick(ServerPlayer player, CorruptionTier tier, CorruptionManager.PlayerState state) {
		RandomSource random = player.getRandom();
		if (tier.hallucinationChance <= 0 || random.nextDouble() >= tier.hallucinationChance) {
			return;
		}

		int roll = random.nextInt(tier.hallucinationTeleports ? 5 : 4);
		switch (roll) {
			case 0 -> fakeChat(player, state, random);
			case 1 -> ModNetworking.sendHallucination(player, HallucinationPayload.Kind.FAKE_MOB);
			case 2 -> ModNetworking.sendHallucination(player, HallucinationPayload.Kind.PHANTOM_SOUND);
			case 3 -> ModNetworking.sendHallucination(player, HallucinationPayload.Kind.SCREEN_FLASH);
			default -> teleport(player, random);
		}
	}

	/** Eine Chat-Nachricht, die so aussieht, als käme sie von einem (toten) Spieler. */
	private void fakeChat(ServerPlayer player, CorruptionManager.PlayerState state, RandomSource random) {
		SoulConfig config = ConfigManager.get();
		if (config.fakeChatMessages.isEmpty()) {
			return;
		}

		List<String> names = new ArrayList<>();
		for (SoulData soul : state.carried) {
			if (soul.playerSoul()) {
				names.add(soul.victimName());
			}
		}
		if (names.isEmpty() && SoulCorruption.server() != null) {
			for (ServerPlayer other : SoulCorruption.server().getPlayerList().getPlayers()) {
				if (other != player) {
					names.add(other.getName().getString());
				}
			}
		}
		if (names.isEmpty()) {
			names.add("???");
		}

		String name = names.get(random.nextInt(names.size()));
		String text = config.fakeChatMessages.get(random.nextInt(config.fakeChatMessages.size()))
				.replace("{owner}", player.getName().getString());
		// Sieht aus wie normaler Spieler-Chat – ist aber nur für diesen Spieler sichtbar.
		player.sendSystemMessage(Component.literal("<" + name + "> " + text));
	}

	/** Kleiner, sicherer Teleport in der Nähe (wie bei einer Chorusfrucht). */
	private void teleport(ServerPlayer player, RandomSource random) {
		if (player.isPassenger() || player.isSleeping()) {
			return;
		}
		double range = ConfigManager.get().hallucinationTeleportRange;
		for (int attempt = 0; attempt < 8; attempt++) {
			double x = player.getX() + (random.nextDouble() - 0.5) * 2 * range;
			double y = player.getY() + random.nextInt(3) - 1;
			double z = player.getZ() + (random.nextDouble() - 0.5) * 2 * range;
			if (player.randomTeleport(x, y, z, true)) {
				ModNetworking.sendHallucination(player, HallucinationPayload.Kind.SCREEN_FLASH);
				return;
			}
		}
	}
}
