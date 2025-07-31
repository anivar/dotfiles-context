#!/usr/bin/env bash
# Context Management System Uninstaller

set -euo pipefail

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

echo -e "${YELLOW}Context Management System Uninstaller${NC}"
echo "====================================="
echo

# Confirm uninstallation
read -p "Are you sure you want to uninstall? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Remove from shell RC files
for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$rc_file" ]] && grep -q "context.sh" "$rc_file"; then
        echo "Removing from $rc_file..."
        # Create backup
        cp "$rc_file" "${rc_file}.backup"
        # Remove context system lines
        sed -i.tmp '/# Context Management System/,/^fi$/d' "$rc_file"
        rm -f "${rc_file}.tmp"
        echo -e "${GREEN}✓ Removed from $rc_file${NC}"
    fi
done

# Remove installation
if [[ -f "$HOME/.config/dotfiles/context.sh" ]]; then
    echo "Removing context.sh..."
    rm -f "$HOME/.config/dotfiles/context.sh"
    echo -e "${GREEN}✓ Removed context.sh${NC}"
fi

# Ask about data removal
echo
read -p "Remove configuration and data? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing configuration and data..."
    rm -rf "$HOME/.config/context"
    rm -rf "$HOME/.local/share/context"
    rm -rf "$HOME/.cache/context"
    echo -e "${GREEN}✓ Configuration and data removed${NC}"
else
    echo -e "${YELLOW}Configuration and data preserved at:${NC}"
    echo "  $HOME/.config/context"
    echo "  $HOME/.local/share/context"
fi

echo
echo -e "${GREEN}Uninstallation complete!${NC}"