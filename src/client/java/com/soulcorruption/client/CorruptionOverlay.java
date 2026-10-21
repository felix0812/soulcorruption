package com.soulcorruption.client;

import net.minecraft.client.DeltaTracker;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphicsExtractor;
import net.minecraft.util.Mth;

/**
 * Zeichnet eine dunkle, pulsierende Vignette – je stärker die Korruption, desto dunkler.
 * Zusätzlich ein kurzes rotes Flackern bei Halluzinationen.
 */
public final class CorruptionOverlay {
	private static int flashTicks;
	private static float smoothedStrength;

	private CorruptionOverlay() {
	}

	/** Startet ein kurzes rotes Flackern. */
	static void flash(int ticks) {
		flashTicks = Math.max(flashTicks, ticks);
	}

	static void tick() {
		if (flashTicks > 0) {
			flashTicks--;
		}
		// Weicher Übergang zwischen Stufen statt hartem Sprung
		smoothedStrength = Mth.lerp(0.05f, smoothedStrength, ClientSoulState.overlayStrength());
	}

	static void render(GuiGraphicsExtractor graphics, DeltaTracker deltaTracker) {
		Minecraft mc = Minecraft.getInstance();
		if (mc.player == null) {
			return;
		}

		int width = graphics.guiWidth();
		int height = graphics.guiHeight();
		float time = mc.player.tickCount + deltaTracker.getGameTimeDeltaPartialTick(false);

		if (smoothedStrength > 0.005f) {
			// Langsames "Atmen" der Dunkelheit
			float pulse = 0.85f + 0.15f * Mth.sin(time * 0.05f);
			float strength = Mth.clamp(smoothedStrength * pulse, 0f, 0.9f);

			int edge = argb(strength, 0x10, 0x00, 0x18);
			int clear = argb(0f, 0x10, 0x00, 0x18);
			int band = Math.max(1, (int) (height * (0.25f + strength * 0.35f)));
			int side = Math.max(1, (int) (width * (0.15f + strength * 0.25f)));

			// Vignette: oben, unten, links, rechts
			graphics.fillGradient(0, 0, width, band, edge, clear);
			graphics.fillGradient(0, height - band, width, height, clear, edge);
			for (int i = 0; i < side; i += 2) {
				float t = 1f - (float) i / side;
				int color = argb(strength * t * t, 0x10, 0x00, 0x18);
				graphics.fill(i, 0, i + 2, height, color);
				graphics.fill(width - i - 2, 0, width - i, height, color);
			}
			// Leichter Gesamtschleier
			graphics.fill(0, 0, width, height, argb(strength * 0.25f, 0x05, 0x00, 0x0A));
		}

		if (flashTicks > 0) {
			float alpha = Math.min(0.45f, flashTicks / 20f);
			graphics.fill(0, 0, width, height, argb(alpha, 0x80, 0x00, 0x00));
		}
	}

	private static int argb(float alpha, int r, int g, int b) {
		int a = Mth.clamp((int) (alpha * 255), 0, 255);
		return a << 24 | r << 16 | g << 8 | b;
	}
}
