#!/bin/bash
#
# Harbour Code Formatter - Command Line Interface
#
# This script launches PyCharm/IntelliJ with the Harbour plugin in headless mode
# to format Harbour (.prg) files using our custom PostFormatProcessor.
#
# Usage:
#   ./harbour-format.sh [options] <file-or-directory>
#
# Options:
#   --dry-run     Show formatted output without modifying files
#   --verbose     Show detailed processing information
#   --compile     Compile file after formatting to verify
#   --recursive   Process directories recursively
#   --help, -h    Show help message
#
# Examples:
#   ./harbour-format.sh /path/to/file.prg
#   ./harbour-format.sh --recursive /path/to/directory
#   ./harbour-format.sh --compile --verbose /path/to/file.prg
#

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Find the IntelliJ/PyCharm sandbox
SANDBOX_DIR="${PROJECT_DIR}/build/idea-sandbox"

# Find the latest sandbox version
if [ -d "${SANDBOX_DIR}" ]; then
    SANDBOX_VERSION=$(ls -1 "${SANDBOX_DIR}" | head -1)
    IDEA_HOME="${SANDBOX_DIR}/${SANDBOX_VERSION}"
else
    echo "Error: Sandbox not found at ${SANDBOX_DIR}"
    echo "Please build the plugin first with: ./gradlew buildPlugin"
    exit 1
fi

# Find the IntelliJ Community installation
IDEA_IC_DIR=$(find ~/.gradle/caches -name "ideaIC-*" -type d 2>/dev/null | head -1)

if [ -z "${IDEA_IC_DIR}" ]; then
    echo "Error: IntelliJ IDEA Community not found in Gradle cache"
    echo "Please run: ./gradlew runIde (once) to download IntelliJ"
    exit 1
fi

echo "Using IntelliJ from: ${IDEA_IC_DIR}"
echo "Using Sandbox: ${IDEA_HOME}"

# Set environment variables for the sandbox
export IDEA_CONFIG_PATH="${IDEA_HOME}/config"
export IDEA_SYSTEM_PATH="${IDEA_HOME}/system"
export IDEA_PLUGINS_PATH="${IDEA_HOME}/plugins"

# Run IntelliJ with our command
exec "${IDEA_IC_DIR}/bin/idea.sh" harbourFormat "$@"
