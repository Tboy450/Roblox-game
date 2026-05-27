# Roblox Retail Game

A Rojo-based Roblox Studio project for a playable retail store game. The map is generated from code, so layout changes, store props, shelves, prompts, registers, traffic markers, and exterior details can be edited in Luau and rebuilt in Studio with the custom **Retail Game** plugin.

## What Is In The Game

This project currently builds a supermarket-style store with:

- A procedural retail blueprint with exterior shell, front windows, entrance, parking lot, sidewalks, rooms, checkout lanes, shelves, signs, lighting, and service areas.
- Player work mechanics for clocking in, stocking shelves, collecting products, helping customers, cleaning spills, handling trash, pickup orders, bakery/pharmacy tasks, and register sales.
- Dynamic shelf assignment so players can choose what product a shelf should stock.
- NPC customer/traffic systems for parking, entering the store, shopping from stocked shelves, and using the NPC checkout lane.
- A resource-button HUD dock, shelf editor, register panel, player menu, and pet lottery/inventory UI.
- A pet lottery system with resource-based pet icons, rarity odds, equip/unequip, visible companion pets, and pet-care discounts.

## Important Files

| Path | Purpose |
| --- | --- |
| `src/shared/RetailStoreBlueprint.luau` | Main generated map blueprint. Builds the store model in `Workspace.RetailStore`. |
| `src/shared/RetailCatalog.luau` | Product departments, product visuals, sizes, prices, and shelf data. |
| `src/shared/RetailAssets.luau` | Button image resources, pet image resources, pet definitions, rarity weights, and roll cost. |
| `src/shared/RetailCurrency.luau` | Money formatting and register denominations. |
| `src/server/BuildRetailMap.server.luau` | Rebuilds the store on Play from the blueprint. |
| `src/server/RetailMechanics.server.luau` | Core work actions, shelf stock, shelf assignment, register sales, and store stats. |
| `src/server/RetailTraffic.server.luau` | NPC shoppers, parking spots, store pathing, and NPC checkout flow. |
| `src/server/RetailPets.server.luau` | Pet lottery, pet inventory, equip/unequip, and companion model spawning. |
| `src/client/init.client.luau` | Player HUD, shelf editor, register UI, player menu, pet lottery UI, and client event handling. |
| `plugins/BuildRetailStore.lua` | Roblox Studio plugin for updating, clearing, selecting, and auto-updating the generated map. |
| `plugins/LinkToCursor.lua` | Optional helper plugin for sending notes from Studio back to this project. |

## Blueprint Overview

The map is not hand-built in Studio. `RetailStoreBlueprint.build()` creates the store through Luau parts and models.

The blueprint handles:

- Main floor, ceiling, roof, fascia, windows, doors, and exterior wall segments.
- Back rooms: stock room, walk-in cooler, loading dock.
- Side rooms: bakery, pharmacy, restrooms, break room, and admin/staff areas.
- Sales floor zones: produce, dairy, frozen, pantry/general, household.
- Shelf units with product boards, product visuals, shelf controls, restock controls, and product selector prompts.
- Checkout front end with player register, NPC register, service desk, bagging area, task board, and time clock.
- Outdoor environment: sidewalk, parking lot, pickup spaces, landscaping, road markings, traffic markers, and service yard.

The blueprint uses a version number near the top:

```luau
local BLUEPRINT_VERSION = 48
```

When making major map changes, bump this number and also update:

- `src/server/BuildRetailMap.server.luau`
- `plugins/BuildRetailStore.lua`

That makes it obvious in Studio which map version is running.

## Game Mechanics

### Player Work Loop

Players use prompts around the store to perform jobs:

- Clock in at a time clock before most work actions.
- Grab stock from the stock room or loading pallet.
- Restock shelves when inventory is low or empty.
- Pick products into the player basket.
- Scan baskets at the player register.
- Make exact change using the register panel.
- Complete task-style interactions like spill cleanup, trash, pickup orders, bakery prep, pharmacy counter, dock controls, and temperature checks.

Player stats are created as `leaderstats`:

- `Cash`
- `Basket`
- `BasketValue`
- `Stock`
- `Tasks`
- `Shift`
- `Customers`
- `Pets`
- `StockOrders`
- `RegisterStreak`

### Shelf Assignment

Shelves are generated from `RetailCatalog` departments and products.

Each shelf has:

- `ShelfControl` prompt: opens the shelf editor.
- `RestockControl` prompt: restocks the current product.
- `ProductSelector` prompt: lets players take the shelf item.
- `TopSign`: shows the current department and product.

The shelf editor lets players select a department and product. Applying a new product updates shelf attributes and visuals, then empties the shelf so it needs restocking.

### Register System

The player register creates customer orders and tracks:

- Item count.
- Total due.
- Customer payment.
- Change due.
- Change given.
- Suggested tender.

The client register UI disables tender buttons that would overpay the remaining change. A sale can finish only when exact change is ready.

Exact player-register sales now build a register streak. Each streak step adds a small checkout bonus, capped at `$2.00`, and clocking out resets the streak.

### HUD And Store Controls

The HUD dock uses image/resource buttons for:

- `HUD`: show or hide the top status panel.
- `Menu`: open the player menu.
- `Help`: open the controls panel.
- `Pets`: open pet lottery and inventory.
- `Stock`: show carried stock, low shelf, empty shelf, service bag status, and order more stock from the HUD.
- `Open/Close`: toggle whether NPC shoppers can enter.
- `Cash`: show player cash, basket value, till cash, and customer totals.

