#!/usr/bin/env bash
# Temporary API probe: prints class signatures from the Minecraft/Fabric jars used by Loom.
set +e
JARS=$(find ~/.gradle/caches -name "*.jar" 2>/dev/null)
findjar() { for j in $JARS; do unzip -l "$j" 2>/dev/null | grep -q " $1.class$" && { echo "$j"; return; }; done; }
p() { local j; j=$(findjar "$1"); echo "=== $1 ($j)"; [ -n "$j" ] && javap -cp "$j" "${1//\//.}" | grep -E "$2"; }
MC=$(findjar net/minecraft/world/entity/EntityType)
CL=$(findjar net/minecraft/client/Minecraft)
unzip -l "$MC" | awk '{print $4}' | grep -E "^net/minecraft/world/entity/[A-Za-z]*Types?\.class|EntityTypes"
unzip -l "$CL" | awk '{print $4}' | grep -E "gui/GuiGraphics"
p net/minecraft/world/inventory/ContainerInput "static|public"
p net/minecraft/world/entity/EntityTypes "VEX|ZOMBIE;|SKELETON;|CREEPER;|ENDERMAN;|WITCH;"
p net/minecraft/ChatFormatting "public [a-z].*\(\);"
p net/minecraft/client/gui/GuiGraphicsExtractor "fill|guiWidth|guiHeight|public .*\(int, int, int, int, int"
p net/minecraft/client/Options "hideGui"
p net/minecraft/sounds/SoundEvents "CREEPER_PRIMED|ZOMBIE_AMBIENT|ENDERMAN_STARE|WARDEN_HEARTBEAT|SKELETON_AMBIENT|WOODEN_DOOR_OPEN|SOUL_ESCAPE|SCULK_SHRIEKER_SHRIEK|EVOKER_PREPARE_SUMMON|VILLAGER_NO"
p net/minecraft/commands/Commands "hasPermission|LEVEL_GAMEMASTERS"
p net/minecraft/core/particles/ParticleTypes " SOUL|SCULK_SOUL|SMOKE;|SOUL_FIRE_FLAME"
