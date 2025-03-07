package main

import "core:fmt"
import "core:os"
import "core:strings"
import rl "vendor:raylib"

Token :: struct {
	kind:  string,
	value: string,
}

Node :: struct {
	tag:      string,
	text:     string,
	children: [dynamic]^Node,
}

render_node :: proc(node: ^Node, x, y: i32) -> i32 {
	y_offset := y
	if node.tag == "text" && node.text != "" {
		c_text := strings.clone_to_cstring(node.text, context.temp_allocator)
		rl.DrawText(c_text, x, y, 20, rl.WHITE)
		return 20
	}

	if node.tag == "p" {
		y_offset += 20
	}

	for child in node.children {
		y_offset += render_node(child, x, y_offset)
	}

	return y_offset - y
}

tokenize :: proc(html: string) -> [dynamic]Token {
	tokens: [dynamic]Token
	for i := 0; i < len(html); {
		if html[i] == '<' {
			end := strings.index(html[i:], ">") + i + 1 // Assumes html is not malformed
			append(&tokens, Token{"tag", html[i:end]})
			i = end
		} else {
			end := strings.index(html[i:], "<")
			if end == -1 {end = len(html)} else {end += i}
			append(&tokens, Token{"text", strings.trim_space(html[i:end])})
			i = end
		}
	}
	return tokens
}

build_dom :: proc(tokens: [dynamic]Token) -> ^Node {
	root := new(Node)
	stack: [dynamic]^Node
	append(&stack, root)
	for token in tokens {
		current := stack[len(stack) - 1]
		if token.kind == "tag" {
			if strings.has_prefix(token.value, "</") {
				if len(stack) > 1 {
					resize(&stack, len(stack) - 1)
				}
			} else {
				node := new(Node)
				tag := token.value[1:len(token.value) - 1]
				space_idx := strings.index(tag, " ")
				node.tag = tag if space_idx == -1 else tag[:space_idx]
				append(&current.children, node)
				append(&stack, node)
			}
		} else if token.kind == "text" {
			node := new(Node)
			node.tag = "text"
			node.text = token.value
			append(&current.children, node)
		}
	}
	return root
}

main :: proc() {
	data, ok := os.read_entire_file_from_filename(os.args[1] if len(os.args) > 1 else "input.html")
	if !ok {
		return
	}
	html := string(data)
	tokens := tokenize(html)
	root := build_dom(tokens)

	rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
	rl.InitWindow(1920, 1080, "Browser")
	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()
		rl.ClearBackground(rl.BLACK)

		y: i32 = 10
		for child in root.children {
			y += render_node(child, 10, y)
		}
	}
}
