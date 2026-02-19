package ui

import "core:unicode/utf8"

import mu   "vendor:microui"
import sapp "../vendor/sokol/sokol/app"
import sg   "../vendor/sokol/sokol/gfx"
import s    "../shaders"

MAX_QUADS :: 16384
MAX_VERTS :: MAX_QUADS * 4
MAX_IDXS  :: MAX_QUADS * 6

// Vertex layout matching the ui shader: pos(FLOAT2) + uv(FLOAT2) + color(UBYTE4N)
Vertex :: struct {
	pos:   [2]f32,
	uv:    [2]f32,
	color: [4]u8,
}

// Center UV of the DEFAULT_ATLAS_WHITE region {125, 68, 3, 3}
WHITE_U :: f32(126.5 / 128.0)
WHITE_V :: f32(69.5  / 128.0)

// A batch groups indices that share the same scissor rect.
@(private)
_Batch :: struct {
	sx, sy, sw, sh: i32,
	idx_start:       int,
	idx_count:       int,
}

MAX_BATCHES :: 256

@(private) _ctx:        mu.Context
@(private) _atlas_img:  sg.Image
@(private) _atlas_view: sg.View
@(private) _atlas_smp:  sg.Sampler
@(private) _pipeline:   sg.Pipeline
@(private) _vbuf:       sg.Buffer
@(private) _ibuf:       sg.Buffer
@(private) _verts:      [MAX_VERTS]Vertex
@(private) _idxs:       [MAX_IDXS]u16
@(private) _vert_n:     int
@(private) _idx_n:      int
@(private) _batches:    [MAX_BATCHES]_Batch
@(private) _batch_n:    int

init :: proc() {
	mu.init(&_ctx)
	_ctx.text_width  = mu.default_atlas_text_width
	_ctx.text_height = mu.default_atlas_text_height

	// Upload the built-in bitmap font atlas as a single-channel R8 texture
	_atlas_img = sg.make_image({
		width        = mu.DEFAULT_ATLAS_WIDTH,
		height       = mu.DEFAULT_ATLAS_HEIGHT,
		pixel_format = .R8,
		data         = {mip_levels = {0 = sg.Range{
			ptr  = &mu.default_atlas_alpha,
			size = size_of(mu.default_atlas_alpha),
		}}},
	})
	_atlas_view = sg.make_view({
		texture = {
			image      = _atlas_img,
			slices     = {base = 0, count = 1},
			mip_levels = {base = 0, count = 1},
		},
	})
	_atlas_smp = sg.make_sampler({
		min_filter = .NEAREST,
		mag_filter = .NEAREST,
	})

	// 2D pipeline: alpha blending enabled, no depth write/test
	shader := sg.make_shader(s.ui_shader_desc(sg.query_backend()))
	_pipeline = sg.make_pipeline({
		shader     = shader,
		layout     = {
			attrs = {
				s.ATTR_ui_a_pos   = {format = .FLOAT2},
				s.ATTR_ui_a_uv    = {format = .FLOAT2},
				s.ATTR_ui_a_color = {format = .UBYTE4N},
			},
		},
		index_type = .UINT16,
		colors     = {0 = {
			blend = {
				enabled          = true,
				src_factor_rgb   = .SRC_ALPHA,
				dst_factor_rgb   = .ONE_MINUS_SRC_ALPHA,
				src_factor_alpha = .ONE,
				dst_factor_alpha = .ONE_MINUS_SRC_ALPHA,
			},
		}},
		depth     = {write_enabled = false, compare = .ALWAYS},
		cull_mode = .NONE,
	})

	// Dynamic buffers rebuilt from scratch every frame
	_vbuf = sg.make_buffer({
		usage = {vertex_buffer = true, stream_update = true},
		size  = size_of(Vertex) * MAX_VERTS,
	})
	_ibuf = sg.make_buffer({
		usage = {index_buffer = true, stream_update = true},
		size  = size_of(u16) * MAX_IDXS,
	})
}

