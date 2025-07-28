#!/usr/bin/env bash
# Copyright (c) SolarWinds, LLC.
# All rights reserved.
#
# This script runs all *_test.rb files in the test/ directory using bundle exec ruby -I test
# It provides comprehensive logging and summary reporting of test results.
#
# Usage: ./run_tests.sh [options]
# Options:
#   -p <pattern>  - Run only test files matching the pattern (e.g., -p "api/*")
#   -v           - Verbose output
#   -h           - Show help
#

set -e

# Initialize variables
exit_status=0
total_tests=0
passed_tests=0
failed_tests=0
skipped_tests=0
test_pattern="*_test.rb"

# Arrays to track test results
declare -a passed_files=()
declare -a failed_files=()
declare -a skipped_files=()

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message"
}

# Function to check test result and update counters
check_test_result() {
    local test_file="$1"
    local test_output="$2"
    local status="$3"

    total_tests=$((total_tests + 1))

    if [[ $status -eq 0 ]]; then
        passed_tests=$((passed_tests + 1))
        passed_files+=("$test_file")
        log_message "✅ PASSED: $test_file"
    else
        failed_tests=$((failed_tests + 1))
        failed_files+=("$test_file")
        exit_status=1
        log_message "❌ FAILED: $test_file (exit code: $status)"
    fi
    echo "$test_output"
}

# Function to run a single test file
run_test_file() {
    local test_file="$1"
    local relative_path=${test_file#test/}

    log_message "Running: $relative_path"

    # Capture both stdout and stderr
    local output
    local status

    if output=$(bundle exec ruby -I test "$test_file"); then
        status=0
    else
        status=$?
    fi

    check_test_result "$relative_path" "$output" "$status"
}

# Setup logging
time=$(date "+%Y%m%d_%H%M")
export TEST_RUNS_FILE_NAME="./log/testrun_$time.log"

# Remove previous log files
rm -f ./log/*.log

log_message "=== SolarWinds APM Ruby Test Runner ==="
log_message "Test pattern: $test_pattern"
log_message "Ruby version: $(ruby -e 'print(RUBY_VERSION)'); $(bundle -v)"
log_message "Searching for test files matching: test/**/$test_pattern"
test_files=$(find test -name "$test_pattern" -type f | sort)

# Count total files to run
total_files=$(echo "$test_files" | wc -l | tr -d ' ')
log_message "Found $total_files test files to run"

# Run each test file
# test_files=(test/solarwinds_apm/init_test/init_1_test.rb)
current_file=0
for test_file in $test_files; do
    current_file=$((current_file + 1))
    log_message "[$current_file/$total_files] Processing: $test_file"
    run_test_file "$test_file"
done

# Generate summary
log_message ""
log_message "=== TEST EXECUTION SUMMARY ==="
log_message "Total files processed: $total_tests"
log_message "Passed: $passed_tests"
log_message "Failed: $failed_tests"
log_message "Success rate: $((passed_tests * 100 / total_tests))%"

if [[ ${#passed_files[@]} -gt 0 ]]; then
    log_message ""
    log_message "✅ PASSED FILES:"
    for file in "${passed_files[@]}"; do
        log_message "  - $file"
    done
fi

if [[ ${#failed_files[@]} -gt 0 ]]; then
    log_message ""
    log_message "❌ FAILED FILES:"
    for file in "${failed_files[@]}"; do
        log_message "  - $file"
    done
fi

# Print summary to console
echo ""
echo "==================== FINAL SUMMARY ===================="
echo "Total Files: $total_tests | Passed: $passed_tests | Failed: $failed_tests"
echo "Success rate: $((passed_tests * 100 / total_tests))%"

if [[ $exit_status -eq 0 ]]; then
    echo "🎉 ALL TESTS PASSED!"
else
    echo "💥 SOME TESTS FAILED!"
fi

exit $exit_status
