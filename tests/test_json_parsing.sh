#!/bin/bash
# Tests for JSON parsing from Hammerspoon output

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$DS_ROOT/lib/utils/common.sh"

# Extract JSON from mixed Hammerspoon output (hs.printf debug messages + JSON)
extract_json() {
    grep -E '^\{.*\}$' | tail -1
}

# Test: extract JSON from clean output
test_extract_json_clean() {
    local input='{"success":true,"spaceId":123}'
    local result
    result=$(echo "$input" | extract_json)
    if [[ "$result" != '{"success":true,"spaceId":123}' ]]; then
        echo "FAIL: extract_json should handle clean JSON"
        echo "  Expected: {\"success\":true,\"spaceId\":123}"
        echo "  Got: $result"
        exit 1
    fi
    echo "PASS: extract_json handles clean JSON"
}

# Test: extract JSON from mixed output with debug messages
test_extract_json_mixed() {
    local input='Dreamspaces: opening workspace test:main
Dreamspaces: reusing existing space 485 for test:main
{"success":true,"reused":true,"spaceId":485}'
    local result
    result=$(echo "$input" | extract_json)
    if [[ "$result" != '{"success":true,"reused":true,"spaceId":485}' ]]; then
        echo "FAIL: extract_json should extract JSON from mixed output"
        echo "  Expected: {\"success\":true,\"reused\":true,\"spaceId\":485}"
        echo "  Got: $result"
        exit 1
    fi
    echo "PASS: extract_json handles mixed output"
}

# Test: extract JSON handles multiple JSON lines (takes last)
test_extract_json_multiple() {
    local input='{"old":"data"}
Some debug output
{"success":true,"final":true}'
    local result
    result=$(echo "$input" | extract_json)
    if [[ "$result" != '{"success":true,"final":true}' ]]; then
        echo "FAIL: extract_json should take last JSON line"
        echo "  Expected: {\"success\":true,\"final\":true}"
        echo "  Got: $result"
        exit 1
    fi
    echo "PASS: extract_json takes last JSON line"
}

# Test: extract JSON returns empty for no JSON
test_extract_json_none() {
    local input='No JSON here
Just some text
More lines'
    local result
    result=$(echo "$input" | extract_json)
    if [[ -n "$result" ]]; then
        echo "FAIL: extract_json should return empty for non-JSON input"
        echo "  Got: $result"
        exit 1
    fi
    echo "PASS: extract_json returns empty for non-JSON input"
}

# Test: jq parsing of extracted JSON
test_jq_parsing() {
    local input='Debug: doing something
{"success":true,"spaceId":42,"error":null}'
    local result
    result=$(echo "$input" | extract_json)
    local success spaceId
    success=$(echo "$result" | jq -r '.success' 2>/dev/null)
    spaceId=$(echo "$result" | jq -r '.spaceId' 2>/dev/null)

    if [[ "$success" != "true" ]]; then
        echo "FAIL: jq should parse success as true"
        echo "  Got: $success"
        exit 1
    fi
    if [[ "$spaceId" != "42" ]]; then
        echo "FAIL: jq should parse spaceId as 42"
        echo "  Got: $spaceId"
        exit 1
    fi
    echo "PASS: jq correctly parses extracted JSON"
}

# Test: handles error case gracefully
test_error_handling() {
    local input='Some error output
Error: something failed'
    local result
    result=$(echo "$input" | extract_json)

    # Should not crash when trying to parse
    local success
    success=$(echo "$result" | jq -r '.success' 2>/dev/null || echo "parse_failed")

    # Empty input to jq should fail gracefully
    if [[ "$success" == "parse_failed" ]] || [[ -z "$success" ]] || [[ "$success" == "null" ]]; then
        echo "PASS: error handling works correctly"
    else
        echo "FAIL: should handle error case gracefully"
        exit 1
    fi
}

# Run tests
echo "Running JSON parsing tests..."
echo ""

test_extract_json_clean
test_extract_json_mixed
test_extract_json_multiple
test_extract_json_none
test_jq_parsing
test_error_handling

echo ""
echo "All JSON parsing tests passed"
