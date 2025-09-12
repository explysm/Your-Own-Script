# YOScript Language Help


![YOScript Logo](images/YourOwn.png)

This document provides a quick reference for the YOScript language syntax and commands. Blocks of code are defined by indentation.

---

### Basic Commands

| Command | Description | Syntax & Example |
| :--- | :--- | :--- |
| **`print`** | Prints a literal value or the value of a variable to the console. | **Syntax:**<br>`print "<value>"`<br>`print <variable>`<br><br>**Example:**<br>`vs message = "Hello"`<br>`print "Hello, World!"`<br>`print message` |
| **`help`** | Displays this help message. | **Syntax:**<br>`help` |
| **`clear`** | Clears the console. | **Syntac:**<br>`clear` |
---

### Variable Declaration

| Command | Type | Description | Syntax & Example |
| :--- | :--- | :--- | :--- |
| **`vs`** | String | Declares a string variable. | **Syntax:**<br>`vs <name> = "<value>"`<br><br>**Example:**<br>`vs my_name = "YOScript"` |
| **`vi`** | Integer | Declares an integer variable. | **Syntax:**<br>`vi <name> = <value>`<br><br>**Example:**<br>`vi my_age = 10` |
| **`vb` | Boolean | Declares a boolean variable. | **Syntax:**<br>`vb <name> = <value>`<br><br>**Example:**<br>`vb is_active = true` |

---

### Control Flow and Conditionals

The `loop`, `else if`, and `if` commands all  rely on the same conditional expressions to evaluate whether a statement is true or false.

#### Operators:
- ` < ` (less than)
- ` > ` (greater than)
- ` == ` (equal to)
- ` != ` (not equal to)

| Command | Description | Syntax & Example |
| :--- | :--- | :--- |
| **`if`** | A conditional statement that runs its block of code once if the condition is true. | **Syntax:**<br>`if: <expr> <operator> <expr>`<br><br>**Example:**<br>`vi user_age = 21`<br>`if: user_age > 18`<br>&nbsp;&nbsp;&nbsp;&nbsp;`print "You are an adult."` |
| **`loop`** | A conditional loop that continues to run its block of code as long as the condition is true. | **Syntax:**<br>`loop: <condition>`<br><br>**Example:**<br>`vi count = 0`<br>`loop: count < 5`<br>&nbsp;&nbsp;&nbsp;&nbsp;`print count`<br>&nbsp;&nbsp;&nbsp;&nbsp;`count = count + 1` |
| **`else if`** | A conditional statement that runs its block of code once after 'if',  if the condition is true. | **Syntax:**<br>`else if: <condition>`<br><br>**Example:**<br>`vi user_age = 21`<br>`if: user_age > 18`<br>&nbsp;&nbsp;&nbsp;&nbsp;`print "You are an adult."`<br>`else if: user_age < 18`<br>&nbsp;&nbsp;&nbsp;&nbsp;`print "You are not an adult."` | 
---

### User Input

| Command | Description | Syntax & Example |
| :--- | :--- | :--- |
| **`input`** | Prompts the user for input and stores the value in a specified variable. | **Syntax:**<br>`input: <variable_name>`<br><br>**Example:**<br>`input: username`<br>`print "Hello, " + username` |
