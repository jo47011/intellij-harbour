# Harbour Language Plugin for PyCharm

A comprehensive plugin for <a href="https://www.jetbrains.com/pycharm/" target="_blank">PyCharm</a> that provides
advanced support for the <a href="https://harbour.github.io/" target="_blank">Harbour/Clipper</a> programming language.

This plugin was implemented as `vibe-coding` project using <a href="https://openai.com/o1/" target="_blank">OpenAI
O1</a>
and <a href="https://claude.ai/" target="_blank">Claude</a>. For detailed development insights and experiences, see
the [MAKING-OF](./MAKING_OF.md).

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Settings](#settings)
- [License](#license)
- [VS Code Users](#vs-code-users)
- [Roadmap](#roadmap--todos)
- [Known Issues](#known-issues)

## Features

- **[Syntax Highlighting](#syntax-highlighting)** - Complete color coding for Harbour/Clipper keywords, functions, and
  syntax
- **[Code Completion](#code-completion)** - Intelligent auto-completion for functions, methods, and variables
- **[Function Navigation](#function-navigation)** - Go-to-declaration and reference resolution
- **[Rename Refactoring](#rename-refactoring)** - Safe renaming of functions and variables across projects
- **[Structure View](#structure-view)** - Tree view of functions, procedures, and classes
- **[Code Formatting](#code-formatting)** - Automatic code indentation and formatting
- **[Linting](#linting)** - Real-time code analysis and error detection
- **[Debugging](#debugging)** - Full breakpoint debugging for console and GUI applications
- **[Automatic Error Monitoring](#automatic-error-monitoring)** - Clickable stack traces for runtime errors
- **[Code Helpers](#code-helpers)** - Quick actions to improve code quality and reduce typing

## Installation

1. Download the latest plugin from the <a href="https://github.com/jo47011/intellij-harbour/releases/" target="_blank">
   releases page</a>
2. In PyCharm: **Settings** → **Plugins** → ⚙️ → **Install Plugin from Disk...**
3. Select the downloaded plugin file and restart PyCharm

### Syntax Highlighting

Full color coding support for Harbour/Clipper syntax with customizable color schemes. Keywords, functions, comments,
strings, and operators are distinctly highlighted for better code readability.

<p align="center">
  <img src="img/syntax-highlighting.png" alt="Syntax Highlighting"/>
  <br>
  <em>Enhanced syntax highlighting with customizable color schemes</em>
</p>

### Code Completion

Intelligent auto-completion suggests functions, methods, variables, and Harbour commands as you type. Supports both
built-in Harbour functions and user-defined functions from your project.

<p align="center">
  <img src="img/code-completion.png" alt="Code Completion"/>
  <br>
  <em>Smart auto-completion for Harbour functions and variables</em>
</p>

### Function Navigation

Quickly navigate to function definitions with **Ctrl+Click** or **Ctrl+B**.
The plugin resolves references across files for custom defined and built-in functions, variables, etc.
For external harbour functions an external documentation link (configurable in the settings) will be opend.

<p align="center">
  <img src="img/function-navigation.png" alt="Function Navigation"/>
  <br>
  <em>Function navigation with external documentation links for built-in functions</em>
</p>

Same applies for procedures, classes, methods and variables. Newly added function, procedures, etc. are added to the
index once the file is saved.

### Rename Refactoring

Safely rename functions, procedures, and variables across your entire project with **Shift+F6**. All references are
automatically updated while preserving code functionality.

<p align="center">
  <img src="img/function-rename.png" alt="Rename Refactoring"/>
  <br>
  <em>Safe project-wide rename refactoring for functions and variables</em>
</p>

### Structure View

The structure view panel (**Alt+7**) shows a tree overview of functions, procedures, classes, and variables in the
current file for easy navigation.

<p align="center">
  <img src="img/structure-view.png" alt="Structure View"/>
  <br>
  <em>Structure view showing project organization</em>
</p>

### Code Formatting

Automatic code indentation and formatting follows Harbour conventions. Customize indentation, line breaks, and statement
positioning in settings.

<p align="center">
  <img src="img/settings-formatting.png" alt="Code Style Settings Format"/>
  <br>
  <em>Customizable code formatting options</em>
</p>

### Linting

Real-time code analysis provides instant feedback on syntax errors, undefined variables, and potential issues as you
type. The linting engine integrates seamlessly with PyCharm's inspection framework.

<p align="center">
  <img src="img/linting.png" alt="Linting"/>
  <br>
  <em>Real-time linting highlights syntax errors and undefined variables</em>
</p>

Configure linting settings in **Settings** → **Tools** → **Harbour** → **Linting**:

<p align="center">
  <img src="img/settings-linting.png" alt="Linting Settings"/>
  <br>
  <em>Customizable linting rules and severity levels</em>
</p>

> **Note:** For proper linting functionality, ensure all include paths are correctly configured in your project settings. Missing include files or incorrect paths may prevent the linter from detecting syntax errors and unused variables.

## Debugging

The plugin provides **full debugging support** for both console and GUI applications with PyCharm debugger integration
featuring conditional breakpoints, variable inspection, step debugging, and watches.

### Variable Types Supported

- **Local Variables**: Function/procedure local variables (`LOCAL nVar`)
- **Private Variables**: Private memory variables (`PRIVATE m_nVar`)
- **Public Variables**: Public memory variables (`PUBLIC g_nVar`)
- **Static Variables**: Currently not supported due to Harbour VM limitations

### Setup

1. **Create Debug Configuration** - Use `Harbour Application` type in PyCharm run configurations
   <p align="center">
     <img src="img/run-debug-config.png" alt="Debug Configuration"/>
     <br>
     <em>Harbour Application debug configuration settings</em>
   </p>

   *Note: Debug flags (`-b -D__HARBOUR_DEBUG__`) are automatically added when using PyCharm debug configurations.*

2.**Set Breakpoints** - Click in the gutter next to line numbers
<p align="center">
  <img src="img/debugging-console.png" alt="Console Debugging"/>
  <br>
  <em>Console debugging with breakpoints and variable inspection</em>
</p>

3. **Start Debugging** - Use Debug button or **Shift+F9**

<p align="center">
  <img src="img/debugging-gui.png" alt="GUI Debugging"/>
  <br>
  <em>GUI debugging with PyCharm debugger and variable inspection</em>
</p>

### Limitations

- **Static Variables**: Static variables are not visible in the debugger due to Harbour VM
  compilation-unit scoping
- **Complex Objects**: Limited support for complex object inspection
- **Remote Debugging**: Currently supports local debugging only (debugging programs running on the
  same machine). Remote debugging would allow debugging Harbour programs running on different
  machines over a network connection.

### Automatic Error Monitoring

The plugin automatically provides clickable stack traces for runtime errors in the PyCharm console.

<p align="center">
  <img src="img/clickable-stacktraces.png" alt="Clickable Stack Traces"/>
  <br>
  <em>Clickable stack traces for quick navigation to error locations</em>
</p>

### Custom ErrorBlock Integration

If your project uses a custom ErrorBlock handler, you can still get clickable stack traces by
calling `printDebugStackTrace()` from your error handler:

```harbour
// Your custom error handling
ErrorBlock({|oError| MyCustomHandler(oError)})

FUNCTION MyCustomHandler(oError)
   // Your custom error logic here
   LogToMyDatabase(oError)
   SaveToLogFile(oError)
   
   // Generate PyCharm-compatible stack trace
   printDebugStackTrace()
   
   // Continue with your error handling
   QUIT
RETURN NIL
```

**Key points:**

- Add `printDebugStackTrace()` to your custom error handler
- This generates clickable stack traces in PyCharm console
- Works alongside your existing error handling logic

## Code Helpers

The plugin provides quick actions to improve code quality and reduce repetitive typing:

### Declare Local Variable (Alt+L)

Quickly declare undefined variables as LOCAL with proper placement and indentation.

**How to use:**
1. Place cursor on any undefined variable in your code
2. Press **Alt+L** 
3. The plugin automatically:
   - Detects the variable name under cursor
   - Finds the containing function or procedure
   - Adds `LOCAL variableName` declaration at the proper position
   - Respects your LOCAL indentation settings

**Example:**
```harbour
FUNCTION TestFunction()
   LOCAL existingVar
   
   myNewVar := 10  // Place cursor on 'myNewVar' and press Alt+L
   // Plugin will add: LOCAL myNewVar
```

**Features:**
- Smart placement after existing LOCAL declarations
- Validates variable names (prevents declaring keywords)
- Checks for duplicate declarations
- Uses indentation from code style settings
- Shows helpful notifications for errors or success

## Building from Source

### Prerequisites

1. **Java Development Kit 11+** - <a href="https://www.oracle.com/java/technologies/downloads/" target="_blank">Download
   from Oracle</a> or <a href="https://openjdk.org/" target="_blank">OpenJDK</a>
2. **IntelliJ Platform Plugin SDK** - Automatically downloaded by <a href="https://gradle.org/" target="_blank">
   Gradle</a>

### Build Steps

1. **Clone the repository:**
   ```bash
   git clone https://github.com/jo47011/intellij-harbour.git
   cd intellij-harbour
   ```

2. **Verify Java version:**
   ```bash
   java -version  # Should show Java 11 or higher
   ```

3. **Build the plugin:**
   ```bash
   ./gradlew buildPlugin  # Linux/macOS
   gradlew.bat buildPlugin  # Windows
   ```

   *Note: The `gradlew` (Gradle Wrapper) script is included in the repository and automatically downloads the correct
   Gradle version.*

4. **Find the built plugin:**
   ```
   build/distributions/harbour-language-plugin-x.x.x.zip
   ```

### Development Setup

For plugin development, you can also run a development instance:

```bash
./gradlew runIde
```

This launches PyCharm with the plugin pre-installed for testing.

## License

This project is licensed under the [MIT License](./LICENSE).

## Settings

Access Harbour plugin settings: **Settings** → **Tools** → **Harbour**

<p align="center">
  <img src="img/settings-tools.png" alt="Tools Settings"/>
  <br>
  <em>Configure Harbour tools, paths, and debugging options</em>
</p>

### Configuration Options

- **Documentation URL** - Base URL for external Harbour documentation
- **Debug Log Directory** - Location for debug logs (empty to disable)
- **Build Output Directory** - Default `.hbmk` for build artifacts
- **Auto-completion** - Enable while typing (default: Ctrl+Space only)
- **Include Paths** - Add directories for #include file resolution
- **Excluded Files** - Files to exclude from navigation and indexing
- **Commands** - Customize code completion command list

### Code Style Settings

Customize code formatting: **Settings** → **Editor** → **Code Style** → **Harbour**

<p align="center">
  <img src="img/settings-codestyle.png" alt="Code Style Settings"/>
  <br>
  <em>Configure indentation, spacing, and formatting rules</em>
</p>

### Color Scheme Settings

Customize syntax highlighting: **Settings** → **Editor** → **Color Scheme** → **Harbour**

<p align="center">
  <img src="img/settings-colorscheme.png" alt="Color Scheme Settings"/>
  <br>
  <em>Customize syntax highlighting colors and themes</em>
</p>

## VS Code Users

For Visual Studio Code users, there's an
excellent <a href="https://github.com/APerricone/harbourCodeExtension" target="_blank">Harbour Code Extension</a>
available. This VS Code plugin was a great help and inspiration during the development of our PyCharm plugin, providing
valuable insights into Harbour language support implementation.

## Roadmap / TODOs

- **Official JetBrains Plugin** - Submit to JetBrains Marketplace for easier installation
- **Process Coupling** - When the debugging process in PyCharm is stopped the running harbour GUI should be terminated
  as well.
- **Tests** - write tests.

## Known Issues

- **Ctrl+hover** should not show tooltip
- **Ctrl-click**: sometimes on 1st click navigates to function directly instead of opening dialog. 2nd and further
  clicks work fine.
- most function/procedure features do not work yet for truncated keywords func/proce.
- Internal function navigation may jump to function definition instead of showing a declaration dialog
  if the file w/ the function definition misses some include file or if the list of usages is very long.
  Subsequent click on function declaration itself work.





