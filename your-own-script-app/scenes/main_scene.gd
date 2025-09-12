extends Control

# ---------------------------
# Keywords for syntax highlighting
const KEYWORDS = ["print", "vs", "vi", "loop:", "input:", "help", "if:", "vb", "==", "<", ">", "!="]
const MAX_LOOP_ITERATIONS = 100000

# Node references
@onready var editor = $Editor
@onready var console = $Console_Panel/Console
@onready var run_button = $Buttons_Panel/RunButton
@onready var compile_button = $Buttons_Panel/CompileButton
@onready var load_file = $Buttons_Panel/LoadButton
@onready var save_file = $Buttons_Panel/SaveButton
@onready var file_dialog = $FileDialog
@onready var input_line = $Console_Panel/InputLine

# Variable storage
var variables = {}
var highlighter_theme = CodeHighlighter.new()
var line_index = 0
var awaiting_input_for_variable = ""
var loop_iterations = 0

# ---------------------------
# Setup
func _ready():
	run_button.pressed.connect(_on_run_pressed)
	compile_button.pressed.connect(_on_compile_pressed)
	
	load_file.pressed.connect(_on_load_pressed)
	save_file.pressed.connect(_on_save_pressed)
	file_dialog.file_selected.connect(_on_file_selected)

	editor.text_changed.connect(_on_editor_text_changed)
	input_line.text_submitted.connect(_on_input_received)
	
	editor.set_draw_spaces(true)
	update_highlighter()
	console.scroll_following = true

func update_highlighter():
	highlighter_theme = CodeHighlighter.new()
	highlighter_theme.add_keyword_color("print", Color.YELLOW)
	highlighter_theme.add_keyword_color("vs", Color.CYAN)
	highlighter_theme.add_keyword_color("vi", Color.CYAN)
	highlighter_theme.add_keyword_color("vb", Color.CYAN)
	highlighter_theme.add_keyword_color("loop:", Color.ORANGE)
	highlighter_theme.add_keyword_color("input:", Color.ORANGE)
	highlighter_theme.add_keyword_color("if:", Color.ORANGE)
	highlighter_theme.add_keyword_color("help", Color.GREEN)
	highlighter_theme.add_keyword_color("==", Color.AQUA)
	highlighter_theme.add_keyword_color("!=", Color.AQUA)
	highlighter_theme.add_keyword_color("<", Color.AQUA)
	highlighter_theme.add_keyword_color(">", Color.AQUA)
	highlighter_theme.add_color_region("#", "", Color.DARK_GRAY)
	
	editor.syntax_highlighter = highlighter_theme

# ---------------------------
# Live Syntax Highlighting
func _on_editor_text_changed():
	update_highlighter()

# ---------------------------
# File I/O
func _on_load_pressed():
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Load YOScript File"
	file_dialog.clear_filters()
	file_dialog.add_filter("*.yo ; YOScript File")
	file_dialog.popup_centered()

func _on_save_pressed():
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Save YOScript File"
	file_dialog.clear_filters()
	file_dialog.add_filter("*.yo ; YOScript File")
	file_dialog.popup_centered()

func _on_file_selected(path: String):
	if file_dialog.file_mode == FileDialog.FILE_MODE_OPEN_FILE:
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			editor.text = file.get_as_text()
			file.close()
	elif file_dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE:
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(editor.text)
			file.close()
			log_output("File saved successfully to: " + path)

# ---------------------------
# Run Interpreter
func _on_run_pressed():
	console.clear()
	variables.clear()
	line_index = 0
	loop_iterations = 0
	run_code()

func run_code():
	var lines = editor.text.split("\n")
	while line_index < lines.size():
		var line = lines[line_index]
		
		# Skip blank lines and comments
		if line.strip_edges() == "" or line.strip_edges().begins_with("#"):
			line_index += 1
			continue
		
		if line.strip_edges().begins_with("loop:"):
			line_index = parse_loop(line, lines, line_index)
			continue
		if line.strip_edges().begins_with("if:"):
			line_index = parse_if(line, lines, line_index)
			continue
		if line.strip_edges().begins_with("input:"):
			var var_name = line.strip_edges().replace("input:", "").strip_edges()
			if var_name:
				log_output(">>")
				input_line.show()
				awaiting_input_for_variable = var_name
			line_index += 1
			return
		
		parse_line(line.strip_edges())
		line_index += 1

