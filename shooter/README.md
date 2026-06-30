# Shooter

This is the Rojo code project for the existing **Shooter** place in Roblox Studio.

The arena already in Studio remains authoritative. `shooter.project.json` deliberately manages no children of `Workspace`, so connecting Rojo will not replace or delete the existing map.

## Included Systems

- An adaptive `ShooterExpansion` with a bunker, elevated overlook, stairs, cover, barriers, and a labeled two-way teleporter between the small former-spawn room and the existing room across from `Workspace.Shop`. It builds beside the existing arena instead of replacing it and does not add competing spawn points.
- A working weapon shop beside `Workspace.Shop`, with Credits, server-validated purchases, ammo refills, the five existing arena Tools, and three new weapons.
- Server-authoritative Hand Cannon, Pulse Rifle, and Scattergun weapons with ammo, reloads, tracers, headshots, and KO/death stats.
- Repaired every sibling `p1`/`p2` or `pt1`/`pt2` set with anti-bounce cooldowns, including duplicate tiles on different floors, plus automatic pairing for models inside `Workspace.Teleporters`.
- Solid collision across all six red, green, and blue surfaces in `Workspace.Obby Part`.
- A separate **Shooter** Studio updater plugin that manages `Workspace.ShooterExpansion` and permanently removes broken legacy portal scripts without replacing the original arena.

Start the connection with:

```powershell
.\scripts\serve-shooter.ps1
```

Then connect the Rojo Studio plugin to `localhost:34872` and select **Shooter**.

Build a place file with:

```powershell
.\scripts\build-shooter.ps1
```

## Shooter Studio Plugin

Install the updater:

```powershell
Copy-Item -LiteralPath ".\plugins\BuildShooter.lua" "$env:LOCALAPPDATA\Roblox\Plugins\BuildShooter.lua" -Force
```

Restart Studio after installing it. The **Shooter** toolbar includes:

- **Update Expansion**: rebuild only `Workspace.ShooterExpansion` beside the existing map.
- **Check Systems**: verify the Shooter Bootstrap, existing shop, and `p1`/`p2` portals.
- **Repair Portals**: permanently remove broken legacy scripts inside every named portal tile; the Rojo server then pairs each sibling set between floors.
- **Repair Bridge**: permanently make all red, green, and blue bridge surfaces solid.
- **Select Expansion**: select the generated addition in Explorer.
- **Clear Expansion**: remove only the addition, leaving the original arena untouched.
- **Auto Update**: rebuild the addition after `ArenaExpansion` changes through Rojo.

## Play Controls

- Equip weapons from the Backpack or number keys.
- Left click / right trigger fires.
- `R` reloads.
- Use the prompt beside the existing shop to open the loadout store.
- Walk onto either portal in a paired set to teleport.
