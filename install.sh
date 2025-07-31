#!/usr/bin/env bash
# Universal AI Context Management System Installer
# Works with Claude, Cursor, Copilot, Gemini, OpenAI, and any AI provider

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Installation paths
readonly INSTALL_DIR="${HOME}/.local/bin"
readonly DOTFILES_DIR="${HOME}/.config/dotfiles-context"

echo -e "${BLUE}Universal AI Context Management System${NC}"
echo -e "${BLUE}=====================================\n${NC}"
echo "🧠 Works with Claude, Cursor, Copilot, Gemini, OpenAI & more!"
echo

# Detect installation method
if [[ -f "context.sh" ]]; then
    # Local installation
    INSTALL_TYPE="local"
    echo "📦 Installing from local files..."
elif command -v curl >/dev/null 2>&1; then
    # Remote installation via curl
    INSTALL_TYPE="remote"
    echo "🌐 Installing from GitHub..."
    REPO_URL="https://raw.githubusercontent.com/anivar/dotfiles-context/main"
else
    echo -e "${RED}Error: No installation method available${NC}"
    echo "Either run from the source directory or install curl"
    exit 1
fi

# Create directories
echo "📁 Creating installation directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$DOTFILES_DIR"

# Install files based on method
if [[ "$INSTALL_TYPE" == "local" ]]; then
    # Copy local files
    echo "📋 Installing context system..."
    cp context.sh "$DOTFILES_DIR/context.sh"
    [[ -f "bin/context" ]] && cp bin/context "$INSTALL_DIR/context"
else
    # Download from remote
    echo "⬇️  Downloading context system..."
    curl -sSL "$REPO_URL/context.sh" -o "$DOTFILES_DIR/context.sh"
    curl -sSL "$REPO_URL/bin/context" -o "$INSTALL_DIR/context"
fi

# Make executable
chmod +x "$DOTFILES_DIR/context.sh"
chmod +x "$INSTALL_DIR/context" 2>/dev/null || true

# Detect shell
SHELL_NAME="$(basename "$SHELL")"
SHELL_RC=""

case "$SHELL_NAME" in
    bash)
        SHELL_RC="$HOME/.bashrc"
        [[ -f "$HOME/.bash_profile" ]] && SHELL_RC="$HOME/.bash_profile"
        ;;
    zsh)
        SHELL_RC="$HOME/.zshrc"
        ;;
    fish)
        SHELL_RC="$HOME/.config/fish/config.fish"
        ;;
    *)
        echo -e "${YELLOW}⚠️  Unsupported shell ($SHELL_NAME). Manual configuration required.${NC}"
        ;;
esac

# Add to shell RC file
if [[ -n "$SHELL_RC" ]]; then
    if grep -q "dotfiles-context" "$SHELL_RC" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  Context system already configured in $SHELL_RC${NC}"
    else
        echo "🔧 Adding context system to $SHELL_RC..."
        
        if [[ "$SHELL_NAME" == "fish" ]]; then
            # Fish shell syntax
            cat >> "$SHELL_RC" << 'EOF'

# Universal AI Context Management System
if test -f "$HOME/.config/dotfiles-context/context.sh"
    source "$HOME/.config/dotfiles-context/context.sh"
end
EOF
        else
            # Bash/Zsh syntax
            cat >> "$SHELL_RC" << 'EOF'

# Universal AI Context Management System
if [[ -f "$HOME/.config/dotfiles-context/context.sh" ]]; then
    source "$HOME/.config/dotfiles-context/context.sh"
fi
EOF
        fi
        echo -e "${GREEN}✅ Added to $SHELL_RC${NC}"
    fi
fi

# Test installation
echo
echo "🧪 Testing installation..."
if source "$DOTFILES_DIR/context.sh" 2>/dev/null && type context >/dev/null 2>&1; then
    echo -e "${GREEN}🎉 Context system installed successfully!${NC}"
    echo
    echo -e "${BLUE}Quick Start:${NC}"
    echo "  context store architecture \"Your system design\""
    echo "  context store decisions \"Your technical decisions\""
    echo "  context retrieve"
    echo "  context status"
    echo "  context help"
    echo
    echo -e "${BLUE}AI Provider Support:${NC}"
    echo "  ✅ Claude Desktop/Web (reads CLAUDE.md)"
    echo "  ✅ Cursor IDE (reads .cursorrules)"  
    echo "  ✅ GitHub Copilot (reads .github/copilot-instructions.md)"
    echo "  ✅ Gemini CLI (uses GEMINI.md symlink)"
    echo "  ✅ OpenAI/ChatGPT (reference .ai-context/memory.md)"
    echo "  ✅ Any AI tool (can read markdown files)"
    echo
    if [[ -n "$SHELL_RC" ]]; then
        echo -e "${YELLOW}📝 Note: Restart your shell or run: source $SHELL_RC${NC}"
    fi
    echo
    echo -e "${GREEN}🚀 Ready to use! Your AI assistants will now remember your project context.${NC}"
else
    echo -e "${RED}❌ Installation test failed${NC}"
    exit 1
fi