func _on_input_received(text: String):
	if awaiting_input_for_variable:
		if variables.has(awaiting_input_for_variable):
			var var_type = variables[awaiting_input_for_variable].get("type")
			if var_type == "int":
				if text.is_valid_int():
					variables[awaiting_input_for_variable].value = int(text)
				else:
					log_error("Input is not a valid integer. Defaulting to 0.")
					variables[awaiting_input_for_variable].value = 0
			elif var_type == "bool":
				variables[awaiting_input_for_variable].value = (text.to_lower() == "true")
			else:
				variables[awaiting_input_for_variable].value = text
		else:
			variables[awaiting_input_for_variable] = {"type": "string", "value": text}
		
		input_line.hide()
		input_line.clear()
		awaiting_input_for_variable = ""
		run_code()

# ---------------------------
# Parse a single line containing multiple statements
func parse_line(line: String):
	var statements = line.split("|")
	for stmt in statements:
		parse_statement(stmt.strip_edges())

# ---------------------------
# Parse a single statement
func parse_statement(line: String):
	line = line.strip_edges()
	if line == "" or line.begins_with("#"):
		return

	if line == "help":
		show_help()
		return

	var parts_reassign = line.split("=")
	if parts_reassign.size() == 2:
		var var_name = parts_reassign[0].strip_edges()
		var new_value_expr = parts_reassign[1].strip_edges()
		if variables.has(var_name):
			var new_value = eval_expression(new_value_expr)
			if new_value != null:
				variables[var_name].value = new_value
				return
			else:
				log_error("Invalid value for variable reassignment: " + new_value_expr)
				return
	
	if line.begins_with("print"):
		var value_expr = line.substr(6, line.length() - 6).strip_edges()
		var result = eval_expression(value_expr)
		if result != null:
			log_output(str(result))
		else:
			log_error("Unknown print value: " + value_expr)

	elif line.begins_with("vs"):
		var parts = line.split(" ", false)
		if parts.size() < 4 or parts[2] != "=":
			log_error("Invalid string variable declaration: " + line)
			return
		var var_name = parts[1]
		var raw_value = line.substr(line.find("=") + 1, line.length() - line.find("=") - 1).strip_edges()
		var eval_result = eval_expression(raw_value)
		if typeof(eval_result) == TYPE_STRING:
			variables[var_name] = {"type": "string", "value": eval_result}
		else:
			log_error("Invalid value for string variable: " + raw_value)

	elif line.begins_with("vi"):
		var parts = line.split(" ", false)
		if parts.size() < 4 or parts[2] != "=":
			log_error("Invalid integer variable declaration: " + line)
			return
		var var_name = parts[1]
		var raw_value = line.substr(line.find("=") + 1, line.length()).strip_edges()
		var eval_result = eval_expression(raw_value)
		if typeof(eval_result) == TYPE_INT:
			variables[var_name] = {"type": "int", "value": int(eval_result)}
		else:
			log_error("Invalid value for integer variable: " + raw_value)
			
	elif line.begins_with("vb"):
		var parts = line.split(" ", false)
		if parts.size() < 4 or parts[2] != "=":
			log_error("Invalid boolean variable declaration: " + line)
			return
		var var_name = parts[1]
		var raw_value = line.substr(line.find("=") + 1, line.length()).strip_edges()
		if raw_value == "true":
			variables[var_name] = {"type": "bool", "value": true}
		elif raw_value == "false":
			variables[var_name] = {"type": "bool", "value": false}
		else:
			log_error("Invalid value for boolean variable: " + raw_value)
	
	elif line.begins_with("input:"):
		var var_name = line.replace("input:", "").strip_edges()
		if variables.has(var_name):
			variables[var_name].value = null
		else:
			log_error("Input target variable not declared: " + var_name)

	else:
		log_error("Unknown command: " + line)

# ---------------------------
# Help command function
func show_help():
	console.clear()
	log_output("--- YOScript Help ---")

	log_output("Blocks are defined by indentation.")

	log_output("--------------------")

	log_output("print '<value>'       : Prints a value to the console. (Replace '' with double quotes)")

	log_output("print <variable>       : Prints a variable value to the console.")

	log_output("--------------------")

	log_output("vs <name> = <value>  : Declares a string variable.")

	log_output("--------------------")

	log_output("vi <name> = <value>  : Declares an integer variable.")

	log_output("--------------------")

	log_output("vb <name> = <value>  : Declares a boolean variable.")

	log_output("--------------------")

	log_output("loop: <condition>     : A conditional loop that runs as long as the condition is true.")

	log_output("--------------------")

	log_output("if: <expr> <operator> <expr> : A conditional statement.")

	log_output("<expr> < <expr>")

	log_output("<expr> > <expr>")

	log_output("<expr> == <expr>")

	log_output("<expr> != <expr>")

	log_output("--------------------")

	log_output("input:<int or string>         : Prompts for user input and stores it in the given variable")

	log_output("--------------------")

	log_output("help                 : Displays this help message.")

	log_output("--------------------")

