package com.soulcorruption.data;

/** Gespeicherter Zustand eines Spielers. */
public final class PlayerSoulRecord {
	/** Zuletzt bekannter Spielername (für /soul top). */
	public String name = "?";
	/** Eigene Seelen-Bilanz. */
	public int souls;
	/** Insgesamt gestohlene Seelen (Statistik). */
	public int totalStolen;
	/** Unix-Millisekunden, bis zu denen der Spieler gebannt ist (0 = nicht gebannt). */
	public long bannedUntil;

	public boolean isBanned() {
		return bannedUntil > System.currentTimeMillis();
	}
}
