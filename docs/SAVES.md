# Saved progress and recovery

The standalone game uses a version-3 JSON save in Godot's Cornerfield Market user-data directory. `cornerfield-save.json` is the primary; `.bak` retains the previous valid save. **F5** saves, **F9** loads. Startup loads existing progress automatically. Transactions trigger a short debounced autosave, and normal window close saves synchronously. A forced process kill can lose changes since the last completed save.

## What survives restart

- Cash, day, opening cash, daily revenue, cost of goods, purchases, sold units and walkouts.
- Separate product stock, editable prices, one-to-one shelf assignments and the next order ID.
- Partly carried cases, receiving cases, incoming product and remaining delivery time.
- Whether a closed-day report was ready; its totals are reconstructed from the ledger.

Resume starts with the store closed and the player at the entrance. Transient shopper positions and paths are not saved. Unpaid basket units are included in saved shelf stock, without changing the running game or counting a restart as a walkout. Loading clears transient shoppers and reservations, so repeated loads do not create extra units. Open the store with O to continue that day, or N after a saved closed-day report to begin the next day.

## File replacement and recovery

The writer validates the snapshot, writes and flushes a temporary file, reads it back, retains the prior valid primary as a backup, then renames the new file over the primary. If the current primary is damaged, it does not overwrite an existing good backup with that damaged data. Write/rename errors return failure and leave prior progress available. This is a local single-writer save system; concurrent game instances are not supported.

Loading validates the complete document before assigning live fields. It checks schema version, product IDs, integer-cent fields, cash reconciliation, capacities, case types and delivery timing. If the primary is damaged or missing, loading tries the backup and reports recovery. If both fail, current progress remains unchanged and autosaving pauses. F5 explicitly retries saving current progress; F9 retries loading. A future schema is rejected without falling back to an older backup or allowing this older game to overwrite it.

Older saves migrate automatically, preserving stock, cash, prices, deliveries, day totals and any shelf swaps. Version 1 gains the original shelf mapping. Each catalog product records the save version that introduced it, so a version-1 or version-2 save gains Meadow Honey with no stock, its default price and its own middle-row shelf. An older save that already lists a later product is rejected rather than guessed at. The next successful write uses version 3, which older game builds treat as a newer, protected save. Checked-in version-1 and version-2 fixtures verify migration. Future schema changes need additional explicit migrations. Saves are local single-player data, not an authority for future multiplayer accounts.

Control preferences use a separate `cornerfield-settings.cfg` file. Sensitivity, movement speed, UI scale, guide visibility, collapsed panel states and key bindings are validated before applying them. Bindings must give every action its own supported physical key and never use Esc, Tab or F2; otherwise the whole file is rejected. They are not rolled back by loading store progress. Missing new preference fields receive defaults, including a compact dashboard. Esc pauses simulation time and the autosave countdown; manual save/load remain available in the pause menu. Save and quit stays in the menu if writing progress fails.

The first-day guide derives its next action from existing inventory, deliveries, sales, report and day data. It needs no new gameplay save version. Loading a partly completed day resumes useful guidance; later days hide the introductory guide.

Automated tests use unique ignored directories under `builds/`, and scripted reviews/package smoke tests disable persistence. They do not read or overwrite the player's save.
