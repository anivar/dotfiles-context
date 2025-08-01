#!/usr/bin/env bash
# Security check for Context Management System
# Professional security validation for dotfiles tool

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

echo "🔒 Security Check for Context Management System"
echo "=============================================="

errors=0
warnings=0

# Check file permissions
echo -n "Checking file permissions... "
if [[ -f "context.sh" ]]; then
    perms=$(stat -c "%a" context.sh 2>/dev/null || stat -f "%Lp" context.sh 2>/dev/null || echo "unknown")
    if [[ "$perms" == "755" ]] || [[ "$perms" == "775" ]] || [[ "$perms" == "777" ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠️  Unusual permissions: $perms${NC}"
        ((warnings++))
    fi
else
    echo -e "${RED}✗ context.sh not found${NC}"
    ((errors++))
fi

# Check for hardcoded secrets
echo -n "Checking for hardcoded secrets... "
secret_patterns=(
    'password\s*[:=]'
    'api[_-]?key\s*[:=]'
    'secret\s*[:=]'
    'token\s*[:=]'
    'sk[_-][a-zA-Z0-9]{20,}'
    'ghp_[a-zA-Z0-9]{36}'
)

found_secrets=0
for pattern in "${secret_patterns[@]}"; do
    if grep -rqiE "$pattern" --include="*.sh" --include="*.md" --exclude-dir=".git" .; then
        ((found_secrets++))
    fi
done

if [[ $found_secrets -eq 0 ]]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Found potential secrets${NC}"
    ((errors++))
fi

# Check input validation
echo -n "Checking input validation... "
if grep -q "_validate_input" context.sh && \
   grep -q "path traversal" context.sh && \
   grep -q "MAX_INPUT_LENGTH" context.sh; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Missing input validation${NC}"
    ((errors++))
fi

# Check atomic operations
echo -n "Checking atomic file operations... "
if grep -q "\.tmp\.\$\$" context.sh && grep -q "mv -f" context.sh; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠️  No atomic operations found${NC}"
    ((warnings++))
fi

# Check .gitignore management
echo -n "Checking .gitignore management... "
if grep -q "\.gitignore" context.sh && grep -q "\.ai-context" context.sh; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Missing .gitignore management${NC}"
    ((errors++))
fi

# Check file size limits
echo -n "Checking file size limits... "
if grep -q "MAX_FILE_SIZE" context.sh; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠️  No file size limits${NC}"
    ((warnings++))
fi

# Summary
echo
echo "=============================================="
echo "Security Check Summary:"
echo "  Errors: $errors"
echo "  Warnings: $warnings"

if [[ $errors -eq 0 ]]; then
    echo -e "${GREEN}✅ Security check passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Security check failed!${NC}"
    exit 1
fi