extends Node2D

@onready var nodes_container: Node2D = $Nodes
@onready var lines_container: Node2D = $Lines
@onready var generator:       Node   = $NetworkGenerator
@onready var grid_manager:    Node   = $GridManager

func _ready():
	var result = generator.generate(nodes_container, lines_container)
	grid_manager.setup(result.nodes, result.lines)
