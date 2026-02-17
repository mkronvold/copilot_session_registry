#!/usr/bin/env bash
# GitHub Copilot CLI Session Management
# Loader script for bash environments

# Enable alias expansion (needed for non-interactive shells)
shopt -s expand_aliases

# Use COPILOT_DIR if set, otherwise try to detect
if [[ -z "$COPILOT_DIR" ]]; then
    # Try to find OneDrive/scripts directory
    if [[ -d "/mnt/c/Users/mike/OneDrive/scripts" ]]; then
        COPILOT_DIR="/mnt/c/Users/mike/OneDrive/scripts"
    elif [[ -d "/mnt/c/Users/mkronvold/OneDrive/scripts" ]]; then
        COPILOT_DIR="/mnt/c/Users/mkronvold/OneDrive/scripts"
    else
        echo "Error: Cannot find OneDrive/scripts directory" >&2
        return 1
    fi
    export COPILOT_DIR
fi

# Source bookmark data
if [[ -f "${COPILOT_DIR}/copilot-bookmarks.bash" ]]; then
    source "${COPILOT_DIR}/copilot-bookmarks.bash"
else
    echo "Warning: copilot-bookmarks.bash not found in ${COPILOT_DIR}" >&2
fi

# Source function registry
if [[ -f "${COPILOT_DIR}/copilot-registry.bash" ]]; then
    source "${COPILOT_DIR}/copilot-registry.bash"
else
    echo "Warning: copilot-registry.bash not found in ${COPILOT_DIR}" >&2
fi

# Set up aliases
alias cpl='show_copilot_sessions'
alias cpr='resume_copilot_session'
alias cpb='add_copilot_bookmark'
alias cprm='remove_copilot_bookmark'
alias cppush='push_copilot_session'
alias cppull='get_copilot_session'
alias cpc='show_copilot_cache'