shutdown :: proc() {
	sg.destroy_image(_atlas_img)
	sg.destroy_view(_atlas_view)
	sg.destroy_sampler(_atlas_smp)
	sg.destroy_pipeline(_pipeline)
	sg.destroy_buffer(_vbuf)
	sg.destroy_buffer(_ibuf)
}

// ctx_ptr returns the microui context so callers can invoke microui procs directly.
ctx_ptr :: proc() -> ^mu.Context {
	return &_ctx
}

// begin_frame must be called once per frame before building any UI.
begin_frame :: proc() {
	mu.begin(&_ctx)
}

// render must be called inside an active sg.begin_pass / sg.end_pass block,
// after all UI widgets have been submitted for this frame.
render :: proc() {
	mu.end(&_ctx)

	_vert_n  = 0
	_idx_n   = 0
	_batch_n = 0

	// Phase 1: walk all commands, accumulate geometry, record scissor batches.
	// update_buffer may only be called once per buffer per frame, so no GPU
	// calls happen here.
	w, h := sapp.width(), sapp.height()
	_push_batch(0, 0, w, h)

	cmd: ^mu.Command
	for mu.next_command(&_ctx, &cmd) {
		switch v in cmd.variant {
		case ^mu.Command_Clip:
			// finalize the running batch, start a new one
			_batches[_batch_n - 1].idx_count = _idx_n - _batches[_batch_n - 1].idx_start
			if v.rect.w > 0x100000 {
				_push_batch(0, 0, w, h)
			} else {
				_push_batch(v.rect.x, v.rect.y, v.rect.w, v.rect.h)
			}
		case ^mu.Command_Rect:
			_push_quad(v.rect, {WHITE_U, WHITE_V, WHITE_U, WHITE_V}, v.color)
		case ^mu.Command_Text:
			pos := v.pos
			for ch in v.str {
				if ch & 0xc0 == 0x80 { continue }
				r := int(min(ch, 127))
				g := mu.default_atlas[mu.DEFAULT_ATLAS_FONT + r]
				_push_quad({pos.x, pos.y, g.w, g.h}, _atlas_rect_uv(g), v.color)
				pos.x += g.w
			}
		case ^mu.Command_Icon:
			g := mu.default_atlas[int(v.id)]
			x := v.rect.x + (v.rect.w - g.w) / 2
			y := v.rect.y + (v.rect.h - g.h) / 2
			_push_quad({x, y, g.w, g.h}, _atlas_rect_uv(g), v.color)
		case ^mu.Command_Jump:
			// handled internally by mu.next_command
		}
	}
	_batches[_batch_n - 1].idx_count = _idx_n - _batches[_batch_n - 1].idx_start

	if _vert_n == 0 { return }

	// Phase 2: upload buffers once, then one draw call per batch.
	sg.update_buffer(_vbuf, {ptr = &_verts, size = uint(size_of(Vertex) * _vert_n)})
	sg.update_buffer(_ibuf, {ptr = &_idxs,  size = uint(size_of(u16)    * _idx_n)})

	sg.apply_pipeline(_pipeline)
	sg.apply_bindings({
		vertex_buffers = {0 = _vbuf},
		index_buffer   = _ibuf,
		views          = {s.VIEW_ui_atlas  = _atlas_view},
		samplers       = {s.SMP_ui_sampler = _atlas_smp},
	})
	params := s.Ui_Vs_Params{screen_size = {f32(w), f32(h)}}
	sg.apply_uniforms(s.UB_UI_VS_Params, {ptr = &params, size = size_of(s.Ui_Vs_Params)})

	for i in 0..<_batch_n {
		b := _batches[i]
		if b.idx_count == 0 { continue }
		sg.apply_scissor_rect(b.sx, b.sy, b.sw, b.sh, true)
		sg.draw(b.idx_start, b.idx_count, 1)
	}

	sg.apply_scissor_rect(0, 0, w, h, true)
}