# ---------------------------
# Parse a block by indentation level
func get_block(lines: Array, start_index: int) -> Array:
	if start_index >= lines.size():
		return []
	
	var header_indent = 0
	while header_indent < lines[start_index].length() and (lines[start_index][header_indent] == ' ' or lines[start_index][header_indent] == '\t'):
		header_indent += 1
		
	var block_body = []
	var i = start_index + 1
	
	while i < lines.size():
		var current_line = lines[i]
		var current_line_stripped = current_line.strip_edges()
		
		# Skip blank lines and comments inside the block
		if current_line_stripped == "" or current_line_stripped.begins_with("#"):
			i += 1
			continue
		
		var current_indent = 0
		while current_indent < current_line.length() and (current_line[current_indent] == ' ' or current_line[current_indent] == '\t'):
			current_indent += 1

		if current_indent > header_indent:
			block_body.append(current_line)
			i += 1
		else:
			break
	
	return block_body

# ---------------------------
# Parse an if statement
func parse_if(line: String, lines: Array, line_index: int) -> int:
	var header = line.strip_edges()
	var body_lines = get_block(lines, line_index)
	
	var condition_str = header.replace("if:", "").strip_edges()
	var result = eval_condition(condition_str)

	if result == null:
		log_error("Invalid if condition: " + condition_str)
		return line_index + len(body_lines) + 1

	if result:
		for body_line in body_lines:
			parse_line(body_line)

	return line_index + len(body_lines) + 1

# ---------------------------
# Parse a loop
func parse_loop(line: String, lines: Array, line_index: int) -> int:
	var header = line.strip_edges()
	var body_lines = get_block(lines, line_index)
	
	var condition_str = header.replace("loop:", "").strip_edges()
	
	while eval_condition(condition_str):
		loop_iterations += 1
		if loop_iterations > MAX_LOOP_ITERATIONS:
			log_error("Loop exceeded max iterations. It may be an infinite loop.")
			break
		for body_line in body_lines:
			parse_line(body_line)
			
	return line_index + len(body_lines) + 1

# ---------------------------
# Evaluate a condition
func eval_condition(condition_str: String):
	condition_str = condition_str.strip_edges()
	var operator = ""
	var parts = []

	if condition_str.find("==") != -1:
		operator = "=="
		parts = condition_str.split("==")
	elif condition_str.find("!=") != -1:
		operator = "!="
		parts = condition_str.split("!=")
	elif condition_str.find("<") != -1:
		operator = "<"
		parts = condition_str.split("<")
	elif condition_str.find(">") != -1:
		operator = ">"
		parts = condition_str.split(">")
	else:
		return null

	if parts.size() != 2:
		return null

	var left_val = eval_expression(parts[0].strip_edges())
	var right_val = eval_expression(parts[1].strip_edges())

	if typeof(left_val) == TYPE_STRING and typeof(right_val) == TYPE_INT:
		left_val = int(left_val)
	elif typeof(left_val) == TYPE_INT and typeof(right_val) == TYPE_STRING:
		right_val = int(right_val)

	if left_val == null or right_val == null:
		return null
	
	var result = false
	match operator:
		"==": result = left_val == right_val
		"!=": result = left_val != right_val
		"<":  result = left_val < right_val
		">":  result = left_val > right_val
	
	return result

# ---------------------------
# Evaluate expression
func eval_expression(expr: String):
	expr = expr.strip_edges()
	
	if variables.has(expr):
		return variables[expr].value
	
	# Pass all expressions to eval_math for evaluation, which can handle literals, variables, and operations
	return eval_math(expr)

# ---------------------------
# Evaluate math and string expressions, including variables
func eval_math(expr: String):
	var expression = Expression.new()
	var input_names = []
	var inputs = []
	
	for key in variables:
		input_names.append(key)
		inputs.append(variables[key].value)
	
	var error = expression.parse(expr, input_names)
	if error != OK:
		return null

	var result = expression.execute(inputs, null, false)
	return result

# ---------------------------
# Console logging
func log_output(msg: String):
	console.add_text(msg + "\n")

func log_error(msg: String):
	console.add_text("ERROR: " + msg + "\n")

