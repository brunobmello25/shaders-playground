package main

MAX_ENTITIES :: 100

EntityKind :: enum {
	nil,
	Light,
	Cube,
}

EntityHandle :: struct {
	id: int,
}

Entity :: struct {
	kind:  EntityKind,
	model: Model,
}

entity_create :: proc() -> ^Entity {

}
