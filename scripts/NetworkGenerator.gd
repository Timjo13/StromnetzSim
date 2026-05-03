extends Node

const NODE_SCENE = preload("res://scenes/GridNode.tscn")

const NETWORK_NODES = [
	{"name": "Gen_Kohle",  "type": 0, "power": 30.0, "pos": Vector2(180, 200)},
	{"name": "Gen_Gas",    "type": 0, "power": 20.0, "pos": Vector2(680, 130)},
	{"name": "Gen_Wind",   "type": 0, "power": 15.0, "pos": Vector2(900, 300)},
	{"name": "Gen_Solar",  "type": 0, "power": 20.0, "pos": Vector2(680, 560)},
	{"name": "Stadt_A",    "type": 1, "power": 18.0, "pos": Vector2(400, 150)},
	{"name": "Stadt_B",    "type": 1, "power": 14.0, "pos": Vector2(300, 380)},
	{"name": "Industrie",  "type": 1, "power": 22.0, "pos": Vector2(600, 350)},
	{"name": "Vorort",     "type": 1, "power":  8.0, "pos": Vector2(800, 480)},
	{"name": "Bahnhof",    "type": 1, "power": 12.0, "pos": Vector2(500, 500)},
]

const NETWORK_LINES = [
	{"from": "Gen_Kohle",  "to": "Stadt_A",   "capacity": 25.0},
	{"from": "Gen_Kohle",  "to": "Stadt_B",   "capacity": 20.0},
	{"from": "Gen_Gas",    "to": "Stadt_A",   "capacity": 20.0},
	{"from": "Gen_Gas",    "to": "Industrie", "capacity": 25.0},
	{"from": "Gen_Wind",   "to": "Industrie", "capacity": 15.0},
	{"from": "Gen_Wind",   "to": "Vorort",    "capacity": 12.0},
	{"from": "Stadt_A",    "to": "Stadt_B",   "capacity": 15.0},
	{"from": "Stadt_A",    "to": "Industrie", "capacity": 18.0},
	{"from": "Industrie",  "to": "Vorort",    "capacity": 12.0},
	{"from": "Industrie",  "to": "Bahnhof",   "capacity": 14.0},
	{"from": "Stadt_B",    "to": "Bahnhof",   "capacity": 10.0},
	{"from": "Gen_Solar",  "to": "Bahnhof",   "capacity": 15.0},
	{"from": "Gen_Solar",  "to": "Vorort",    "capacity": 12.0},
]

func generate(nodes_container: Node, lines_container: Node) -> Dictionary:
	# Alte Nodes sofort entfernen (nicht queue_free)
	for child in nodes_container.get_children():
		nodes_container.remove_child(child)
		child.free()
	for child in lines_container.get_children():
		lines_container.remove_child(child)
		child.free()

	var node_refs = {}
	var spawned_nodes = []
	var spawned_lines = []

	# Knoten spawnen
	for data in NETWORK_NODES:
		var node = NODE_SCENE.instantiate()
		node.name        = data["name"]
		node.node_type   = data["type"]
		node.power_value = data["power"]
		node.position    = data["pos"]
		nodes_container.add_child(node)
		node_refs[data["name"]] = node
		spawned_nodes.append(node)

	# Leitungen spawnen
	for data in NETWORK_LINES:
		var na = node_refs.get(data["from"])
		var nb = node_refs.get(data["to"])
		if not na or not nb:
			push_warning("Leitung: Node nicht gefunden – %s oder %s" % [data["from"], data["to"]])
			continue

		var line = Line2D.new()
		line.name = "Line_%s_%s" % [data["from"], data["to"]]
		line.set_script(load("res://scripts/GridLine.gd"))
		lines_container.add_child(line)

		line.node_a       = na
		line.node_b       = nb
		line.max_capacity = data["capacity"]
		line.clear_points()
		line.add_point(na.position)
		line.add_point(nb.position)
		spawned_lines.append(line)

	print("Netz generiert: %d Knoten, %d Leitungen" % [spawned_nodes.size(), spawned_lines.size()])
	return {"nodes": spawned_nodes, "lines": spawned_lines}
