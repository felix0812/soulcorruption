package com.soulcorruption;

import com.soulcorruption.command.SoulCommand;
import com.soulcorruption.component.ModComponents;
import com.soulcorruption.config.ConfigManager;
import com.soulcorruption.corruption.CorruptionManager;
import com.soulcorruption.data.SoulStore;
import com.soulcorruption.item.ModItems;
import com.soulcorruption.minion.MinionManager;
import com.soulcorruption.network.ModNetworking;
import com.soulcorruption.soul.LastWordsTracker;
import com.soulcorruption.soul.SoulService;
import net.fabricmc.api.ModInitializer;
import net.fabricmc.fabric.api.command.v2.CommandRegistrationCallback;
import net.fabricmc.fabric.api.entity.event.v1.ServerLivingEntityEvents;
import net.fabricmc.fabric.api.entity.event.v1.ServerPlayerEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerEntityEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerLifecycleEvents;
import net.fabricmc.fabric.api.event.lifecycle.v1.ServerTickEvents;
import net.fabricmc.fabric.api.message.v1.ServerMessageEvents;
import net.fabricmc.fabric.api.networking.v1.ServerPlayConnectionEvents;
import net.minecraft.resources.Identifier;
import net.minecraft.server.MinecraftServer;
import org.jetbrains.annotations.Nullable;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Einstiegspunkt (gemeinsamer Code für Server und Client).
 * <p>
 * Hier werden nur Registrierungen und Event-Verdrahtung erledigt – die eigentliche
 * Logik steckt in den jeweiligen Managern/Services.
 */
public final class SoulCorruption implements ModInitializer {
	public static final String MOD_ID = "soulcorruption";
	public static final Logger LOGGER = LoggerFactory.getLogger("SoulCorruption");

	@Nullable
	private static MinecraftServer server;

	public static Identifier id(String path) {
		return Identifier.fromNamespaceAndPath(MOD_ID, path);
	}

	/** Der aktuell laufende Server (integriert oder dediziert), sonst {@code null}. */
	@Nullable
	public static MinecraftServer server() {
		return server;
	}

	@Override
	public void onInitialize() {
		// Config zuerst laden – Item-Eigenschaften (Stapelgröße) hängen davon ab.
		ConfigManager.load();

		ModComponents.register();
		ModItems.register();
		ModNetworking.registerPayloads();

		registerLifecycle();
		registerGameplayEvents();

		CommandRegistrationCallback.EVENT.register((dispatcher, registryAccess, environment) ->
				SoulCommand.register(dispatcher));

		LOGGER.info("SoulCorruption geladen – die Seelen warten.");
	}

	private static void registerLifecycle() {
		ServerLifecycleEvents.SERVER_STARTED.register(s -> {
			server = s;
			SoulStore.get().load(s);
		});
		ServerLifecycleEvents.SERVER_STOPPING.register(s -> {
			MinionManager.get().dismissAll();
			SoulStore.get().save();
			CorruptionManager.get().clear();
			LastWordsTracker.clear();
			server = null;
		});

		ServerTickEvents.END_SERVER_TICK.register(s -> {
			CorruptionManager.get().tick(s);
			MinionManager.get().tick(s);
			SoulStore.get().tickAutosave(s);
		});
	}

	private static void registerGameplayEvents() {
		// Kills & Tode → Seelen stehlen / verlieren
		ServerLivingEntityEvents.AFTER_DEATH.register(SoulService::onEntityDeath);

		// Minions dürfen ihren Beschwörer nicht verletzen
		ServerLivingEntityEvents.ALLOW_DAMAGE.register(MinionManager.get()::allowDamage);

		// Übrig gebliebene Minions (z.B. nach Absturz) beim Laden entfernen
		ServerEntityEvents.ENTITY_LOAD.register(MinionManager.get()::onEntityLoad);

		// Letzte Worte = letzte Chat-Nachricht eines Spielers
		ServerMessageEvents.CHAT_MESSAGE.register((message, sender, params) ->
				LastWordsTracker.record(sender, message.signedContent()));

		ServerPlayerEvents.AFTER_RESPAWN.register((oldPlayer, newPlayer, alive) ->
				SoulService.onRespawn(newPlayer));

		ServerPlayConnectionEvents.JOIN.register((handler, sender, s) ->
				SoulService.onJoin(handler.player));
		ServerPlayConnectionEvents.DISCONNECT.register((handler, s) -> {
			CorruptionManager.get().forget(handler.player.getUUID());
			MinionManager.get().dismissOwnedBy(handler.player.getUUID());
		});
	}
}
