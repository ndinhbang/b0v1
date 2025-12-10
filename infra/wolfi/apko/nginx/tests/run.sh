#!/bin/bash
# Script simulates the imagetest/oci tests defined in Terraform.
#
# This script performs three main checks on a given nginx container image:
#   1. Verifies that the nginx binary in the image reports its version correctly.
#   2. Starts the nginx container and checks that the default welcome page is served.
#   3. Checks that the container logs proper shutdown messages when stopped.
#
# Usage:
#   ./run.sh <image_digest>
# Example:
#   ./run.sh cgr.dev/chainguard/nginx:latest
#
# Requirements:
#   - Docker must be installed and running.
#   - Network access to pull the nginx and curl images.

# --- COLOR DEFINITIONS ---
# Define ANSI color codes for colored output
CLR_RESET="\033[0m"
CLR_RED="\033[38;5;203m"
CLR_GREEN="\033[38;5;71m"
CLR_YELLOW="\033[38;5;179m"
CLR_BLUE="\033[38;5;67m"
CLR_MAGENTA="\033[38;5;139m"

# --- INITIAL CONFIGURATION (VARIABLES) ---

# Get the image digest from the first argument
DIGEST="${1:-}"
IMAGE_NAME="$DIGEST"

# Generate a random suffix for container/network names to avoid collisions
RANDOM_PET_SUFFIX=$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c 8)

# --- TEST RESULT TRACKING ---
# Track test results
TEST_PASSED=0
TEST_FAILED=0

# --- UTILITY FUNCTIONS ---
# Helper functions for colored output and section formatting

print_section() {
    echo -e "${CLR_YELLOW}## [TEST] $1${CLR_RESET}"
}

print_divider() {
    echo -e "---${CLR_RESET}"
}

print_success() {
    echo -e "${CLR_GREEN}✅ PASSED: $1${CLR_RESET}"
    TEST_PASSED=$((TEST_PASSED+1))
}

print_failure() {
    echo -e "${CLR_RED}❌ FAILED: $1${CLR_RESET}"
    TEST_FAILED=$((TEST_FAILED+1))
}

print_summary() {
    TOTAL_TESTS=$((TEST_PASSED + TEST_FAILED))
    if [ "$TEST_FAILED" -gt 0 ]; then
        echo -e "${CLR_YELLOW}Summary:${CLR_RESET} ${CLR_GREEN}$TEST_PASSED/$TOTAL_TESTS passed${CLR_RESET}, ${CLR_RED}$TEST_FAILED failed${CLR_RESET}"
    else
        echo -e "${CLR_YELLOW}Summary:${CLR_RESET} ${CLR_GREEN}$TEST_PASSED/$TOTAL_TESTS passed${CLR_RESET}"
    fi
}

# --- VALIDATION ---
# Validate input parameters and environment
validate_input() {
    if [ -z "$DIGEST" ]; then
        echo -e "${CLR_RED}Error:${CLR_RESET} Please provide an image digest as the first argument."
        echo -e "Usage: $0 <image_digest>"
        exit 1
    fi
    echo -e "${CLR_BLUE}Using random suffix:${CLR_RESET} $RANDOM_PET_SUFFIX"
}

# --- TESTS ---
# Test 1: Check Nginx version
test_nginx_version() {
    print_section "Nginx version"
    local output exit_code
    output=$(docker run --rm --entrypoint /usr/sbin/nginx "$IMAGE_NAME" -v 2>&1)
    exit_code=$?
    if [ $exit_code -eq 0 ] && echo "$output" | grep -q "nginx version:"; then
        print_success "Output: $output"
    else
        print_failure "Exit code: $exit_code. Output: $output"
    fi
    print_divider
}

# Test 2: Welcome Page
test_welcome_page() {
    print_section "Welcome page"
    local container_name network_name curl_result exit_code
    container_name="welcome-page-$RANDOM_PET_SUFFIX"
    network_name="welcome-page-$RANDOM_PET_SUFFIX"

    # Cleanup function to remove container and network after test
    cleanup_welcome_page() {
        echo -e "${CLR_BLUE}Cleaning up...${CLR_RESET}"
        docker logs "$container_name" 2>/dev/null || true
        docker rm -f "$container_name" > /dev/null 2>&1 || true
        docker network rm "$network_name" > /dev/null 2>&1 || true
    }

    # Ensure cleanup runs on script exit during this test
    trap cleanup_welcome_page EXIT

    # Create a dedicated Docker network for the test
    echo -e "${CLR_BLUE}Creating network:${CLR_RESET} $network_name"
    docker network create "$network_name" > /dev/null

    # Start the nginx container attached to the test network
    echo -e "${CLR_BLUE}Starting nginx container:${CLR_RESET} $container_name"
    docker run -d --network "$network_name" --name "$container_name" "$IMAGE_NAME" > /dev/null

    # Use a curl container to request the welcome page from nginx
    echo -e "${CLR_BLUE}Checking the welcome page...${CLR_RESET}"
    curl_result=$(docker run --rm --network "$network_name" cgr.dev/chainguard/curl:latest \
        --max-time 10 "http://$container_name:8080/" 2>&1 | grep -E '<title>Welcome to nginx!</title>')
    exit_code=$?

    if [ $exit_code -eq 0 ] && [ -n "$curl_result" ]; then
        print_success "$curl_result"
    else
        print_failure "Did not find title 'Welcome to nginx!'"
    fi

    # Remove trap and cleanup after the test
    trap - EXIT
    cleanup_welcome_page
    print_divider
}

# Test 3: Graceful Shutdown
test_graceful_shutdown() {
    print_section "Graceful shutdown"
    local logfile id attach_pid grep_quit grep_shutdown
    logfile=$(mktemp)
    echo -e "${CLR_BLUE}Running container and attaching to capture logs...${CLR_RESET}"
    id=$(docker run -d "$IMAGE_NAME")

    # Attach to the container's logs in the background
    docker attach "$id" 2> "$logfile" &
    attach_pid=$!
    sleep 5

    # Stop the container to trigger shutdown
    echo -e "${CLR_BLUE}Sending stop signal (docker stop $id)...${CLR_RESET}"
    docker stop "$id" > /dev/null

    # Wait for log capture to finish
    wait $attach_pid 2>/dev/null

    # Check the logs for shutdown messages
    echo -e "${CLR_BLUE}Checking log:${CLR_RESET} $logfile"
    grep_quit=$(grep "SIGQUIT" "$logfile" || true)
    grep_shutdown=$(grep "gracefully shutting down" "$logfile" || true)

    if [ -z "$grep_quit" ] || [ -z "$grep_shutdown" ]; then
        print_failure "Shutdown test FAILED."
        echo -e "${CLR_RED}Missing 'SIGQUIT' or 'gracefully shutting down' in logs.${CLR_RESET}"
        echo -e "${CLR_MAGENTA}--- LOGS FOR THIS TEST ---${CLR_RESET}"
        cat "$logfile"
        echo -e "${CLR_MAGENTA}--------------------------${CLR_RESET}"
    else
        print_success "Found both 'SIGQUIT' and 'gracefully shutting down' in logs."
    fi

    # Remove temporary log file
    rm -f "$logfile"
    print_divider
}

# --- MAIN EXECUTION ---
validate_input
test_nginx_version
test_welcome_page
test_graceful_shutdown
print_summary

# To run this script you need Docker installed:
# $ chmod +x run.sh
# $ ./run.sh cgr.dev/chainguard/nginx:latest
