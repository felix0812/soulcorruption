package com.soulcorruption.client;

import com.soulcorruption.network.SoulSyncPayload;

/** Vom Server synchronisierter Zustand des lokalen Spielers. */
public final class ClientSoulState {
	private static int souls;
	private static int corruption;
	private static int tier;
	private static float particleDensity;
	private static float overlayStrength;

	private ClientSoulState() {
	}

	static void update(SoulSyncPayload payload) {
		souls = payload.souls();
		corruption = payload.corruption();
		tier = payload.tier();
		particleDensity = payload.particleDensity();
		overlayStrength = payload.overlayStrength();
	}

	static void reset() {
		souls = 0;
		corruption = 0;
		tier = 0;
		particleDensity = 0;
		overlayStrength = 0;
	}

	public static int souls() {
		return souls;
	}

	public static int corruption() {
		return corruption;
	}

	public static int tier() {
		return tier;
	}

	public static float particleDensity() {
		return particleDensity;
	}

	public static float overlayStrength() {
		return overlayStrength;
	}
}
