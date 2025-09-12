extends Control

# ---------------------------
# Keywords for syntax highlighting
const KEYWORDS = ["print", "vs", "vi", "loop:", "input:", "help", "if:", "vb", "==", "<", ">", "!=", "loop"]
const MAX_LOOP_ITERATIONS = 100000

# Node references
@onready var editor = $Editor
@onready var console = $Console_Panel/Console
@onready var run_button = $RunButton
@onready var compile_button = $CompileButton
@onready var load_file = $LoadButton
@onready var save_file = $SaveButton
@onready var copy_button = $Console_Panel/CopyButton
@onready var build_button = $BuildButton
@onready var file_dialog = $FileDialog
@onready var input_line = $Console_Panel/InputLine
@onready var dotnet_path_input = $DotNetPathInput
@onready var browse_button = $BrowseButton


# Variable storage
var variables = {}
var highlighter_theme = CodeHighlighter.new()
var awaiting_input_for_variable = ""
var loop_iterations = {} # Now a dictionary to handle multiple loops
var execution_stack = []
var config = ConfigFile.new()
var dialog_purpose = "" # "load", "save", or "browse_dotnet"

# ---------------------------
# Setup
func _ready():
	run_button.pressed.connect(_on_run_pressed)
	compile_button.pressed.connect(_on_compile_pressed)
	
	load_file.pressed.connect(_on_load_pressed)
	save_file.pressed.connect(_on_save_pressed)
	build_button.pressed.connect(_on_build_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	browse_button.pressed.connect(_on_browse_pressed)

	editor.text_changed.connect(_on_editor_text_changed)
	input_line.text_submitted.connect(_on_input_received)
	
	editor.set_draw_spaces(true)
	update_highlighter()
	console.scroll_following = true
	
	find_dotnet_path_from_config()

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
	dialog_purpose = "load"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Load YOScript File"
	file_dialog.clear_filters()
	file_dialog.add_filter("*.yo ; YOScript File")
	file_dialog.popup_centered()

func _on_save_pressed():
	dialog_purpose = "save"
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Save YOScript File"
	file_dialog.clear_filters()
	file_dialog.add_filter("*.yo ; YOScript File")
	file_dialog.popup_centered()

func _on_file_selected(path: String):
	if dialog_purpose == "browse_dotnet":
		dotnet_path_input.text = path
	elif dialog_purpose == "load":
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			editor.text = file.get_as_text()
			file.close()
	elif dialog_purpose == "save":
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(editor.text)
			file.close()
			log_output("File saved successfully to: " + path)

# ---------------------------
# Console Button Functionality
func _on_copy_pressed():
	DisplayServer.clipboard_set(console.text)

func find_dotnet_path_from_config():
	var err = config.load("user://user.cfg")
	if err == OK:
		var path = config.get_value("settings", "dotnet_path", "")
		if not path.is_empty():
			dotnet_path_input.text = path
			log_output("Loaded dotnet path from user.cfg")
			return path
	return ""

func save_dotnet_path_to_config(path: String):
	config.set_value("settings", "dotnet_path", path)
	config.save("user://user.cfg")

func _on_browse_pressed():
	dialog_purpose = "browse_dotnet"
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.title = "Select dotnet executable"
	file_dialog.clear_filters()
	file_dialog.popup_centered()

func _on_build_pressed():
	log_output("Starting dotnet build...")
	
	var dotnet_path = dotnet_path_input.text.strip_edges()
	
	# If the user hasn't specified a path, try to find it dynamically
	if dotnet_path.is_empty():
		dotnet_path = find_dotnet_path_from_path_env()

	if dotnet_path.is_empty():
		log_error("Could not find the 'dotnet' executable. Please specify the path manually or ensure it's in your system's PATH.")
		return
	
	save_dotnet_path_to_config(dotnet_path)
	
	var output = []
	var exit_code = OS.execute(dotnet_path, ["build"], output, true)
	
	if exit_code == 0:
		log_output("Build successful!")
		if not output.is_empty():
			log_output(output[0])
	else:
		log_error("Build failed with exit code: " + str(exit_code))
		if not output.is_empty():
			log_error(output[0])

# This is the original function to find dotnet, now renamed for clarity
func find_dotnet_path_from_path_env():
	var os_name = OS.get_name()
	var dotnet_exec_name = "dotnet"
	
	if os_name == "Windows":
		dotnet_exec_name += ".exe"

	var path_env = OS.get_environment("PATH")
	var path_separator = ":"
	if os_name == "Windows":
		path_separator = ";"

	var path_dirs = path_env.split(path_separator)

	for dir in path_dirs:
		var full_path = dir.strip_edges() + "/" + dotnet_exec_name
		if FileAccess.file_exists(full_path):
			return full_path

	return ""

# ---------------------------
# Program Execution (Stack-based)
func _on_run_pressed():
	console.clear()
	variables.clear()
	loop_iterations.clear()
	execution_stack.clear()
	
	var lines = editor.text.split("\n")
	execution_stack.append({"lines": lines, "index": 0})
	
	execute_program()

func execute_program():
	while execution_stack.size() > 0:
		var frame = execution_stack.back()
		var lines = frame.lines
		var i = frame.index

		if i >= lines.size():
			execution_stack.pop_back()
			continue

		var line = lines[i]
		var stripped_line = line.strip_edges()
		
		# Skip blank lines and comments
		if stripped_line.is_empty() or stripped_line.begins_with("#"):
			frame.index += 1
			continue

		if stripped_line.begins_with("loop:"):
			var body_lines = get_block(lines, i)
			var condition = stripped_line.replace("loop:", "").strip_edges()
			
			if eval_condition(condition):
				var loop_id = str(hash(lines) + i) # Unique ID for each loop
				loop_iterations[loop_id] = loop_iterations.get(loop_id, 0) + 1
				if loop_iterations[loop_id] > MAX_LOOP_ITERATIONS:
					log_error("Loop exceeded max iterations. It may be an infinite loop.")
					execution_stack.clear()
					return
				
				# Move to the body of the loop
				execution_stack.append({"lines": body_lines, "index": 0, "parent_loop_index": i})
				frame.index = i + 1 # Prepare parent to skip past the loop body
				continue
			else:
				# Exit the loop and move past its body
				frame.index += body_lines.size() + 1
				continue
		
		elif stripped_line.begins_with("if:"):
			var body_lines = get_block(lines, i)
			var condition = stripped_line.replace("if:", "").strip_edges()
			
			if eval_condition(condition):
				frame.index += 1
				execution_stack.append({"lines": body_lines, "index": 0})
				continue
			else:
				frame.index += body_lines.size() + 1
				continue
		
		elif stripped_line.begins_with("input:"):
			var var_name = stripped_line.replace("input:", "").strip_edges()
			if var_name:
				log_output(">>")
				input_line.show()
				awaiting_input_for_variable = var_name
				frame.index += 1
				return
		
		else:
			parse_line(stripped_line)
			frame.index += 1

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
		execute_program()

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
	if line.is_empty() or line.begins_with("#"):
		return

	if line == "help":
		show_help()
		return

	var parts_reassign = line.split("=", false, 1)
	if parts_reassign.size() == 2:
		var var_name = parts_reassign[0].strip_edges()
		var new_value_expr = parts_reassign[1].strip_edges()
		
		if KEYWORDS.has(var_name):
			log_error("Cannot reassign a reserved keyword: " + var_name)
			return

		if variables.has(var_name):
			var new_value = eval_expression(new_value_expr)
			if new_value != null:
				var var_type = variables[var_name].get("type")
				if var_type == "int":
					if typeof(new_value) == TYPE_INT or (typeof(new_value) == TYPE_STRING and new_value.is_valid_int()):
						variables[var_name].value = int(new_value)
					else:
						log_error("Cannot assign " + typeof_to_string(typeof(new_value)) + " to integer variable '" + var_name + "'")
				elif var_type == "bool":
					if typeof(new_value) == TYPE_BOOL or (typeof(new_value) == TYPE_STRING and (new_value.to_lower() == "true" or new_value.to_lower() == "false")):
						variables[var_name].value = bool(new_value)
					else:
						log_error("Cannot assign " + typeof_to_string(typeof(new_value)) + " to boolean variable '" + var_name + "'")
				else: # string
					variables[var_name].value = str(new_value)
				return
			else:
				log_error("Invalid value for variable reassignment: " + new_value_expr)
				return
	
	if line.begins_with("print"):
		var value_expr = line.substr(6, line.length() - 6).strip_edges()
		var result = eval_print_expression(value_expr)
		if result != null:
			log_output(str(result))
		else:
			log_error("Unknown print value: " + value_expr)

	elif line.begins_with("vs"):
		var parts = line.split(" ", false, 3)
		if parts.size() < 4 or parts[2] != "=":
			log_error("Invalid string variable declaration: " + line)
			return
		var var_name = parts[1]
		var raw_value = line.substr(line.find("=") + 1, line.length() - line.find("=") - 1).strip_edges()
		var eval_result = eval_print_expression(raw_value)
		if typeof(eval_result) == TYPE_STRING:
			variables[var_name] = {"type": "string", "value": eval_result}
		else:
			log_error("Invalid value for string variable: " + raw_value)

	elif line.begins_with("vi"):
		var parts = line.split(" ", false, 3)
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
		var parts = line.split(" ", false, 3)
		if parts.size() < 4 or parts[2] != "=":
			log_error("Invalid boolean variable declaration: " + line)
			return
		var var_name = parts[1]
		var raw_value = line.substr(line.find("=") + 1, line.length()).strip_edges()
		var eval_result = eval_literal(raw_value)
		if typeof(eval_result) == TYPE_BOOL:
			variables[var_name] = {"type": "bool", "value": eval_result}
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

func typeof_to_string(type: int):
	match type:
		TYPE_NIL: return "Nil"
		TYPE_BOOL: return "Boolean"
		TYPE_INT: return "Integer"
		TYPE_FLOAT: return "Float"
		TYPE_STRING: return "String"
		_: return "Unknown"
		
func eval_literal(expr: String):
	if expr.begins_with("\"") and expr.ends_with("\""):
		return expr.substr(1, expr.length() - 2)
	if expr.to_lower() == "true":
		return true
	if expr.to_lower() == "false":
		return false
	if expr.is_valid_int():
		return int(expr)
	if expr.is_valid_float():
		return float(expr)
	if variables.has(expr):
		return variables[expr].value
	return null

func eval_print_expression(expr: String):
	var parts = expr.split("+")
	var result = ""
	for part in parts:
		var evaluated_part = eval_literal(part.strip_edges())
		if evaluated_part != null:
			result += str(evaluated_part)
		else:
			# If it's a math expression, evaluate it with eval_expression
			var math_result = eval_expression(part.strip_edges())
			if math_result != null:
				result += str(math_result)
			else:
				# Unknown part
				log_error("Failed to evaluate expression part: " + part)
				return null
	return result

# ---------------------------
# Help command function
func show_help():
	console.clear()
	log_output("--- YOScript Help ---")
	log_output("Blocks are defined by indentation.")
	log_output("print <value>        : Prints a value to the console.")
	log_output("vs <name> = <value>  : Declares a string variable.")
	log_output("vi <name> = <value>  : Declares an integer variable.")
	log_output("vb <name> = <value>  : Declares a boolean variable.")
	log_output("loop:<condition>     : A conditional loop that runs as long as the condition is true.")
	log_output("if:<expr> < <expr> or <expr> == <expr> or <expr> > <expr> or <expr> != <expr> : A conditional statement.")
	log_output("input:<name>         : Prompts for user input and stores it in 'name'.")
	log_output("help                 : Displays this help message.")
	log_output("---")

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
		if current_line_stripped.is_empty() or current_line_stripped.begins_with("#"):
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

func remove_indentation(line: String):
	return line.lstrip(" \t")

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
		"<": result = left_val < right_val
		">": result = left_val > right_val
	
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
	var code = editor.text.split("\n")
	var cs_lines = ["using System;", "", "class Program {", "    static void Main() {"]
	variables.clear() # Clear variables for a clean compile pass
	var i = 0
	while i < code.size():
		var line = code[i].strip_edges()
		
		if line.is_empty() or line.begins_with("#"):
			i += 1
			continue
			
		var block_result = compile_block_statement(line, code, i)
		if block_result.lines.is_empty():
			var stmt_cs = compile_statement(line)
			if not stmt_cs.is_empty():
				cs_lines.append("        " + stmt_cs)
			i += 1
		else:
			cs_lines.append_array(block_result.lines)
			i = block_result.next_index
	cs_lines.append("    }")
	cs_lines.append("}")
	var file = FileAccess.open("Program.cs", FileAccess.WRITE)
	for l in cs_lines:
		file.store_line(l)
	file.close()
	log_output("Compiled to Program.cs")

func compile_block_statement(line: String, lines: Array, line_index: int) -> Dictionary:
	if line.begins_with("if:"):
		var condition = line.replace("if:", "").strip_edges()
		var body_lines = get_block(lines, line_index)
		var cs_lines = ["        if (%s)" % compile_expression_for_csharp(condition), "        {"]
		for b_line in body_lines:
			var stmt_cs = compile_statement(b_line.strip_edges())
			if not stmt_cs.is_empty():
				cs_lines.append("            " + stmt_cs)
		cs_lines.append("        }")
		return {"lines": cs_lines, "next_index": line_index + body_lines.size() + 1}
	elif line.begins_with("loop:"):
		var condition = line.replace("loop:", "").strip_edges()
		var body_lines = get_block(lines, line_index)
		var cs_lines = ["        while (%s)" % compile_expression_for_csharp(condition), "        {"]
		for b_line in body_lines:
			var stmt_cs = compile_statement(b_line.strip_edges())
			if not stmt_cs.is_empty():
				cs_lines.append("            " + stmt_cs)
		cs_lines.append("        }")
		return {"lines": cs_lines, "next_index": line_index + body_lines.size() + 1}
	else:
		return {"lines": [], "next_index": line_index + 1}

func compile_expression_for_csharp(expr: String) -> String:
	expr = expr.strip_edges()
	
	# Handle simple cases for C# compilation
	if variables.has(expr):
		return expr
	if expr.is_valid_int() or expr.is_valid_float():
		return expr
	if expr.begins_with("\"") and expr.ends_with("\""):
		return expr
	if expr == "true" or expr == "false":
		return expr.to_lower()

	# Use a regex-like approach for complex expressions to handle different operators
	var operators = ["==", "!=", "<", ">", "\\+", "-", "\\*", "/"]
	for op in operators:
		var parts = expr.split(op, false, 1)
		if parts.size() == 2:
			var left = compile_expression_for_csharp(parts[0])
			var right = compile_expression_for_csharp(parts[1])
			return "(%s %s %s)" % [left, op.replace("\\", ""), right]
	
	# If nothing else matches, return the expression as-is (might be an unknown var or function)
	return expr

func compile_statement(line: String) -> String:
	line = line.strip_edges()
	if line.begins_with("print"):
		var value = compile_expression_for_csharp(line.substr(6).strip_edges())
		return "Console.WriteLine(%s);" % value
	elif line.begins_with("vs"):
		var parts = line.split("=", false, 1)
		var var_name = parts[0].replace("vs", "").strip_edges()
		var var_value = compile_expression_for_csharp(parts[1].strip_edges())
		variables[var_name] = {"type": "string", "value": null}
		return "string %s = %s;" % [var_name, var_value]
	elif line.begins_with("vi"):
		var parts = line.split("=", false, 1)
		var var_name = parts[0].replace("vi", "").strip_edges()
		var var_value = compile_expression_for_csharp(parts[1].strip_edges())
		variables[var_name] = {"type": "int", "value": null}
		return "int %s = %s;" % [var_name, var_value]
	elif line.begins_with("vb"):
		var parts = line.split("=", false, 1)
		var var_name = parts[0].replace("vb", "").strip_edges()
		var var_value = compile_expression_for_csharp(parts[1].strip_edges())
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
	
	var parts_reassign = line.split("=", false, 1)
	if parts_reassign.size() == 2:
		var var_name = parts_reassign[0].strip_edges()
		var new_value_expr = parts_reassign[1].strip_edges()
		var compiled_expr = compile_expression_for_csharp(new_value_expr)
		return "%s = %s;" % [var_name, compiled_expr]

	return ""
