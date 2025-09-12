# YOScript Language Help

![YOScript Logo](images/YourOwn.png)

This document provides a quick reference for the YOScript language syntax and commands. Blocks of code are defined by indentation.

---

### Basic Commands

| Command | Description | Syntax |
| :--- | :--- | :--- |
| **`print`** | Prints a literal value or the value of a variable to the console. | `print "Hello, world!"`<br>`print my_variable` |
| **`help`** | Displays this help message. | `help` |

---

### Variable Declaration

| Command | Type | Description | Syntax |
| :--- | :--- | :--- | :--- |
| **`vs`** | String | Declares a string variable. | `vs my_name = "YOScript"` |
| **`vi`** | Integer | Declares an integer variable. | `vi my_age = 10` |
| **`vb`** | Boolean | Declares a boolean variable. | `vb is_active = true` |

---

### Control Flow

| Command | Description | Syntax |
| :--- | :--- | :--- |
| **`loop`** | A conditional loop that runs as long as the condition is true. | `loop: <condition>` |
| **`if`** | A conditional statement. | `if: <expression> <operator> <expression>` |

#### Operators for `if` statements:

-   ` < ` (less than)
-   ` > ` (greater than)
-   ` == ` (equal to)
-   ` != ` (not equal to)

**Example:**
