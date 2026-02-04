package main

MAX_ENTITIES :: 100

EntityKind :: enum {
	nil,
	Light,
	Cube,
}

EntityHandle :: struct {
	id:       int,
	index:    int,
	position: Vec3,
}

Entity :: struct {
	kind:   EntityKind,
	model:  Model,
	scale:  Vec3,
	update: proc(e: ^Entity),
	render: proc(e: ^Entity),
}

EntityGlobals :: struct {
	entities:             [MAX_ENTITIES]Entity,
	next_available_index: int,
}

entity_create :: proc() -> ^Entity {
	if g.entity_globals.next_available_index >= MAX_ENTITIES {
		panic("Max entities reached")
	}

	index := g.entity_globals.next_available_index
	g.entity_globals.next_available_index += 1

	return &g.entity_globals.entities[index]
}

setup_light :: proc(e: ^Entity) {
	e.kind = .Light

	e.model = make_cube()
	e.scale = Vec3{0.2, 0.2, 0.2}
}
