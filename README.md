# Harbour Language Plugin for IntelliJ Platform

A comprehensive language support plugin for Harbour/xHarbour programming language, compatible with IntelliJ IDEA, PyCharm, and other JetBrains IDEs.

[![Plugin Version](https://img.shields.io/badge/version-1.0.498-blue.svg)](https://github.com/yourusername/intellij-harbour)
[![IntelliJ Platform](https://img.shields.io/badge/platform-2024.3.4-orange.svg)](https://plugins.jetbrains.com/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## ✨ Features

### 🎨 **Language Support**
- **Advanced Syntax Highlighting** with customizable colors for keywords, strings, functions, and comments
- **Intelligent Code Completion** for functions, methods, variables, and DATA fields
- **Structure View** with class hierarchy and method navigation
- **Code Formatting** with auto-indentation and custom style settings
- **File Extensions**: Full support for `.prg` and `.hb` files

### 🧭 **Navigation & References**
- **Go-to-Declaration** for functions, methods, classes, and variables
- **Enhanced Navigation Popup** with syntax highlighting and precise column alignment
- **External Function Documentation** - Ctrl+click opens Harbour documentation in browser
- **Include File Resolution** with case-insensitive search and multiple path support
- **Find Usages** with comprehensive reference tracking
- **Class Property Navigation** - Navigate between DATA declarations and `::property` usage

### 🐛 **Debugging Features**
The plugin provides **dual debugging support** with automatic detection:

- **Console Applications**: Full PyCharm debugger integration
  - Conditional breakpoints with expressions (`counter > 5`)
  - Variable inspection (LOCAL, PRIVATE, PUBLIC variables)
  - Step debugging (Step Into, Step Over, Step Out)
  - Watch expressions and evaluate functionality
  
- **GUI Applications**: Harbour internal debugger with breakpoints in `init.cld`
- **Smart Detection**: Automatically chooses method based on GUI flags in .hbp files
- **Socket Protocol**: Debug communication on port 9876

### 🛠 **Development Tools**
- **Compiler Error Navigation** - Click on error messages to jump to source
- **Missing Function Detection** - Navigate to undefined function references
- **Browser Configuration Notifications** for external documentation access
- **Custom Run/Debug Configurations** for Harbour applications
- **File Exclusion Settings** to improve performance and focus navigation

### ⚙️ **Customization**
- **Color Settings Page** for syntax highlighting customization
- **Code Style Settings** with Harbour-specific formatting rules
- **Application Settings** for include paths and excluded files
- **Notification System** with configurable browser failure detection

## 🚀 Installation

### From JetBrains Plugin Repository
1. Open **Settings/Preferences** → **Plugins**
2. Search for "Harbour Language Support"
3. Click **Install** and restart IDE

### From Release File
1. Download the latest `.zip` file from [Releases](../../releases)
2. Open **Settings/Preferences** → **Plugins** → **⚙️ Settings** → **Install Plugin from Disk...**
3. Select the downloaded file and restart IDE

## 🏗️ Building from Source

### Prerequisites
- **Java 17** or higher
- **Gradle 8.0+** 
- **IntelliJ Platform SDK**

### Build Commands
```bash
# Build the plugin
./gradlew buildPlugin

# Run in development IDE
./gradlew runIde

# Run tests
./gradlew test

# Clean build artifacts
./gradlew clean
```

The built plugin will be in `build/distributions/harbour-language-plugin-X.X.XXX.zip`

## 🐛 Debugging Setup

### For Console Applications
1. **Compile with Debug Info**:
   ```bash
   hbmk2 yourprogram.prg -b -D__HARBOUR_DEBUG__
   ```
   
2. **Create Harbour Debug Configuration** in IntelliJ
3. **Set Breakpoints** by clicking in the gutter
4. **Start Debugging** with the Debug button or **Shift+F9**

### Variable Types Supported
- **LOCAL Variables**: `LOCAL nCounter := 0`
- **PRIVATE Variables**: `PRIVATE m_cName := "John"`  
- **PUBLIC Variables**: `PUBLIC g_lDebug := .T.`
- **Static Variables**: Currently not supported due to Harbour VM limitations

### Debug Protocol
- Uses socket-based communication (default port 9876)
- Automatic integration when compiling with `-D__HARBOUR_DEBUG__`
- Supports both local and remote debugging scenarios

## 📁 Project Structure

```
intellij-harbour/
├── src/main/java/org/intellij/sdk/language/
│   ├── HarbourGoToDeclarationHandler.java    # Navigation logic
│   ├── HarbourSyntaxHighlighter.java         # Syntax highlighting  
│   ├── HarbourDebuggerRunner.java            # Debug configuration
│   ├── HarbourExternalDocumentationHandler.java  # External docs
│   └── ...
├── src/main/resources/
│   ├── META-INF/plugin.xml                   # Plugin configuration
│   └── debug/harbour_debug.prg               # Debug library
├── src/main/grammar/
│   └── Harbour.flex                          # Lexer definition
└── build.gradle                              # Build configuration
```

## 🔧 Configuration

### Include Paths
Configure Harbour include directories in **Settings** → **Languages & Frameworks** → **Harbour**:
- Add your Harbour installation include directory
- Add project-specific include paths
- Configure HARBOUR_HOME environment variable

### File Exclusions
Exclude files from navigation and indexing to improve performance:
- Large generated files
- Third-party library code  
- Debug and temporary files

### Browser Configuration
For external documentation links:
1. Configure default browser in IDE settings
2. Ensure internet connectivity for Harbour documentation
3. Use notification system to troubleshoot browser issues

## 🔗 External Documentation

The plugin integrates with Harbour online documentation:
- **Function References**: Links to `https://harbour.github.io/doc/`
- **Ctrl+Click Navigation**: Opens documentation in configured browser
- **Smart Fallback**: Shows notification if browser fails to open
- **URL Copying**: Easy access to documentation URLs

## 🐞 Troubleshooting

### Debug Connection Issues
- Ensure port 9876 is not blocked by firewall
- Check that Harbour program is compiled with debug flags
- Verify `HB_REMOTE_DEBUG=1` environment variable is set

### Navigation Problems  
- Rebuild project indexes: **File** → **Invalidate Caches and Restart**
- Check include paths in Harbour settings
- Verify file exclusion settings aren't hiding target files

### Browser Not Opening
- Check browser configuration in IDE settings
- Test with different browsers
- Review notification messages for specific error details

### Performance Issues
- Add large generated files to exclusion list
- Limit include path scope to essential directories
- Consider increasing IDE memory allocation

## 📝 Version History

- **v1.0.498** - Navigation popup improvements, version compatibility fixes
- **v1.0.496** - Fixed case-sensitive missing function navigation  
- **v1.0.495** - Universal browser failure detection for external functions
- **v1.0.490** - Enhanced missing function navigation with clickable error messages
- **v1.0.470** - Perfect navigation popup alignment and visual consistency
- **v1.0.426** - PropertyAccess navigation fixes for class DATA fields

See [VERSION_HISTORY.md](VERSION_HISTORY.md) for complete changelog.

## 🤝 Contributing

This plugin was developed using AI assistance (Claude 3.7 and O1 Pro) with human orchestration. Contributions are welcome:

1. **Fork** the repository
2. **Create** a feature branch
3. **Make** your changes following existing code style
4. **Test** thoroughly with sample Harbour projects
5. **Submit** a pull request with detailed description

### Development Guidelines
- Follow existing Java code conventions
- Add comprehensive logging using `HarbourLogger.java`
- Update plugin version in both `build.gradle` and `plugin.xml`
- Test with both GUI and console Harbour applications
- Document any new features in README and VERSION_HISTORY

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Harbour Development Team** for the excellent programming language
- **JetBrains** for the IntelliJ Platform SDK and documentation
- **AI Development Partners** (Claude 3.7, O1 Pro) for code generation assistance
- **Harbour Community** for feedback and testing

## 🔗 Links

- [Harbour Language Official Site](https://harbour.github.io/)
- [IntelliJ Platform SDK Documentation](https://plugins.jetbrains.com/docs/intellij/)
- [JetBrains Plugin Repository](https://plugins.jetbrains.com/)
- [Issue Tracker](../../issues)

---

**Note**: This plugin provides comprehensive Harbour language support with advanced debugging capabilities. For best results, ensure your Harbour compiler supports debug information generation and your projects are properly configured with include paths.