#!/usr/bin/env bash

# Check for required dependencies
check_dependencies() {
    local missing_deps=()
    local required_tools=("whiptail" "sed" "grep" "apt-get" "systemctl")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_deps+=("$tool")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "\e[31m✖ ERROR: Missing required dependencies\e[0m"
        echo "The following tools are required but not found:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Install whiptail with: apt-get install -y whiptail"
        exit 1
    fi
}
