extends RefCounted
## Prices and supplier costs are integer cents; stable IDs are used in saves.
## Models are Blender packaging GLBs in metres, base centred at the origin.
## Each product's ID also names its home shelf slot at (shelf_x, shelf_z); "since"
## is the save version that introduced it, so older saves can gain it on load.
const IDS := ["beans", "oats", "soap", "honey"]
const PRODUCTS := {
	"beans": {"name": "Harvest Beans", "short": "Beans", "department": "PANTRY", "cost": 70, "price": 149, "color": "c17b38", "shelf_x": -7.0, "shelf_z": 4.0, "model": "merch-beans.glb", "since": 1},
	"oats": {"name": "Morning Oats", "short": "Oats", "department": "BREAKFAST", "cost": 110, "price": 249, "color": "d6b967", "shelf_x": 0.0, "shelf_z": 4.0, "model": "merch-oats.glb", "since": 1},
	"soap": {"name": "Cedar Hand Soap", "short": "Soap", "department": "HOUSEHOLD", "cost": 125, "price": 299, "color": "568c8c", "shelf_x": 7.0, "shelf_z": 4.0, "model": "merch-soap.glb", "since": 1},
	"honey": {"name": "Meadow Honey", "short": "Honey", "department": "SPREADS", "cost": 180, "price": 399, "color": "d89a2b", "shelf_x": -7.0, "shelf_z": 0.0, "model": "merch-honey.glb", "since": 3},
}