# ---------------------------
# Compile YOScript → C#
func _on_compile_pressed():
	var code = editor.text
	var cs_lines = ["using System;", "", "class Program {", "    static void Main() {"]
	variables.clear()
	var i = 0
	var lines = code.split("\n")
	while i < lines.size():
		var line = lines[i]
		
		# Skip blank lines and comments
		if line.strip_edges() == "" or line.strip_edges().begins_with("#"):
			i += 1
			continue
			
		if line.strip_edges().begins_with("loop:"):
			var header = lines[i].strip_edges()
			var body_lines = get_block(lines, i)
			var cs_block = compile_block("while", header.replace("loop:", "").strip_edges(), body_lines)
			cs_lines += cs_block
			i += len(body_lines) + 1
			continue
		
		if line.strip_edges().begins_with("if:"):
			var header = lines[i].strip_edges()
			var body_lines = get_block(lines, i)
			var cs_block = compile_block("if", header.replace("if:", "").strip_edges(), body_lines)
			cs_lines += cs_block
			i += len(body_lines) + 1
			continue
			
		var stmt_cs = compile_statement(line.strip_edges())
		if stmt_cs != "":
			cs_lines.append("        " + stmt_cs)
		i += 1
	cs_lines.append("    }")
	cs_lines.append("}")
	var file = FileAccess.open("yoscript_output.cs", FileAccess.WRITE)
	for l in cs_lines:
		file.store_line(l)
	file.close()
	log_output("Compiled to yoscript_output.cs")

func compile_expression(expr: String) -> String:
	expr = expr.strip_edges()
	
	if variables.has(expr):
		return expr
	if expr.is_valid_int() or expr.is_valid_float():
		return expr
	
	if expr.begins_with("\"") and expr.ends_with("\""):
		return expr

	var parts = []
	if expr.find("==") != -1:
		parts = expr.split("==")
	elif expr.find("!=") != -1:
		parts = expr.split("!=")
	elif expr.find("<") != -1:
		parts = expr.split("<")
	elif expr.find(">") != -1:
		parts = expr.split(">")
	else:
		return expr

	if parts.size() == 2:
		var left = compile_expression(parts[0])
		var right = compile_expression(parts[1])
		return "(%s %s %s)" % [left, expr.split(parts[0])[1].split(parts[1])[0].strip_edges(), right]

	return expr

func compile_statement(line: String) -> String:
	if line.begins_with("print"):
		var value = compile_expression(line.substr(6).strip_edges())
		return "Console.WriteLine(%s);" % value
	elif line.begins_with("vs"):
		var parts = line.split("=")
		var var_name = parts[0].replace("vs", "").strip_edges()
		var var_value = compile_expression(parts[1].strip_edges())
		variables[var_name] = {"type": "string", "value": null}
		return "string %s = %s;" % [var_name, var_value]
	elif line.begins_with("vi"):
		var parts = line.split("=")
		var var_name = parts[0].replace("vi", "").strip_edges()
		var var_value = compile_expression(parts[1].strip_edges())
		variables[var_name] = {"type": "int", "value": null}
		return "int %s = %s;" % [var_name, var_value]
	elif line.begins_with("vb"):
		var parts = line.split("=")
		var var_name = parts[0].replace("vb", "").strip_edges()
		var var_value = compile_expression(parts[1].strip_edges())
		variables[var_name] = {"type": "bool", "value": null}
		return "bool %s = %s;" % [var_name, var_value]
	elif line.begins_with("input:"):
		var var_name = line.replace("input:", "").strip_edges()
		var var_type = variables.get(var_name, {}).get("type", "string")
		if var_type == "int":
			return "%s = int.Parse(Console.ReadLine());" % var_name
		elif var_type == "bool":
			return "%s = bool.Parse(Console.ReadLine());" % var_name
		else:
			return "%s = Console.ReadLine();" % var_name
	
	var parts_reassign = line.split("=")
	if parts_reassign.size() == 2:
		var var_name = parts_reassign[0].strip_edges()
		var new_value_expr = parts_reassign[1].strip_edges()
		var compiled_expr = compile_expression(new_value_expr)
		return "%s = %s;" % [var_name, compiled_expr]

	return ""

func compile_block(block_type: String, condition_str: String, body: Array) -> Array:
	var compiled_condition = compile_expression(condition_str)
	var cs_lines = ["        %s (%s) {" % [block_type, compiled_condition]]
	for stmt_line in body:
		var stmt = stmt_line.strip_edges()
		var stmt_cs = compile_statement(stmt)
		if stmt_cs != "":
			cs_lines.append("            " + stmt_cs)
	cs_lines.append("        }")
	return cs_lines
