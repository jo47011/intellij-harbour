# Harbour Language IntelliJ Plugin

# Harbour Language Plugin for IntelliJ

A plugin for IntelliJ IDEA that provides support for the Harbour/Clipper programming language.

## Features

- Syntax highlighting
- Code completion
- Function and procedure navigation
- Reference resolution
- Rename refactoring
- Structure view
- Code formatting
- Debugging

## Introduction

This package was purely implemented by O1 pro and Claude 3.7.  No code was written by myself.  I just did the
orchestration and provided some help here and there.  If you are interested in my experiences see the making-of.

## Installation

1. Download the latest release from the JetBrains Plugin Repository
2. Install the plugin from disk in IntelliJ IDEA (Settings → Plugins → ⚙️ → Install Plugin from Disk...)

## Usage Example

The plugin supports standard Harbour/Clipper code syntax:

![Syntax Highlighting](example.png)

## Building from Source

To build the plugin from source:

```bash
./gradlew buildPlugin
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.


## Logging

// Simple usage (auto-detects project)
HarbourLogger.log("ComponentName", "Log message");

// With explicit project reference
HarbourLogger.log(project, "ComponentName", "Log message");

-----

## File Exclusion

The Harbour plugin allows you to exclude specific files from navigation and indexing. This is useful for:

- Improving performance by skipping large generated files
- Avoiding navigation to library or third-party code
- Focusing on your own source code during development

### How to Configure Excluded Files

1. Go to **Settings** > **Languages & Frameworks** > **Harbour**
2. Under "Files excluded from navigation (won't be indexed)", use:
  - **+** button to add a new file
  - **-** button to remove selected files
  - Up/down arrows to reorder the list

### Effects of Exclusion

When a file is excluded:

- Its functions won't appear in code completion suggestions
- Go to Declaration won't navigate to functions defined in excluded files
- Find Usages won't include references from excluded files
- Code highlighting for unresolved references won't report references to excluded files

### Best Practices

- Exclude test files if they're not relevant to your main development
- Exclude large generated code files that slow down indexing
- Don't exclude files that contain functions you regularly need to navigate to

Changes to excluded files take effect after restarting the IDE or manually refreshing the Harbour indexes.

# TODOs

- navigation
  - should be correct while you type / after return
  - LOCAL oB := BClass():New(oA) clicking on new should go to the correct new() method / show popup

- remove garbage from idea log

- navigation
  - LOCAL oB := BClass():New(oA) clicking on new should go to the correct new() method / show popup
  - LOCAL GetList:={}, dateiName, shift := 0, gbsArt, anz_ls := 1
    not working
  - pre-index so navigation becomes quicker
  
- Tab should have the same as indent (2 in my case)
- indentation 
  - should be correct while you type / after return
  - only return at eof should be left aligned, e.g. this not:
    if ...
      ... 
RETURN
    endif

- code completion should propose local and public vars as well

- compile/link errors:
  - hbmk2: Error: Referenced, missing, but unknown function(s): FOO()
    foo() should be clickable

- remove garbage from idea log

- external functions are no longer recognized as such -> no external link opened


- Debugger in pycharm?

- making-of schreiben:
  - Erfahrung O1 Pro vs claude, evtl. als Tabelle
  - mein prompt Vorgaben etc.