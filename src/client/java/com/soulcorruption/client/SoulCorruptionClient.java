package com.soulcorruption.client;

import com.soulcorruption.SoulCorruption;
import com.soulcorruption.network.HallucinationPayload;
import com.soulcorruption.network.SoulSyncPayload;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.item.v1.ItemTooltipCallback;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayNetworking;
import net.fabricmc.fabric.api.client.rendering.v1.hud.HudElementRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.hud.VanillaHudElements;

/**
 * Client-Einstiegspunkt: rein visuelle Effekte (Overlay, Partikel, Halluzinationen, Tooltip).
 * Der Server bleibt die einzige Quelle der Wahrheit.
 */
public final class SoulCorruptionClient implements ClientModInitializer {

	@Override
	public void onInitializeClient() {
		ClientPlayNetworking.registerGlobalReceiver(SoulSyncPayload.TYPE, (payload, context) ->
				context.client().execute(() -> ClientSoulState.update(payload)));
		ClientPlayNetworking.registerGlobalReceiver(HallucinationPayload.TYPE, (payload, context) ->
				context.client().execute(() -> ClientHallucinations.trigger(context.client(), payload.kind())));

		ClientPlayConnectionEvents.DISCONNECT.register((handler, client) -> {
			ClientSoulState.reset();
			ClientHallucinations.clear(client);
		});

		ClientTickEvents.END_CLIENT_TICK.register(client -> {
			CorruptionParticles.tick(client);
			ClientHallucinations.tick(client);
			CorruptionOverlay.tick();
		});

		// Dunkles Korruptions-Overlay unter dem Chat, über der Spielwelt
		HudElementRegistry.attachElementBefore(VanillaHudElements.CHAT, SoulCorruption.id("corruption_overlay"),
				(graphics, deltaTracker) -> CorruptionOverlay.render(graphics, deltaTracker));

		ItemTooltipCallback.EVENT.register((stack, tooltipContext, tooltipFlag, lines) ->
				SoulTooltip.append(stack, lines));
	}
}
