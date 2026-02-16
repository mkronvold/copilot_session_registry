#!/usr/bin/env bash
# Copilot Session Bookmarks
# This file stores bookmarked Copilot sessions with hostname tracking
# Format: Two parallel associative arrays (bash doesn't support nested arrays)
#   COPILOT_SESSIONS_HOST[name]="hostname"
#   COPILOT_SESSIONS_ID[name]="session-id"

# Require Bash 4+ for associative arrays
if ((BASH_VERSINFO[0] < 4)); then
    echo "Error: Bash 4.0 or higher required for Copilot session management" >&2
    return 1 2>/dev/null || exit 1
fi

# Initialize associative arrays
declare -gA COPILOT_SESSIONS_HOST
declare -gA COPILOT_SESSIONS_ID

# Bookmark data (synced across machines via OneDrive)
COPILOT_SESSIONS_HOST=(
    [bashtest]="mike-proart"
    [starship]="mike-proart"
)

COPILOT_SESSIONS_ID=(
    [bashtest]="ccf6cdfe-f558-40c6-876d-c478f635e77f"
    [starship]="ccf6cdfe-f558-40c6-876d-c478f635e77f"
)
