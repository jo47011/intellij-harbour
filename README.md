# Harbour Language Plugin for PyCharm

A comprehensive plugin for <a href="https://www.jetbrains.com/pycharm/" target="_blank">PyCharm</a> that provides advanced support for the <a href="https://harbour.github.io/" target="_blank">Harbour/Clipper</a> programming language.

## Features

- **[Syntax Highlighting](#syntax-highlighting)** - Complete color coding for Harbour/Clipper keywords, functions, and syntax
- **[Code Completion](#code-completion)** - Intelligent auto-completion for functions, methods, and variables
- **[Function Navigation](#function-navigation)** - Go-to-declaration and reference resolution
- **[Rename Refactoring](#rename-refactoring)** - Safe renaming of functions and variables across projects
- **[Structure View](#structure-view)** - Tree view of functions, procedures, and classes
- **[Code Formatting](#code-formatting)** - Automatic code indentation and formatting
- **[Debugging Support](#debugging)** - Full breakpoint debugging for console and GUI applications

## Installation

1. Download the latest plugin from the <a href="https://github.com/jo47011/intellij-harbour/releases/" target="_blank">releases page</a>
2. In PyCharm: **Settings** → **Plugins** → ⚙️ → **Install Plugin from Disk...**
3. Select the downloaded plugin file and restart PyCharm

### Syntax Highlighting

Full color coding support for Harbour/Clipper syntax with customizable color schemes. Keywords, functions, comments, strings, and operators are distinctly highlighted for better code readability.

![Syntax Highlighting](img/syntax-highlighting.png)
*Enhanced syntax highlighting with customizable color schemes*

### Code Completion

Intelligent auto-completion suggests functions, methods, variables, and Harbour commands as you type. Supports both built-in Harbour functions and user-defined functions from your project.

![Code Completion](img/code-completion.png)
*Smart auto-completion for Harbour functions and variables*

### Function Navigation

Quickly navigate to function definitions with **Ctrl+Click** or **Ctrl+B**. The plugin resolves references across files and provides external documentation links for built-in functions.

![Function Navigation](img/function-navigation.png)
*Function navigation with external documentation links for built-in functions*

### Rename Refactoring

Safely rename functions, procedures, and variables across your entire project with **Shift+F6**. All references are automatically updated while preserving code functionality.

![Rename Refactoring](img/function-rename.png)
*Safe project-wide rename refactoring for functions and variables*

### Structure View

The structure view panel (**Alt+7**) shows a tree overview of functions, procedures, classes, and variables in the current file for easy navigation.

![Structure View](img/structure-view.png)
*Structure view showing project organization*

### Code Formatting

Automatic code indentation and formatting follows Harbour conventions. Customize indentation, line breaks, and statement positioning in settings.

![Code Style Settings](img/settings-codestyle.png)
*Customizable code formatting options*

## Development

This plugin was implemented by <a href="https://openai.com/o1/" target="_blank">OpenAI O1</a> and <a href="https://claude.ai/" target="_blank">Claude</a>. For detailed development insights and experiences, see the [making-of documentation](./MAKING_OF.md).

## Debugging

The plugin provides **full debugging support** for both console and GUI applications with PyCharm debugger integration featuring conditional breakpoints, variable inspection, step debugging, and watches.

### Variable Types Supported

- **Local Variables**: Function/procedure local variables (`LOCAL nVar`)
- **Private Variables**: Private memory variables (`PRIVATE m_nVar`)
- **Public Variables**: Public memory variables (`PUBLIC g_nVar`)
- **Static Variables**: Currently not supported due to Harbour VM limitations

### Setup

1. **Create Debug Configuration** - Use `Harbour Application` type in PyCharm run configurations
   ![Debug Configuration](img/run-debug-config.png)
   *Harbour Application debug configuration settings*

   *Note: Debug flags (`-b -D__HARBOUR_DEBUG__`) are automatically added when using PyCharm debug configurations.*

2.**Set Breakpoints** - Click in the gutter next to line numbers
![Console Debugging](img/debugging-console.png)
*Console debugging with breakpoints and variable inspection*

3. **Start Debugging** - Use Debug button or **Shift+F9**

![GUI Debugging](img/debugging-gui.png)
*GUI debugging with pycharm debugger and variable inspection.*


### Limitations

- **Static Variables**: Static variables are not visible in the debugger due to Harbour VM
  compilation-unit scoping
- **Complex Objects**: Limited support for complex object inspection
- **Remote Debugging**: Currently supports local debugging only (debugging programs running on the
  same machine). Remote debugging would allow debugging Harbour programs running on different
  machines over a network connection.

### Automatic Error Monitoring

The plugin automatically provides clickable stack traces for runtime errors in the PyCharm console.

![Clickable Stack Traces](img/clickable-stacktraces.png)
*Clickable stack traces for quick navigation to error locations*

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

## Building from Source

### Prerequisites

1. **Java Development Kit 11+** - <a href="https://www.oracle.com/java/technologies/downloads/" target="_blank">Download from Oracle</a> or <a href="https://openjdk.org/" target="_blank">OpenJDK</a>
2. **IntelliJ Platform Plugin SDK** - Automatically downloaded by <a href="https://gradle.org/" target="_blank">Gradle</a>

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
   
   *Note: The `gradlew` (Gradle Wrapper) script is included in the repository and automatically downloads the correct Gradle version.*

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

![Tools Settings](img/settings-tools.png)
*Configure Harbour tools, paths, and debugging options*

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

![Code Style Settings](img/settings-codestyle.png)
*Configure indentation, spacing, and formatting rules*

### Color Scheme Settings

Customize syntax highlighting: **Settings** → **Editor** → **Color Scheme** → **Harbour**

![Color Scheme](img/settings-colorscheme.png)
*Customize syntax highlighting colors and themes*

## VS Code Users

For Visual Studio Code users, there's an excellent <a href="https://github.com/APerricone/harbourCodeExtension" target="_blank">Harbour Code Extension</a> available. This VS Code plugin was a great help and inspiration during the development of our PyCharm plugin, providing valuable insights into Harbour language support implementation.

## Roadmap

- **Official JetBrains Plugin** - Submit to JetBrains Marketplace for easier installation
- **Code Analysis** - Advanced linting and static analysis features
