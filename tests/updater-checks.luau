assert(#warnings == 0, "Updater must initialize without runtime errors")
for _, testMode in { "running", "paused" } do
	mode = testMode
	buttons["Update Map"].Click:Fire()
	assert(warnings[#warnings]:find("Stop the play test"), "Update must refuse active and paused tests")
	buttons["Clear Map"].Click:Fire()
	assert(warnings[#warnings]:find("Stop the play test"), "Clear must refuse active and paused tests")
end
assert(waypoints == 0, "Play-mode guards must run before edit-mode mutations")
buttons["Auto Update"].Click:Fire()
flush()
assert(waypoints == 0, "Enabling auto-update while paused must not rebuild")
mode = "running"
runStateChanged:Fire()
flush()
assert(waypoints == 0, "Resuming Play must not rebuild")
mode = "edit"
runStateChanged:Fire()
assert(#delayed == 1, "Stopping Play must queue one edit-mode refresh")
flush()
assert(waypoints == 1, "Edit mode must attempt the queued update")
assert(warnings[#warnings]:find("Connect Rojo first"), "Missing sync must be reported clearly")
runStateChanged:Fire()
plugin.Unloading:Fire()
flush()
assert(waypoints == 1, "Unloading must cancel queued rebuilds")
print("PASS: updater startup, running/paused guards, stop-to-edit refresh, unload cancellation")