// handle_event translates a sokol event into microui input calls.
handle_event :: proc(e: ^sapp.Event) {
	#partial switch e.type {
	case .MOUSE_MOVE:
		mu.input_mouse_move(&_ctx, i32(e.mouse_x), i32(e.mouse_y))
	case .MOUSE_DOWN:
		mu.input_mouse_down(&_ctx, i32(e.mouse_x), i32(e.mouse_y), _mu_mouse(e.mouse_button))
	case .MOUSE_UP:
		mu.input_mouse_up(&_ctx, i32(e.mouse_x), i32(e.mouse_y), _mu_mouse(e.mouse_button))
	case .MOUSE_SCROLL:
		mu.input_scroll(&_ctx, 0, i32(-e.scroll_y * 30))
	case .KEY_DOWN:
		if key, ok := _mu_key(e.key_code); ok {
			mu.input_key_down(&_ctx, key)
		}
	case .KEY_UP:
		if key, ok := _mu_key(e.key_code); ok {
			mu.input_key_up(&_ctx, key)
		}
	case .CHAR:
		buf, n := utf8.encode_rune(rune(e.char_code))
		mu.input_text(&_ctx, string(buf[:n]))
	}
}

@(private)
_atlas_rect_uv :: proc(r: mu.Rect) -> [4]f32 {
	return {
		f32(r.x)       / 128.0,
		f32(r.y)       / 128.0,
		f32(r.x + r.w) / 128.0,
		f32(r.y + r.h) / 128.0,
	}
}

@(private)
_push_batch :: proc(sx, sy, sw, sh: i32) {
	if _batch_n >= MAX_BATCHES { return }
	_batches[_batch_n] = {sx, sy, sw, sh, _idx_n, 0}
	_batch_n += 1
}

@(private)
_push_quad :: proc(dst: mu.Rect, uv: [4]f32, color: mu.Color) {
	if _vert_n + 4 > MAX_VERTS || _idx_n + 6 > MAX_IDXS { return }

	c  := [4]u8{color.r, color.g, color.b, color.a}
	b  := u16(_vert_n)
	x0 := f32(dst.x)
	y0 := f32(dst.y)
	x1 := f32(dst.x + dst.w)
	y1 := f32(dst.y + dst.h)

	_verts[_vert_n + 0] = {{x0, y0}, {uv[0], uv[1]}, c}
	_verts[_vert_n + 1] = {{x1, y0}, {uv[2], uv[1]}, c}
	_verts[_vert_n + 2] = {{x1, y1}, {uv[2], uv[3]}, c}
	_verts[_vert_n + 3] = {{x0, y1}, {uv[0], uv[3]}, c}

	_idxs[_idx_n + 0] = b + 0
	_idxs[_idx_n + 1] = b + 1
	_idxs[_idx_n + 2] = b + 2
	_idxs[_idx_n + 3] = b + 0
	_idxs[_idx_n + 4] = b + 2
	_idxs[_idx_n + 5] = b + 3

	_vert_n += 4
	_idx_n  += 6
}

@(private)
_mu_mouse :: proc(btn: sapp.Mousebutton) -> mu.Mouse {
	#partial switch btn {
	case .LEFT:   return .LEFT
	case .RIGHT:  return .RIGHT
	case .MIDDLE: return .MIDDLE
	}
	return .LEFT
}

@(private)
_mu_key :: proc(key: sapp.Keycode) -> (mu.Key, bool) {
	#partial switch key {
	case .LEFT_SHIFT, .RIGHT_SHIFT:       return .SHIFT,     true
	case .LEFT_CONTROL, .RIGHT_CONTROL:   return .CTRL,      true
	case .LEFT_ALT, .RIGHT_ALT:           return .ALT,       true
	case .BACKSPACE:                       return .BACKSPACE, true
	case .DELETE:                          return .DELETE,    true
	case .ENTER, .KP_ENTER:               return .RETURN,    true
	case .LEFT:                            return .LEFT,      true
	case .RIGHT:                           return .RIGHT,     true
	case .HOME:                            return .HOME,      true
	case .END:                             return .END,       true
	case .A:                               return .A,         true
	case .X:                               return .X,         true
	case .C:                               return .C,         true
	case .V:                               return .V,         true
	}
	return .SHIFT, false
}
