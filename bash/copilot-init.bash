#!/usr/bin/env bash
# GitHub Copilot CLI Session Management
# Loader script for bash environments

# Enable alias expansion (needed for non-interactive shells)
shopt -s expand_aliases

# Source bookmark data
if [[ -f "/mnt/c/Users/mike/OneDrive/scripts/copilot-bookmarks.bash" ]]; then
    source "/mnt/c/Users/mike/OneDrive/scripts/copilot-bookmarks.bash"
else
    echo "Warning: copilot-bookmarks.bash not found" >&2
fi

# Source function registry
if [[ -f "/mnt/c/Users/mike/OneDrive/scripts/copilot-registry.bash" ]]; then
    source "/mnt/c/Users/mike/OneDrive/scripts/copilot-registry.bash"
else
    echo "Warning: copilot-registry.bash not found" >&2
fi

# Set up aliases
alias cpl='show_copilot_sessions'
alias cpr='resume_copilot_session'
alias cpb='add_copilot_bookmark'
alias cprm='remove_copilot_bookmark'
alias cppush='push_copilot_session'
alias cppull='get_copilot_session'
alias cpc='show_copilot_cache'
