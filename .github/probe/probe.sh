#!/usr/bin/env bash
# Temporary API probe: prints class signatures from the Minecraft/Fabric jars used by Loom.
set +e
JARS=$(find ~/.gradle/caches -name "*.jar" 2>/dev/null)
findjar() { for j in $JARS; do unzip -l "$j" 2>/dev/null | grep -q " $1.class$" && { echo "$j"; return; }; done; }
p() { local j; j=$(findjar "$1"); echo "=== $1 ($j)"; [ -n "$j" ] && javap -cp "$j" "${1//\//.}" | grep -E "$2"; }
MC=$(findjar net/minecraft/world/entity/EntityType)
echo "MC jar: $MC"
unzip -l "$MC" | grep -E "world/inventory/[A-Z][A-Za-z]*\.class|monster/.*Vex|Vex\.class" | awk '{print $4}'
p net/minecraft/world/inventory/AbstractContainerMenu "clicked|quickMove|sendAllData"
p net/minecraft/world/entity/EntityType "VEX|Vex|ZOMBIE |create\("
p net/minecraft/world/entity/Entity "Tag|setId|lookAt|noPhysics|setGlowing"
p net/minecraft/ChatFormatting "static"
p net/minecraft/world/entity/LivingEntity "randomTeleport|getLastHurt"
p net/minecraft/server/level/ServerPlayer "drop\(|sendSystemMessage|displayClientMessage"
p net/minecraft/world/entity/player/Player "drop\(|displayClientMessage"
p net/fabricmc/fabric/api/networking/v1/PayloadTypeRegistry "static|register"
p net/minecraft/client/gui/GuiGraphics "fill|guiWidth|guiHeight"
p net/minecraft/client/multiplayer/ClientLevel "addEntity|removeEntity|playLocalSound"
p net/minecraft/client/DeltaTracker "Partial"
p net/fabricmc/fabric/api/client/rendering/v1/hud/HudElementRegistry "static"
p net/fabricmc/fabric/api/client/rendering/v1/hud/HudElement "render|void"
p net/fabricmc/fabric/api/client/item/v1/ItemTooltipCallback "void"
p net/fabricmc/fabric/api/client/networking/v1/ClientPlayNetworking "registerGlobalReceiver"
p net/minecraft/client/Minecraft "setScreen|public .*options|isPaused|public .*gui;"
p net/minecraft/world/entity/monster/Vex "public"
