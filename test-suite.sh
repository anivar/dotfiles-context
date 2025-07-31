#!/usr/bin/env bash
# Context Management System Test Suite

set -euo pipefail

# Colors
readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test framework
test_case() {
    local name="$1"
    local command="$2"
    local expected="$3"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "Testing: $name... "
    
    if result=$(eval "$command" 2>&1); then
        if [[ "$result" == *"$expected"* ]]; then
            echo -e "${GREEN}PASS${NC}"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            echo -e "${RED}FAIL${NC}"
            echo "  Expected: $expected"
            echo "  Got: $result"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
    else
        echo -e "${RED}FAIL (command error)${NC}"
        echo "  Error: $result"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "Context Management System Test Suite"
echo "==================================="
echo

# Source context.sh
source ./context.sh || {
    echo -e "${RED}Failed to source context.sh${NC}"
    exit 1
}

# Test 1: Help command
test_case "Help command" \
    "context help | head -1" \
    "Context Management System"

# Test 2: Initial status (we already have context from test directory)
test_case "Initial status" \
    "context status | grep -E '(entries|No context)'" \
    "entries"

# Test 3: Store context
test_case "Store context" \
    "context store architecture 'Test architecture'" \
    "✓ Stored [architecture]"

# Test 4: Retrieve context
test_case "Retrieve context" \
    "context retrieve | grep 'Test architecture'" \
    "Test architecture"

# Test 5: Filter retrieval
test_case "Filter retrieval" \
    "context retrieve 'architecture'" \
    "Test architecture"

# Test 6: Invalid category (error should be in stderr)
test_case "Invalid category" \
    "! context store '123invalid' 'Should fail' 2>/dev/null && echo 'Command failed as expected'" \
    "Command failed as expected"

# Test 7: Security validation (error should be in stderr)
test_case "Security validation" \
    "! context store test 'Script <script>alert()</script>' 2>/dev/null && echo 'Command failed as expected'" \
    "Command failed as expected"

# Test 8: Provider files
test_case "Provider files created" \
    "ls -1a | grep -E '(CLAUDE.md|GEMINI.md|.cursorrules)' | wc -l | grep -q 3 && echo 'All files created'" \
    "All files created"

# Test 9: Status with entries
test_case "Status shows entries" \
    "context status | grep 'entries'" \
    "entries"

# Test 10: Multiple categories
test_case "Multiple categories" \
    "context store decisions 'Database choice' >/dev/null 2>&1 && context store issues 'Performance fix' >/dev/null 2>&1 && context retrieve | grep -c '^## \\[' | grep -E '^[3-9]' >/dev/null && echo 'Multiple entries stored'" \
    "Multiple entries stored"

# Summary
echo
echo "Test Summary"
echo "============"
echo -e "Total tests: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed!${NC}"
    exit 1
fi