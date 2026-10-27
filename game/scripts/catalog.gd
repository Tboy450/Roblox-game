extends RefCounted
## Prices and supplier costs are integer cents; stable IDs are used in saves.
const IDS := ["beans", "oats", "soap"]
const PRODUCTS := {
	"beans": {"name": "Harvest Beans", "short": "Beans", "department": "PANTRY", "cost": 70, "price": 149, "color": "c17b38", "shelf_x": -7.0},
	"oats": {"name": "Morning Oats", "short": "Oats", "department": "BREAKFAST", "cost": 110, "price": 249, "color": "d6b967", "shelf_x": 0.0},
	"soap": {"name": "Cedar Hand Soap", "short": "Soap", "department": "HOUSEHOLD", "cost": 125, "price": 299, "color": "568c8c", "shelf_x": 7.0},
}
