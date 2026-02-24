package config

import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:os"

Vec3 :: [3]f32

ConfigPath :: "config.json"

Config :: struct {
	world_size: f32,
	fog:        struct {
		start:     f32,
		end:       f32,
		shininess: f32,
	},
}

default_config: Config = {
	world_size = 100.0,
	fog        = {start = 30.0, end = 50.0, shininess = 1.0},
}

@(private = "file")
_c: Config

get :: proc() -> ^Config {
	return &_c
}

save :: proc() { 	// TODO: probably handle errors here
	data, _ := json.marshal(_c, {pretty = true})
	os.write_entire_file(ConfigPath, data)
	delete(data)
}

load :: proc() {
	data, ok := os.read_entire_file(ConfigPath)
	if !ok {
		log.warnf("Failed to read config file at %s, using default config", ConfigPath)
		_c = default_config
	}
	err := json.unmarshal(data, &_c)
	if err != nil {
		log.warnf("Failed to parse config file at %s, using default config: %v", ConfigPath, err)
		_c = default_config
	}
}
