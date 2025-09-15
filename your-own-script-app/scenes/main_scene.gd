extends Control

# ---------------------------
# Keywords for syntax highlighting
const KEYWORDS = ["print", "vs", "vi", "vb", "loop:", "if:", "else", "else if:", "input:", "help", "clear", "random", "len", "timer:", "break", "continue", "func:", "call", "list", "add", "get"]
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
@onready var help = $Help2


# Variable storage
var variables = {}
var functions = {}
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
	copy_button.pressed.connect(_on_copy_pressed)
	build_button.pressed.connect(_on_build_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	browse_button.pressed.connect(_on_browse_pressed)

	editor.text_changed.connect(_on_editor_text_changed)
	
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
	highlighter_theme.add_keyword_color("clear", Color.WHITE)
	highlighter_theme.add_keyword_color("random", Color.WHITE)
	highlighter_theme.add_keyword_color("len", Color.WHITE)
	highlighter_theme.add_keyword_color("timer:", Color.ORANGE)
	highlighter_theme.add_keyword_color("break", Color.RED)
	highlighter_theme.add_keyword_color("continue", Color.RED)
	highlighter_theme.add_keyword_color("func:", Color.PURPLE)
	highlighter_theme.add_keyword_color("call", Color.PURPLE)
	highlighter_theme.add_keyword_color("list", Color.BLUE)
	highlighter_theme.add_keyword_color("add", Color.BLUE)
	highlighter_theme.add_keyword_color("get", Color.BLUE)
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
func _on_run_pressed() -> void:
	console.clear()
	variables.clear()
	functions.clear()
	loop_iterations.clear()
	execution_stack.clear()
	
	var lines = editor.text.split("\n")
	
	# First pass: Find and store all function definitions
	var i = 0
	while i < lines.size():
		var stripped_line = lines[i].strip_edges()
		if stripped_line.begins_with("func:"):
			var func_name = stripped_line.replace("func:", "").strip_edges()
			if func_name.is_empty():
				log_error("Function name not declared.")
				return
			var func_body = get_block(lines, i)
			functions[func_name] = func_body
			i += func_body.size() + 1
		else:
			i += 1
	
	# Second pass: Execute the main body of the program
	execution_stack.append({"lines": lines, "index": 0})
	await execute_program()

func execute_program() -> void:
	while execution_stack.size() > 0:
		var frame = execution_stack.back()
		var lines = frame.lines
		var i = frame.index

		if i >= lines.size():
			execution_stack.pop_back()
			continue

		var line = lines[i]
		var stripped_line = line.strip_edges()
		
		if stripped_line.is_empty() or stripped_line.begins_with("#"):
			frame.index += 1
			continue
		
		# --- New command logic ---
		if stripped_line == "break":
			# Find the parent loop and pop its frame to exit the loop
			var found_loop = false
			while execution_stack.size() > 0:
				var current_frame = execution_stack.back()
				if current_frame.get("parent_loop_index") != null:
					execution_stack.pop_back() # Pop the loop's body frame
					found_loop = true
					break
				execution_stack.pop_back() # Pop any other frames (e.g., if/else)
			if not found_loop:
				log_error("'break' command used outside of a loop.")
				execution_stack.clear()
			continue
		
		if stripped_line == "continue":
			# Find the parent loop and reset its index to the beginning of the loop's body
			var found_loop = false
			for j in range(execution_stack.size() -1, -1, -1):
				var current_frame = execution_stack[j]
				if current_frame.get("parent_loop_index") != null:
					execution_stack.back().index = current_frame.lines.size() # End the current iteration
					found_loop = true
					break
			if not found_loop:
				log_error("'continue' command used outside of a loop.")
				execution_stack.clear()
			continue
		
		if stripped_line.begins_with("func:"):
			# Skip function declaration during execution pass
			var func_body = get_block(lines, i)
			frame.index += func_body.size() + 1
			continue
		# --- End new command logic ---

		if stripped_line.begins_with("loop:"):
			var body_lines = get_block(lines, i)
			var condition = stripped_line.replace("loop:", "").strip_edges()
			
			if eval_condition(condition):
				var loop_id = str(hash(lines) + i)
				loop_iterations[loop_id] = loop_iterations.get(loop_id, 0) + 1
				if loop_iterations[loop_id] > MAX_LOOP_ITERATIONS:
					log_error("Loop exceeded max iterations. It may be an infinite loop.")
					execution_stack.clear()
					return
				
				execution_stack.append({"lines": body_lines, "index": 0, "parent_loop_index": i})
				frame.index = i + 1
				continue
			else:
				frame.index += body_lines.size() + 1
				continue
		
		elif stripped_line.begins_with("if:"):
			var condition = stripped_line.replace("if:", "").strip_edges()
			var block_lines = get_block(lines, i)
			var block_executed = false
			
			if eval_condition(condition):
				execution_stack.append({"lines": block_lines, "index": 0})
				block_executed = true
				
			var current_index = i + block_lines.size() + 1
			
			while current_index < lines.size():
				var next_line = lines[current_index]
				var next_stripped_line = next_line.strip_edges()
				
				if not (next_stripped_line.begins_with("else") or next_stripped_line.begins_with("else if:")):
					break
				
				var next_block_lines = get_block(lines, current_index)
				
				if not block_executed and next_stripped_line.begins_with("else if:"):
					var next_condition = next_stripped_line.replace("else if:", "").strip_edges()
					if eval_condition(next_condition):
						execution_stack.append({"lines": next_block_lines, "index": 0})
						block_executed = true
				elif not block_executed and next_stripped_line.begins_with("else"):
					execution_stack.append({"lines": next_block_lines, "index": 0})
					block_executed = true
				
				current_index += next_block_lines.size() + 1
			
			frame.index = current_index
			continue

		elif stripped_line.begins_with("input:"):
			await get_input_from_user(stripped_line)
			frame.index += 1
			continue

		elif stripped_line.begins_with("timer:"):
			var time_str = stripped_line.replace("timer:", "").strip_edges()
			var time_msec = eval_expression(time_str)
			if typeof(time_msec) == TYPE_INT and time_msec > 0:
				await get_tree().create_timer(float(time_msec) / 1000.0).timeout
			else:
				log_error("Invalid time for 'timer:'. Must be a positive integer.")
			frame.index += 1
			continue
		
		else:
			parse_line(stripped_line)
			frame.index += 1

func get_input_from_user(line: String) -> void:
	var var_name = line.replace("input:", "").strip_edges()
	if var_name:
		log_output(">>")
		input_line.show()
		var input_text = await input_line.text_submitted
		
		if variables.has(var_name):
			var var_type = variables[var_name].get("type")
			if var_type == "int":
				if input_text.is_valid_int():
					variables[var_name].value = int(input_text)
				else:
					log_error("Input is not a valid integer. Defaulting to 0.")
					variables[var_name].value = 0
			elif var_type == "bool":
				variables[var_name].value = (input_text.to_lower() == "true")
			else:
				variables[var_name].value = input_text
		else:
			variables[var_name] = {"type": "string", "value": input_text}
		
		input_line.hide()
		input_line.clear()
	else:
		log_error("Input target variable not declared: " + var_name)

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
	elif line == "clear":
		console.clear()
		return
	elif line.begins_with("random"):
		var parts = line.split(" ")
		if parts.size() != 4:
			log_error("Invalid 'random' syntax. Usage: random <var> <min> <max>")
			return
		
		var var_name = parts[1]
		var min_val = eval_expression(parts[2])
		var max_val = eval_expression(parts[3])
		
		if not variables.has(var_name) or variables[var_name].type != "int":
			log_error("Target variable for 'random' must be a declared integer.")
			return
		
		if typeof(min_val) != TYPE_INT or typeof(max_val) != TYPE_INT:
			log_error("Min and max values for 'random' must be integers.")
			return
		
		randomize()
		variables[var_name].value = randi_range(int(min_val), int(max_val))
		return
	elif line.begins_with("len"):
		var parts = line.split(" ")
		if parts.size() != 2:
			log_error("Invalid 'len' syntax. Usage: len <var_name>")
			return

		var var_name = parts[1]
		if not variables.has(var_name) or variables[var_name].type != "string":
			log_error("Target variable for 'len' must be a declared string.")
			return
		
		var length = variables[var_name].value.length()
		log_output("Length of '" + var_name + "': " + str(length))
		return
	elif line.begins_with("call"):
		var func_name = line.replace("call", "").strip_edges()
		if functions.has(func_name):
			execution_stack.append({"lines": functions[func_name], "index": 0})
		else:
			log_error("Unknown function: " + func_name)
		return
	elif line.begins_with("list"):
		var parts = line.split(" ")
		if parts.size() < 2:
			log_error("Invalid 'list' syntax. Usage: list <var_name>")
			return
		var var_name = parts[1]
		if KEYWORDS.has(var_name):
			log_error("Cannot use a keyword as a list name: " + var_name)
			return
		variables[var_name] = {"type": "list", "value": []}
		return
	elif line.begins_with("add"):
		var parts = line.split(" ", false, 2)
		if parts.size() < 3:
			log_error("Invalid 'add' syntax. Usage: add <list_name> <value>")
			return
		var list_name = parts[1].strip_edges()
		if not variables.has(list_name) or variables[list_name].type != "list":
			log_error("Target variable for 'add' is not a list: " + list_name)
			return
		
		var value = eval_literal(parts[2].strip_edges())
		if value == null:
			# If eval_literal fails, try eval_expression for more complex cases.
			value = eval_expression(parts[2].strip_edges())
		
		if value != null:
			variables[list_name].value.append(value)
		else:
			log_error("Invalid value for 'add' command.")
		return
	elif line.begins_with("get"):
		var parts = line.split(" ")
		if parts.size() != 4:
			log_error("Invalid 'get' syntax. Usage: get <var_name> <list_name> <index>")
			return
		var var_name = parts[1].strip_edges()
		var list_name = parts[2].strip_edges()
		var index = eval_expression(parts[3].strip_edges())
		if not variables.has(list_name) or variables[list_name].type != "list":
			log_error("Target for 'get' is not a list: " + list_name)
			return
		if not variables.has(var_name):
			log_error("Target variable for 'get' not declared: " + var_name)
			return
		if typeof(index) != TYPE_INT or index < 0 or index >= variables[list_name].value.size():
			log_error("Invalid index for 'get' command.")
			return
		
		var value = variables[list_name].value[index]
		var var_type = variables[var_name].get("type")
		if var_type == "int":
			if typeof(value) == TYPE_INT:
				variables[var_name].value = value
			else:
				log_error("Cannot assign non-integer value from list to integer variable.")
		elif var_type == "bool":
			if typeof(value) == TYPE_BOOL:
				variables[var_name].value = value
			else:
				log_error("Cannot assign non-boolean value from list to boolean variable.")
		else:
			variables[var_name].value = str(value)
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
				elif var_type == "string":
					variables[var_name].value = str(new_value)
				else:
					log_error("Cannot reassign a list variable '" + var_name + "' with a single value.")
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
	log_output("print <value>          : Prints a value to the console.")
	log_output("vs <name> = <value>    : Declares a string variable.")
	log_output("vi <name> = <value>    : Declares an integer variable.")
	log_output("vb <name> = <value>    : Declares a boolean variable.")
	log_output("loop:<condition>       : A conditional loop that runs as long as the condition is true.")
	log_output("break                  : Exits the current loop.")
	log_output("continue               : Skips to the next iteration of the current loop.")
	log_output("if:<condition>         : A conditional statement.")
	log_output("else if:<condition>    : An alternative conditional statement.")
	log_output("else                   : A fallback statement if no preceding conditions are met.")
	log_output("func:<name>            : Declares a new function.")
	log_output("call <name>            : Executes a declared function.")
	log_output("list <name>            : Declares an empty list variable.")
	log_output("add <list> <value>     : Adds a value to a list.")
	log_output("get <var> <list> <index>: Gets a value from a list and stores it in <var>.")
	log_output("input:<name>           : Prompts for user input and stores it in 'name'.")
	log_output("clear                  : Clears the console.")
	log_output("random <var> <min> <max> : Generates a random integer and stores it in <var>.")
	log_output("len <var>              : Prints the length of a string variable.")
	log_output("timer: <msec>          : Pauses execution for a specified number of milliseconds.")
	log_output("help                   : Displays this help message.")
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
		if variables[key].type == "list":
			# Expressions don't handle lists, so we use a placeholder
			inputs.append(null)
		else:
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
	var cs_lines = ["using System;", "using System.Collections.Generic;", "", "public class Program", "{"]
	var main_body = ["    public static void Main()", "    {"]
	var func_definitions = {} # Use a dictionary to store function bodies
	variables.clear() # Clear variables for a clean compile pass

	# First pass: Get all variables and function declarations
	var i = 0
	while i < code.size():
		var stripped_line = code[i].strip_edges()
		if stripped_line.begins_with("vs"):
			var var_name = stripped_line.split(" ", false, 2)[1].split("=")[0].strip_edges()
			variables[var_name] = {"type": "string", "value": null}
		elif stripped_line.begins_with("vi"):
			var var_name = stripped_line.split(" ", false, 2)[1].split("=")[0].strip_edges()
			variables[var_name] = {"type": "int", "value": null}
		elif stripped_line.begins_with("vb"):
			var var_name = stripped_line.split(" ", false, 2)[1].split("=")[0].strip_edges()
			variables[var_name] = {"type": "bool", "value": null}
		elif stripped_line.begins_with("list"):
			var var_name = stripped_line.split(" ")[1].strip_edges()
			variables[var_name] = {"type": "list", "value": null}
		elif stripped_line.begins_with("func:"):
			var func_name = stripped_line.replace("func:", "").strip_edges()
			var func_body_lines = get_block(code, i)
			func_definitions[func_name] = func_body_lines
			i += func_body_lines.size()
		i += 1

	# Add class-level variable declarations
	for var_name in variables:
		var var_type = variables[var_name].type
		var type_string = "object"
		if var_type == "string": type_string = "string"
		elif var_type == "int": type_string = "int"
		elif var_type == "bool": type_string = "bool"
		elif var_type == "list": type_string = "List<object>"
		cs_lines.append("    static " + type_string + " " + var_name + ";")
	cs_lines.append("")

	# Compile main body of the program
	var j = 0
	while j < code.size():
		var line = code[j].strip_edges()
		if line.begins_with("func:"):
			var func_body_lines = get_block(code, j)
			j += func_body_lines.size() + 1
			continue
		var stmt_cs = compile_statement(line)
		if not stmt_cs.is_empty():
			main_body.append("        " + stmt_cs)
		j += 1
		
	main_body.append("    }")
	
	# Compile functions
	for func_name in func_definitions:
		var body_lines = func_definitions[func_name]
		cs_lines.append("")
		cs_lines.append("    public static void " + func_name + "()")
		cs_lines.append("    {")
		for compiled_line in compile_block(body_lines):
			cs_lines.append("        " + compiled_line)
		cs_lines.append("    }")

	cs_lines.append_array(main_body)
	cs_lines.append("}")
	var file = FileAccess.open("Program.cs", FileAccess.WRITE)
	for l in cs_lines:
		file.store_line(l)
	file.close()
	log_output("Compiled to Program.cs")

func compile_block(lines: Array, indent_level = 0) -> Array:
	var compiled_lines = []
	var i = 0
	while i < lines.size():
		var line = lines[i]
		var stripped_line = remove_indentation(line)
		
		if stripped_line.is_empty() or stripped_line.begins_with("#"):
			i += 1
			continue

		var block_start_index = i
		var block_lines = get_block(lines, block_start_index)
		
		if stripped_line.begins_with("if:"):
			var condition = stripped_line.replace("if:", "").strip_edges()
			compiled_lines.append("if (%s)" % compile_expression_for_csharp(condition))
			compiled_lines.append("{")
			var inner_block_compiled = compile_block(block_lines, indent_level + 1)
			compiled_lines.append_array(inner_block_compiled)
			compiled_lines.append("}")
			i += block_lines.size() + 1
			
		elif stripped_line.begins_with("loop:"):
			var condition = stripped_line.replace("loop:", "").strip_edges()
			compiled_lines.append("while (%s)" % compile_expression_for_csharp(condition))
			compiled_lines.append("{")
			var inner_block_compiled = compile_block(block_lines, indent_level + 1)
			compiled_lines.append_array(inner_block_compiled)
			compiled_lines.append("}")
			i += block_lines.size() + 1
			
		else:
			var stmt_cs = compile_statement(stripped_line)
			if not stmt_cs.is_empty():
				compiled_lines.append(stmt_cs)
			i += 1
			
	return compiled_lines

func compile_expression_for_csharp(expr: String) -> String:
	expr = expr.strip_edges()
	
	if variables.has(expr):
		return expr
	if expr.is_valid_int() or expr.is_valid_float():
		return expr
	if expr.begins_with("\"") and expr.ends_with("\""):
		return expr
	if expr == "true" or expr == "false":
		return expr.to_lower()

	var operators = ["==", "!=", "<", ">", "\\+", "-", "\\*", "/"]
	for op in operators:
		var parts = expr.split(op, false, 1)
		if parts.size() == 2:
			var left = compile_expression_for_csharp(parts[0])
			var right = compile_expression_for_csharp(parts[1])
			return "(%s %s %s)" % [left, op.replace("\\", ""), right]
	
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
		return "%s = %s;" % [var_name, var_value]
	elif line.begins_with("vi"):
		var parts = line.split("=", false, 1)
		var var_name = parts[0].replace("vi", "").strip_edges()
		var var_value = compile_expression_for_csharp(parts[1].strip_edges())
		variables[var_name] = {"type": "int", "value": null}
		return "%s = %s;" % [var_name, var_value]
	elif line.begins_with("vb"):
		var parts = line.split("=", false, 1)
		var var_name = parts[0].replace("vb", "").strip_edges()
		var var_value = compile_expression_for_csharp(parts[1].strip_edges())
		variables[var_name] = {"type": "bool", "value": null}
		return "%s = %s;" % [var_name, var_value]
	elif line.begins_with("list"):
		var parts = line.split(" ")
		var var_name = parts[1].strip_edges()
		variables[var_name] = {"type": "list", "value": null}
		return "%s = new List<object>();" % var_name
	elif line.begins_with("add"):
		var parts = line.split(" ", false, 2)
		var list_name = parts[1].strip_edges()
		var var_value = compile_expression_for_csharp(parts[2].strip_edges())
		return "%s.Add(%s);" % [list_name, var_value]
	elif line.begins_with("get"):
		var parts = line.split(" ")
		if parts.size() != 4:
			return "" # Avoid compiler error, will be caught by runtime
		var var_name = parts[1].strip_edges()
		var list_name = parts[2].strip_edges()
		var index = compile_expression_for_csharp(parts[3].strip_edges())
		var var_type = variables.get(var_name, {}).get("type", "object")
		var cast = ""
		if var_type == "string": cast = "(string)"
		elif var_type == "int": cast = "(int)"
		elif var_type == "bool": cast = "(bool)"
		return "%s = %s%s[%s];" % [var_name, cast, list_name, index]
	elif line.begins_with("input:"):
		var var_name = line.replace("input:", "").strip_edges()
		var var_type = variables.get(var_name, {}).get("type", "string")
		if var_type == "int":
			return "%s = int.Parse(Console.ReadLine());" % var_name
		elif var_type == "bool":
			return "%s = bool.Parse(Console.ReadLine());" % var_name
		else:
			return "%s = Console.ReadLine();" % var_name
	elif line == "break":
		return "break;"
	elif line == "continue":
		return "continue;"
	elif line.begins_with("call"):
		var func_name = line.replace("call", "").strip_edges()
		return "%s();" % func_name
	
	var parts_reassign = line.split("=", false, 1)
	if parts_reassign.size() == 2:
		var var_name = parts_reassign[0].strip_edges()
		var new_value_expr = parts_reassign[1].strip_edges()
		var compiled_expr = compile_expression_for_csharp(new_value_expr)
		return "%s = %s;" % [var_name, compiled_expr]

	return ""


func _on_docs_pressed() -> void:
	OS.shell_open("https://yourown.yike.games/docs.html")


func _on_help_pressed() -> void:
	help.visible = true
