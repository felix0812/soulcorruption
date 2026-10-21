package com.soulcorruption.config;

import com.soulcorruption.config.SoulConfig.EffectEntry;

import java.util.ArrayList;
import java.util.List;

/**
 * Eine Korruptionsstufe. Aktiv, sobald der Korruptionswert eines Spielers
 * {@link #threshold} erreicht.
 */
public final class CorruptionTier {
	public String name = "Rein";
	/** Farbe des Stufennamens (ChatFormatting-Name, z.B. "dark_purple"). */
	public String color = "gray";
	public int threshold = 0;

	/** Dauerhafte Buffs. */
	public List<EffectEntry> buffs = new ArrayList<>();
	/** Dauerhafte Debuffs. */
	public List<EffectEntry> debuffs = new ArrayList<>();
	/** Debuffs, die nur gelegentlich (pulsartig) auftreten. */
	public List<EffectEntry> pulseDebuffs = new ArrayList<>();
	/** Chance pro Sekunde, dass ein Puls-Debuff ausgelöst wird. */
	public double pulseChance = 0.0;

	/** Chance pro Sekunde für eine Halluzination. */
	public double hallucinationChance = 0.0;
	/** Erlaubt kleine Teleports als Halluzination. */
	public boolean hallucinationTeleports = false;

	// Clientseitige Darstellung
	/** Partikel-Dichte (0 = keine). */
	public float particleDensity = 0.0f;
	/** Deckkraft des dunklen Overlays (0..1). */
	public float overlayStrength = 0.0f;

	public CorruptionTier() {
	}

	static List<CorruptionTier> defaults() {
		List<CorruptionTier> list = new ArrayList<>();

		CorruptionTier pure = new CorruptionTier();
		pure.name = "Rein";
		pure.color = "gray";
		pure.threshold = 0;
		list.add(pure);

		CorruptionTier stained = new CorruptionTier();
		stained.name = "Befleckt";
		stained.color = "dark_aqua";
		stained.threshold = 3;
		stained.buffs.add(new EffectEntry("minecraft:speed", 0));
		stained.pulseDebuffs.add(new EffectEntry("minecraft:hunger", 0));
		stained.pulseChance = 0.01;
		stained.particleDensity = 0.08f;
		stained.overlayStrength = 0.10f;
		list.add(stained);

		CorruptionTier tainted = new CorruptionTier();
		tainted.name = "Verdorben";
		tainted.color = "dark_purple";
		tainted.threshold = 8;
		tainted.buffs.add(new EffectEntry("minecraft:speed", 0));
		tainted.buffs.add(new EffectEntry("minecraft:strength", 0));
		tainted.debuffs.add(new EffectEntry("minecraft:glowing", 0));
		tainted.pulseDebuffs.add(new EffectEntry("minecraft:hunger", 1));
		tainted.pulseDebuffs.add(new EffectEntry("minecraft:darkness", 0));
		tainted.pulseChance = 0.02;
		tainted.hallucinationChance = 0.005;
		tainted.particleDensity = 0.2f;
		tainted.overlayStrength = 0.22f;
		list.add(tainted);

		CorruptionTier possessed = new CorruptionTier();
		possessed.name = "Besessen";
		possessed.color = "dark_red";
		possessed.threshold = 15;
		possessed.buffs.add(new EffectEntry("minecraft:strength", 1));
		possessed.buffs.add(new EffectEntry("minecraft:resistance", 0));
		possessed.buffs.add(new EffectEntry("minecraft:night_vision", 0));
		possessed.debuffs.add(new EffectEntry("minecraft:glowing", 0));
		possessed.pulseDebuffs.add(new EffectEntry("minecraft:nausea", 0));
		possessed.pulseDebuffs.add(new EffectEntry("minecraft:darkness", 0));
		possessed.pulseDebuffs.add(new EffectEntry("minecraft:weakness", 0));
		possessed.pulseChance = 0.03;
		possessed.hallucinationChance = 0.02;
		possessed.hallucinationTeleports = true;
		possessed.particleDensity = 0.45f;
		possessed.overlayStrength = 0.35f;
		list.add(possessed);

		CorruptionTier lost = new CorruptionTier();
		lost.name = "Verloren";
		lost.color = "black";
		lost.threshold = 25;
		lost.buffs.add(new EffectEntry("minecraft:strength", 2));
		lost.buffs.add(new EffectEntry("minecraft:speed", 1));
		lost.buffs.add(new EffectEntry("minecraft:resistance", 1));
		lost.debuffs.add(new EffectEntry("minecraft:glowing", 0));
		lost.debuffs.add(new EffectEntry("minecraft:hunger", 1));
		lost.pulseDebuffs.add(new EffectEntry("minecraft:wither", 0));
		lost.pulseDebuffs.add(new EffectEntry("minecraft:nausea", 0));
		lost.pulseDebuffs.add(new EffectEntry("minecraft:blindness", 0));
		lost.pulseChance = 0.05;
		lost.hallucinationChance = 0.04;
		lost.hallucinationTeleports = true;
		lost.particleDensity = 0.8f;
		lost.overlayStrength = 0.5f;
		list.add(lost);

		return list;
	}
}
