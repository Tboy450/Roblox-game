# roblox-game

Edit Luau in Cursor, sync into Roblox Studio with [Rojo](https://rojo.space/).

## One-time setup

1. **Roblox Studio** — install and sign in.
2. **Rojo plugin in Studio** — Plugins → Plugin Folder → copy `plugins/Rojo.rbxm` into that folder, restart Studio.  
   Or install from the [Rojo plugin page](https://create.roblox.com/marketplace/asset/13916111004/Rojo).
3. **Cursor** — open this folder (`File → Open Folder`).
4. **CLI tools** (if `.tools/` is missing):

   ```powershell
   .\setup.ps1
   ```

5. Optional: install recommended extensions when Cursor prompts (Rojo, StyLua, Selene).

## Daily workflow

1. In Cursor terminal (Rojo + link bridge):

   ```powershell
   .\scripts\dev.ps1
   ```

   Or only Rojo: `.\scripts\serve.ps1`

2. Open Roblox Studio → **Baseplate** or a blank place.
3. **Game Settings → Security → Allow HTTP Requests** (needed for link).
4. Rojo plugin → **Connect** (default `localhost:34872`).
5. Edit files under `src/` — changes sync into Studio.
6. Press **Play** in Studio to test.

## Map updater plugin

After `.\setup.ps1` installs plugins and Studio restarts, use **Plugins -> Retail Game**:

- **Update Map** rebuilds `Workspace.RetailStore` from the latest Rojo-synced blueprint.
- **Clear Map** removes the generated map from Workspace.
- **Select Map** selects `RetailStore` in Explorer.
- **Auto Update** watches `RetailStoreBlueprint` and rebuilds after Rojo syncs changes.

Rojo must be connected before Update Map or Auto Update can use the blueprint.

## Link command (talk to Cursor from Studio)

Studio cannot open Cursor chat directly. The **link** plugin sends notes to a file in this project.

1. Run `.\scripts\dev.ps1` in Cursor (starts bridge on port `8765`).
2. Restart Studio once after `.\setup.ps1` (installs **LinkToCursor** plugin).
3. In Studio: **Plugins** tab → **Link** (opens the panel at the bottom).
4. Type your message (optional prefix `link `), press **Enter** or click **link**.
5. In **Cursor chat**, say: `read pending` (or keep this chat open — hooks may auto-continue).

### Auto-read (background)

With `.\scripts\dev.ps1` running:

- Studio messages create `.studio/pending.md` + a Windows notification
- Project hooks (`.cursor/hooks.json`) can auto-submit a follow-up when an agent chat is active
- Rule `.cursor/rules/studio-link.mdc` tells the agent to process pending messages

**Limitation:** Cursor cannot run the agent with zero interaction unless you use the [Cursor SDK](https://cursor.com/docs/api/sdk/typescript) with an API key. For fully unattended runs, set `CURSOR_API_KEY` and we can add an optional `scripts/auto-agent.ts` later.

From terminal:

```powershell
.\scripts\link.ps1 "Add a red spawn platform"
```

## Project layout

| Path | Maps to Studio |
|------|----------------|
| `src/server/` | ServerScriptService → Server |
| `src/client/` | StarterPlayerScripts → Client |
| `src/shared/` | ReplicatedStorage → Shared |

- `*.server.luau` → Script (runs on server)
- `*.client.luau` → LocalScript (runs on client)
- Other `*.luau` → ModuleScript

## Packages (Wally)

```powershell
.\.tools\wally\wally.exe install
```

Add dependencies in `wally.toml`, then sync with Rojo.

## Build a place file

```powershell
.\scripts\build.ps1
```

Outputs `build.rbxlx` you can open in Studio.
