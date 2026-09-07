# Roblox Retail Game

> This repository now contains two separate Rojo projects. The retail game remains on `default.project.json`; the existing arena-based Shooter uses `shooter.project.json` and is documented in [`shooter/README.md`](shooter/README.md). Connecting the Shooter project preserves the arena already in Studio.

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
| `src/server/RetailRoomDoors.server.luau` | Bathroom door interactions with proximity and occupied-doorway checks. |
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
local BLUEPRINT_VERSION = 55
```

When making major map changes, bump this number and also update:

- `src/server/BuildRetailMap.server.luau`

The updater has its own version. Updater v52 accepts blueprint v52 and newer, so normal map updates no longer require reinstalling the plugin. Update the plugin only when its own code changes.

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

The shelf editor lets clocked-in players select a department and product. Applying a new product returns the old shelf stock to the player's carried stock, updates the shelf, and empties it ready for restocking.

### Register System

The player register creates customer orders and tracks:

- Item count.
- Total due.
- Customer payment.
- Change due.
- Change given.
- Suggested tender.
- Opening till cash.
- Tender received, change paid, and net sales.

The client register UI disables tender buttons that would overpay the remaining change. A sale can finish only when exact change is ready.

Exact player-register sales now build a register streak. Each streak step adds a small checkout bonus, capped at `$2.00`, and clocking out resets the streak.

The store drawer starts with a `$200.00` opening till. Player and NPC sales add customer tender, subtract change paid, and update net sales so the HUD shows the drawer balance instead of only raw sales totals.

### HUD And Store Controls

The HUD dock uses image/resource buttons for:

- `HUD`: show or hide the top status panel.
- `Menu`: open the player menu.
- `Help`: open the controls panel.
- `Pets`: open pet lottery and inventory.
- `Stock`: show carried stock, low shelf, empty shelf, service bag status, and order more stock from the HUD.
- `Open/Close`: toggle whether NPC shoppers can enter.
- `Cash`: show player cash, basket value, opening till, drawer cash, tender, change, sales, and customer totals.

Players start with enough test cash to roll pets while the economy is still being tuned.

### NPC Traffic

NPC traffic uses invisible markers generated by the blueprint:

- Road spawn/approach/exit.
- Parking spots.
- Store entry markers.
- Shopping markers.
- Register queue and register spot.

NPC shoppers pick from stocked shelves, reduce shelf inventory, and complete orders through the NPC register.

In v52, shoppers use Roblox PathfindingService to walk around fixtures and use spaced, first-in-first-out checkout queue positions. Closing the store interrupts shopping routes, pauses new arrivals, and sends existing shoppers back to their cars. The HUD shows Closing until the remaining visits finish, plus the checkout queue count.

NPC baskets reserve real shelf stock. An abandoned order restores those items exactly once. If its original shelf has been reassigned or filled, the units go into returned stock and are recovered on the next stock collection. Only a valid unpaid reservation can become an NPC sale.

### Pet Lottery

The player menu includes a pet lottery using assets from `RetailAssets.luau`.

Current pet flow:

- Rolls cost `$5.00`.
- The menu shows rarity odds and rare safety progress.
- A roll awards one pet based on rarity weights.
- The lottery includes dog, cat, bunny, sprite, and dragon-style pets.
- Pet cards draw cute species-specific portraits while still showing the resource thumbnail badge.
- The first pet auto-equips.
- Players can tap owned pet cards to switch or unequip immediately, or use the resource-based equip button for the selected pet.
- Selecting a different owned pet keeps that pet selected, so switching companions works from the same equip button.
- Equipped pets spawn as multi-part companion models with faces, ears, tails, paws, and dragon wings/horns where appropriate.
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
- **Check Sync**: shows the updater version, synced blueprint version, and built map version.
- **Clear Map**: deletes the generated `RetailStore`.
- **Select Map**: selects `RetailStore` in Explorer.
- **Auto Update**: watches blueprint/catalog/HUD changes, handles Rojo reconnects, and rebuilds after sync. Rebuilds pause during Play.

Rojo must be connected before **Update Map** can use the latest local files.

Stop Play before updating. The blueprint finishes constructing the new model before replacing the old store, so gameplay scripts see a complete map. Newer blueprint versions are accepted by updater v52 without a matching plugin version number.

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

- Add a pet entry with `id`, `name`, `rarity`, `weight`, `image`, `color`, `accentColor`, `detailColor`, `species`, and size.
- Use `species` values like `dog`, `cat`, `bunny`, `sprite`, or `dragon` to change menu portraits and companion model details.
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
- Click **Check Sync**. The synced blueprint should be v52 or newer; the built map should match it after **Update Map**. The updater itself can remain v52 for newer map releases.
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

## v52 Model And Layout Fixes

- Sealed the full height of both front-window openings, including the right jamb and header gaps.
- Kept signs and small register components at their exact designed dimensions instead of snapping them onto the two-stud structural grid.
- Separated the receipt printers, drawer assemblies, and monitors; added customer mats at checkout.
- Repositioned the staff-board controls and corrected the break-room fridge, vending machine, and glass orientation.
- Moved the seasonal display out of the entrance and made the spawn marker invisible and non-colliding.
- Added a live open/closed sign by the entrance and clear NPC shopping/queue destinations.
- Corrected the office door-frame positions and service-area display refreshes.
- Fixed updater startup and blocked rebuilds during both running and paused Play tests.

## v53 Visual Pass

- Steel shop shelving, slim price rails, and individual fruit in wooden produce crates.
- Detailed checkout stations with monitor stands, working price/status displays, card readers, belt guides, and drawer trim.
- Round car tires and hubs, framed windows, painted roofs, mirrors, bumpers, and separate lights. Pickup and delivery-truck cabs no longer occupy their cargo space.
- Separated carts and bench, rebuilt wire cart baskets and slatted seating, and moved parking away from the central entrance walkway.
- Pet eye highlights, inner ears, softer dog/bunny ears, corrected tail proportions, and less luminous dragon wings. Pet switching and lottery rules are unchanged.

Connect Rojo, then use **Plugins -> Retail Game -> Update Map**. Updater v52 supports map v53; no new plugin installation is needed for this visual pass. Car and equipped-pet visuals appear during Play.

## v54 Layout Pass

- Preserved exact wall and fixture dimensions throughout the blueprint instead of rounding them onto the two-stud grid.
- Joined the back rooms into a continuous perimeter, removed the duplicate back divider, added doorway lintels, and moved room labels above their actual entrances.
- Filled the front floor strip and extended the office walls to meet the exterior shell.
- Removed obsolete bathroom and break-room props that overlapped the newer furniture. Separated counters, seating, cabinets, crates, and staging equipment across all eight perimeter rooms.
- Opened the stock-room center lane and loading-room entrance. Moved produce clear of the cooler entrance and left a continuous rear cross aisle.
- Separated pet care from the seasonal display, moved baskets beside the front wall, and placed bag holders beside checkout instead of inside the pet kiosk.
- Replaced the misplaced blue parking patches with two reserved bays nearest the entrance, each beside a separate six-stud hatched access aisle connected to the sidewalk. NPCs use the ten ordinary bays only.
- Moved the side walks clear of parked cars, lamps onto the islands, pickup paint onto the asphalt, and the dumpster away from the loading pallet.

For this update, connect the retail Rojo server at **localhost:34872**, stop any Play test, and click **Plugins -> Retail Game -> Update Map**. The map sign should read **v54 test**. Updater v52 remains compatible; no plugin reinstall is needed. Shelf, checkout, and pet rules are unchanged.

## v55 Store Expansion

- Widened the building from 120 to 152 studs, keeping its 100-stud depth and the existing fixture sizes. The sales-floor width between the side-room walls grows from 84 to 116 studs.
- Moved complete side rooms outward without stretching furniture; widened shelf spacing and aligned shopper and checkout markers with the new positions. The manager room's internal arrangement is preserved.
- Rebuilt the restroom block as two separate single-occupancy bathrooms, each with its own toilet, sink, fittings, light, and working privacy door.
- Removed the corridor gaps between pharmacy/bakery and bathroom/staff room. Each adjoining pair now shares a single wall.
- Added usable staff-room seats, a properly supported table, and room lighting. Repositioned staff controls against the new wall, reduced and wall-mounted loading signs, and refinished the dock door.
- Updated the roof, front walls/windows, parking field, fourteen ordinary parking bays, side walks, lighting islands, road edges, pickup area, and service yard to match the wider building. The two reserved entrance bays and their access aisles stay clear of NPC parking.

Use **Plugins -> Retail Game -> Update Map** with the retail Rojo connection active. Updater v52 supports this build; the map sign should read **v55 test**. Privacy doors can be opened or closed from either side. They will not finish closing through a player in the doorway. Shelf, checkout, and pet economy rules are unchanged.

## Development Checks

Install the official [Luau Windows command-line release](https://github.com/luau-lang/luau/releases) into `.tools/luau`, then run:

```powershell
.\scripts\test-retail.ps1
```

This compiles the retail scripts, tests NPC stock reservations and refunds, checks updater startup and Play/pause/stop handling, constructs all eight car styles, executes the actual blueprint with construction doubles, and builds `build.rbxlx` with Rojo. Layout checks cover window seals, fixture-to-wall clearance, principal furniture separation in nine rooms, avatar-sized entrance routes, shared walls, the wider shell/exterior, reserved parking/access aisles, and sidewalk connections. Door tests cover proximity, animation guards, interrupted closing, and cancellation recovery. These checks do not simulate Roblox physics or pathfinding. In Studio, also walk the room entrances and parking approaches, and test bathroom doors, shopper checkout, closing during a trip, reopening, shelf reassignment, and the HUD.

## GitHub

Published repository:

```text
https://github.com/Tboy450/Roblox-game
```

Main branch:

```text
main
```