Players start with enough test cash to roll pets while the economy is still being tuned.

### NPC Traffic

NPC traffic uses invisible markers generated by the blueprint:

- Road spawn/approach/exit.
- Parking spots.
- Store entry markers.
- Shopping markers.
- Register queue and register spot.

NPC shoppers pick from stocked shelves, reduce shelf inventory, and complete orders through the NPC register.

### Pet Lottery

The player menu includes a pet lottery using assets from `RetailAssets.luau`.

Current pet flow:

- Rolls cost `$5.00`.
- The menu shows rarity odds and rare safety progress.
- A roll awards one pet based on rarity weights.
- The first pet auto-equips.
- Players can select owned pets in the menu and equip or unequip them.
- Selecting a different owned pet keeps that pet selected, so switching companions works from the same equip button.
- Equipped pets spawn as a small companion model near the character with a resource icon badge.
- Pet care can be triggered from the pet menu or care station to discount the next roll, and some equipped pets improve that discount.

Pet definitions live in:

```text
src/shared/RetailAssets.luau
```

Add or rebalance pets by editing the `RetailAssets.pets` table.

## Rojo And Studio Workflow

### One-Time Setup

Install local tools if `.tools/` is missing:

```powershell
.\setup.ps1
```

Install the Rojo Studio plugin:

1. Open Roblox Studio.
2. Go to **Plugins -> Plugins Folder**.
3. Copy `plugins/Rojo.rbxm` into that folder.
4. Restart Roblox Studio.

Or install Rojo from Roblox's plugin marketplace.

### Daily Development

Start Rojo:

```powershell
.\scripts\serve.ps1
```

Or start Rojo plus the optional Studio message bridge:

```powershell
.\scripts\dev.ps1
```

Then in Roblox Studio:

1. Open a blank/baseplate place.
2. Open the Rojo plugin.
3. Connect to `localhost:34872`.
4. Confirm `ReplicatedStorage.Shared`, `ServerScriptService.Server`, and `StarterPlayerScripts.Client` are synced.
5. Press **Play** to test, or use the custom map updater plugin.

### Build A Place File

To build an `.rbxlx` place file from the project:

```powershell
.\scripts\build.ps1
```

Output:

```text
build.rbxlx
```

The build output is ignored by git. Source files are the real project.

## Retail Game Studio Plugin

The custom plugin is:

```text
plugins/BuildRetailStore.lua
```

In Studio, it appears under **Plugins -> Retail Game**.

Buttons:

- **Update Map**: rebuilds `Workspace.RetailStore` from the latest Rojo-synced blueprint.
- **Check Sync**: shows the updater plugin version and the Rojo-synced blueprint version.
- **Clear Map**: deletes the generated `RetailStore`.
- **Select Map**: selects `RetailStore` in Explorer.
- **Auto Update**: watches blueprint/catalog changes and rebuilds after Rojo syncs.

Rojo must be connected before **Update Map** can use the latest local files.

### Updating The Plugin

If you edit `plugins/BuildRetailStore.lua`, copy it into your Roblox plugins folder and restart Studio:

```powershell
Copy-Item -LiteralPath ".\plugins\BuildRetailStore.lua" "$env:LOCALAPPDATA\Roblox\Plugins\BuildRetailStore.lua" -Force
```

If the copy fails, Roblox Studio probably has the plugin file locked. Close Studio, run the copy command again, then reopen Studio.

## Adding More Content

### Add Products

Edit `src/shared/RetailCatalog.luau`:

- Add products to a department.
- Set product color, material, size, and price.
- Shelves and NPC orders will use the catalog automatically.

### Add Pets

Edit `src/shared/RetailAssets.luau`:

- Add a pet entry with `id`, `name`, `rarity`, `weight`, `image`, colors, and size.
- Higher `weight` means more common.
- The client menu and server lottery read this shared table.

### Change The Store Layout

Edit `src/shared/RetailStoreBlueprint.luau`:

- Move parts by changing positions and sizes.
- Keep checkout/front entry clear before adding new props.
- Avoid overlapping floor slabs at the same height because Roblox may flicker between surfaces.
- Prefer non-colliding overlay markers for visual floor zones.

After edits:

```powershell
.\.tools\rojo\rojo.exe build default.project.json -o build.rbxlx
```

Then connect Rojo in Studio and click **Retail Game -> Update Map**.

## Troubleshooting

### Update Map Uses Old Code

- Make sure Rojo is connected.
- Click **Check Sync**. The plugin version and Rojo blueprint version should match.
- Save the file in your editor.
- Restart Studio if the plugin itself was changed.
- Check the map version sign in front of the store.

### Plugin Copy Fails

Close Roblox Studio and retry:

```powershell
Copy-Item -LiteralPath ".\plugins\BuildRetailStore.lua" "$env:LOCALAPPDATA\Roblox\Plugins\BuildRetailStore.lua" -Force
```

### Map Looks Like Parts Are Flickering

This usually means two parts occupy the same plane. Check floor/sidewalk/paint pieces first. Use thin non-colliding overlays slightly above the surface instead of full duplicate slabs.

### Rojo Is Missing

Run:

```powershell
.\setup.ps1
```

### Rebuild From Scratch In Studio

1. Connect Rojo.
2. Click **Retail Game -> Clear Map**.
3. Click **Retail Game -> Update Map**.
4. Press **Play** to test mechanics.

## GitHub

Published repository:

```text
https://github.com/Tboy450/Roblox-game
```

Main branch:

```text
main
```
