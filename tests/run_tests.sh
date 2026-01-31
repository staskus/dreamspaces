#!/bin/bash
# Test runner for dreamspaces

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)

    echo -n "Running $test_name... "
    TESTS_RUN=$((TESTS_RUN + 1))

    if bash "$test_file" > /dev/null 2>&1; then
        echo -e "${GREEN}PASSED${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}FAILED${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        # Show output on failure
        echo "  Output:"
        bash "$test_file" 2>&1 | sed 's/^/    /'
    fi
}

echo "Running dreamspaces tests..."
echo ""

# Run all test files
for test_file in "$SCRIPT_DIR"/test_*.sh; do
    if [[ -f "$test_file" ]]; then
        run_test "$test_file"
    fi
done

echo ""
echo "================================"
echo "Tests run: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo "================================"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi
