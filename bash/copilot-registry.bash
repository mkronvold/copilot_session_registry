#!/usr/bin/env bash
# GitHub Copilot CLI Session Management Functions
# Bash implementation with full feature parity to PowerShell version

# ANSI color codes
readonly CYAN='\033[0;36m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly RED='\033[0;31m'
readonly GRAY='\033[0;90m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Paths
readonly SESSION_STATE_DIR="$HOME/.copilot/session-state"
readonly CACHE_DIR="/mnt/c/Users/mike/OneDrive/.copilot-cache"
readonly BOOKMARKS_FILE="/mnt/c/Users/mike/OneDrive/scripts/copilot-bookmarks.bash"

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Get short hostname (lowercase)
get_short_hostname() {
    hostname | tr '[:upper:]' '[:lower:]'
}

# Test if session exists locally
# Args: session_id
# Returns: 0 if exists, 1 if not
test_session_exists() {
    local session_id="$1"
    [[ -d "$SESSION_STATE_DIR/$session_id" ]]
}

# Get bookmark info
# Args: bookmark_name
# Outputs: JSON-like info or empty if not found
get_bookmark_info() {
    local name="$1"
    
    if [[ -z "${COPILOT_SESSIONS_ID[$name]}" ]]; then
        return 1
    fi
    
    local host="${COPILOT_SESSIONS_HOST[$name]}"
    local id="${COPILOT_SESSIONS_ID[$name]}"
    local current_host
    current_host=$(get_short_hostname)
    local is_local="false"
    local exists="false"
    
    [[ "$host" == "$current_host" ]] && is_local="true"
    test_session_exists "$id" && exists="true"
    
    echo "name=$name|host=$host|id=$id|is_local=$is_local|exists=$exists"
}

# Expand short session ID to full UUID
# Args: short_id (8+ chars)
# Returns: 0 and prints full ID if found, 1 if not found or ambiguous
expand_session_id() {
    local short_id="$1"
    
    if [[ ${#short_id} -lt 8 ]]; then
        echo "Error: Short ID must be at least 8 characters" >&2
        return 1
    fi
    
    local matches=()
    if [[ -d "$SESSION_STATE_DIR" ]]; then
        while IFS= read -r dir; do
            local session_id
            session_id=$(basename "$dir")
            if [[ "$session_id" == "$short_id"* ]]; then
                matches+=("$session_id")
            fi
        done < <(find "$SESSION_STATE_DIR" -mindepth 1 -maxdepth 1 -type d)
    fi
    
    if [[ ${#matches[@]} -eq 0 ]]; then
        echo "Error: No session found matching '$short_id'" >&2
        return 1
    elif [[ ${#matches[@]} -gt 1 ]]; then
        echo "Error: Multiple sessions match '$short_id':" >&2
        printf "  %s\n" "${matches[@]}" >&2
        return 1
    fi
    
    echo "${matches[0]}"
}

# Validate session ID format (UUID)
# Args: session_id
# Returns: 0 if valid UUID format, 1 if not
validate_session_id() {
    local id="$1"
    [[ "$id" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]
}

# ============================================================================
# CORE COMMANDS
# ============================================================================

# Show Copilot Sessions (cpl)
# Lists bookmarked and recent sessions with metadata
show_copilot_sessions() {
    echo -e "${BOLD}${CYAN}GitHub Copilot Sessions${NC}"
    echo ""
    
    # Show bookmarked sessions
    if [[ ${#COPILOT_SESSIONS_ID[@]} -gt 0 ]]; then
        echo -e "${BOLD}Bookmarked Sessions:${NC}"
        
        local current_host
        current_host=$(get_short_hostname)
        
        for name in "${!COPILOT_SESSIONS_ID[@]}"; do
            local host="${COPILOT_SESSIONS_HOST[$name]}"
            local id="${COPILOT_SESSIONS_ID[$name]}"
            local short_id="${id:0:8}"
            local location=""
            local status=""
            
            if [[ "$host" == "$current_host" ]]; then
                if test_session_exists "$id"; then
                    location="${GREEN}[local]${NC}"
                    status="${GREEN}✓${NC}"
                else
                    location="${YELLOW}[local-missing]${NC}"
                    status="${RED}✗${NC}"
                fi
            else
                location="${GRAY}[remote:$host]${NC}"
                if test_session_exists "$id"; then
                    status="${GREEN}✓${NC}"
                else
                    status="${GRAY}✗${NC}"
                fi
            fi
            
            # Get plan description if available
            local plan_desc=""
            if test_session_exists "$id"; then
                local plan_file="$SESSION_STATE_DIR/$id/plan.md"
                if [[ -f "$plan_file" ]]; then
                    plan_desc=$(head -1 "$plan_file" | sed 's/^# *//')
                fi
            fi
            
            echo -e "  ${status} ${BOLD}${name}${NC} $location"
            echo -e "     ID: ${CYAN}$short_id${NC}... ($id)"
            [[ -n "$plan_desc" ]] && echo -e "     ${GRAY}$plan_desc${NC}"
        done
        echo ""
    fi
    
    # Show recent sessions
    if [[ -d "$SESSION_STATE_DIR" ]]; then
        echo -e "${BOLD}Recent Sessions:${NC}"
        
        local count=0
        while IFS= read -r dir; do
            local session_id
            session_id=$(basename "$dir")
            
            # Skip if bookmarked
            local is_bookmarked=false
            for id in "${COPILOT_SESSIONS_ID[@]}"; do
                if [[ "$id" == "$session_id" ]]; then
                    is_bookmarked=true
                    break
                fi
            done
            
            if [[ "$is_bookmarked" == "false" ]]; then
                local short_id="${session_id:0:8}"
                local plan_desc=""
                local plan_file="$dir/plan.md"
                
                if [[ -f "$plan_file" ]]; then
                    plan_desc=$(head -1 "$plan_file" | sed 's/^# *//')
                fi
                
                echo -e "  ${BOLD}$short_id${NC}... ($session_id)"
                [[ -n "$plan_desc" ]] && echo -e "     ${GRAY}$plan_desc${NC}"
                
                ((count++))
                [[ $count -ge 5 ]] && break
            fi
        done < <(find "$SESSION_STATE_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -rn | cut -d' ' -f2-)
    fi
    
    echo ""
    echo -e "${BOLD}Usage:${NC}"
    echo "  cpr <name>      Resume bookmarked session"
    echo "  cpr <shortid>   Resume by short ID (min 8 chars)"
    echo "  cpb <name> <id> Bookmark current/specified session"
    echo "  cppush <name>   Push bookmarked session to cache"
    echo "  cppull <name>   Pull bookmarked session from cache"
    echo "  cpc             List cached sessions"
}

# Resume Copilot Session (cpr)
# Args: bookmark_name or short_id
resume_copilot_session() {
    local input="$1"
    
    if [[ -z "$input" ]]; then
        echo -e "${RED}Error: Please provide a bookmark name or session ID${NC}" >&2
        echo "Usage: cpr <name|shortid>" >&2
        return 1
    fi
    
    local session_id=""
    
    # Check if it's a bookmark name
    if [[ -n "${COPILOT_SESSIONS_ID[$input]}" ]]; then
        session_id="${COPILOT_SESSIONS_ID[$input]}"
        local host="${COPILOT_SESSIONS_HOST[$input]}"
        local current_host
        current_host=$(get_short_hostname)
        
        # Validate session exists
        if ! test_session_exists "$session_id"; then
            if [[ "$host" == "$current_host" ]]; then
                echo -e "${RED}Error: Session '$input' not found locally${NC}" >&2
                echo -e "${YELLOW}The session was bookmarked on this machine but the files are missing.${NC}" >&2
                echo -e "${YELLOW}Try: cppull $input${NC}" >&2
            else
                echo -e "${RED}Error: Session '$input' is not available on this machine${NC}" >&2
                echo -e "${YELLOW}This session was bookmarked on '$host'${NC}" >&2
                echo -e "${YELLOW}To use it here, run: cppull $input${NC}" >&2
            fi
            return 1
        fi
    else
        # Try to expand as short ID
        if ! session_id=$(expand_session_id "$input"); then
            return 1
        fi
    fi
    
    # Resume session
    echo -e "${GREEN}Resuming session: ${CYAN}$session_id${NC}"
    copilot --resume "$session_id"
}

# Add Copilot Bookmark (cpb)
# Args: bookmark_name [session_id] [--no-persist]
add_copilot_bookmark() {
    local name="$1"
    local session_id="$2"
    local persist=true
    
    # Parse flags
    shift 2 2>/dev/null || shift $#
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-persist)
                persist=false
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown flag '$1'${NC}" >&2
                return 1
                ;;
        esac
    done
    
    if [[ -z "$name" ]]; then
        echo -e "${RED}Error: Please provide a bookmark name${NC}" >&2
        echo "Usage: cpb <name> [session_id] [--no-persist]" >&2
        return 1
    fi
    
    # Get current session if not specified
    if [[ -z "$session_id" ]]; then
        local current_session_file="$HOME/.copilot/current-session.txt"
        if [[ -f "$current_session_file" ]]; then
            session_id=$(cat "$current_session_file")
        else
            echo -e "${RED}Error: No current session and no session ID provided${NC}" >&2
            echo "Usage: cpb <name> <session_id>" >&2
            return 1
        fi
    fi
    
    # Expand short ID if needed
    if ! validate_session_id "$session_id"; then
        if ! session_id=$(expand_session_id "$session_id"); then
            return 1
        fi
    fi
    
    # Validate session exists
    if ! test_session_exists "$session_id"; then
        echo -e "${RED}Error: Session '$session_id' not found${NC}" >&2
        return 1
    fi
    
    local current_host
    current_host=$(get_short_hostname)
    
    # Add to in-memory registry
    COPILOT_SESSIONS_HOST["$name"]="$current_host"
    COPILOT_SESSIONS_ID["$name"]="$session_id"
    
    echo -e "${GREEN}✓${NC} Bookmarked '${BOLD}$name${NC}' → ${CYAN}${session_id:0:8}${NC}... on ${YELLOW}$current_host${NC}"
    
    # Persist to file if requested
    if [[ "$persist" == "true" ]]; then
        # Create backup
        local backup_file="${BOOKMARKS_FILE}.bak-$(date +%Y%m%d%H%M%S)"
        cp "$BOOKMARKS_FILE" "$backup_file" 2>/dev/null
        
        # Rebuild bookmarks file
        {
            echo '#!/usr/bin/env bash'
            echo '# Copilot Session Bookmarks'
            echo '# This file stores bookmarked Copilot sessions with hostname tracking'
            echo '# Format: Two parallel associative arrays (bash doesn'"'"'t support nested arrays)'
            echo '#   COPILOT_SESSIONS_HOST[name]="hostname"'
            echo '#   COPILOT_SESSIONS_ID[name]="session-id"'
            echo ''
            echo '# Require Bash 4+ for associative arrays'
            echo 'if ((BASH_VERSINFO[0] < 4)); then'
            echo '    echo "Error: Bash 4.0 or higher required for Copilot session management" >&2'
            echo '    return 1 2>/dev/null || exit 1'
            echo 'fi'
            echo ''
            echo '# Initialize associative arrays'
            echo 'declare -gA COPILOT_SESSIONS_HOST'
            echo 'declare -gA COPILOT_SESSIONS_ID'
            echo ''
            echo '# Bookmark data (synced across machines via OneDrive)'
            echo 'COPILOT_SESSIONS_HOST=('
            
            for key in "${!COPILOT_SESSIONS_HOST[@]}"; do
                echo "    [$key]=\"${COPILOT_SESSIONS_HOST[$key]}\""
            done
            
            echo ')'
            echo ''
            echo 'COPILOT_SESSIONS_ID=('
            
            for key in "${!COPILOT_SESSIONS_ID[@]}"; do
                echo "    [$key]=\"${COPILOT_SESSIONS_ID[$key]}\""
            done
            
            echo ')'
        } > "$BOOKMARKS_FILE"
        
        echo -e "${GREEN}✓${NC} Saved to config file (backup: $(basename "$backup_file"))"
    else
        echo -e "${YELLOW}Note: Bookmark is temporary (not saved to file)${NC}"
    fi
}

# ============================================================================
# TRANSFER FUNCTIONS
# ============================================================================

# Push Copilot Session to Cache (cppush)
# Args: bookmark_name [--force]
push_copilot_session() {
    local name="$1"
    local force=false
    
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f)
                force=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown flag '$1'${NC}" >&2
                return 1
                ;;
        esac
    done
    
    if [[ -z "$name" ]]; then
        echo -e "${RED}Error: Please provide a bookmark name${NC}" >&2
        echo "Usage: cppush <name> [--force]" >&2
        return 1
    fi
    
    # Get bookmark info
    if [[ -z "${COPILOT_SESSIONS_ID[$name]}" ]]; then
        echo -e "${RED}Error: Bookmark '$name' not found${NC}" >&2
        return 1
    fi
    
    local session_id="${COPILOT_SESSIONS_ID[$name]}"
    local session_dir="$SESSION_STATE_DIR/$session_id"
    
    if ! test_session_exists "$session_id"; then
        echo -e "${RED}Error: Session directory not found: $session_id${NC}" >&2
        return 1
    fi
    
    local cache_path="$CACHE_DIR/$name"
    
    # Check if cache already exists
    if [[ -d "$cache_path" ]] && [[ "$force" != "true" ]]; then
        echo -e "${YELLOW}Cache for '$name' already exists${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            return 0
        fi
    fi
    
    # Calculate size
    local size_bytes
    size_bytes=$(du -sb "$session_dir" | cut -f1)
    local size_mb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1048576}")
    local file_count
    file_count=$(find "$session_dir" -type f | wc -l)
    
    echo -e "${CYAN}Pushing session '$name' to cache...${NC}"
    echo "  Session ID: ${session_id:0:8}..."
    echo "  Size: ${size_mb} MB ($file_count files)"
    
    # Create cache directory
    mkdir -p "$cache_path"
    
    # Copy session files
    cp -r "$session_dir"/* "$cache_path/"
    
    # Create session-id.txt
    echo "$session_id" > "$cache_path/session-id.txt"
    
    # Create metadata
    local current_host
    current_host=$(get_short_hostname)
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$cache_path/metadata.json" << EOF
{
  "bookmark": "$name",
  "sessionId": "$session_id",
  "pushedBy": "$current_host",
  "pushedAt": "$timestamp",
  "sizeBytes": $size_bytes,
  "fileCount": $file_count
}
EOF
    
    echo -e "${GREEN}✓${NC} Session pushed to cache successfully"
    echo "  Cache location: $cache_path"
}

# Get Copilot Session from Cache (cppull)
# Args: bookmark_name [--force]
get_copilot_session() {
    local name="$1"
    local force=false
    
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f)
                force=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown flag '$1'${NC}" >&2
                return 1
                ;;
        esac
    done
    
    if [[ -z "$name" ]]; then
        echo -e "${RED}Error: Please provide a bookmark name${NC}" >&2
        echo "Usage: cppull <name> [--force]" >&2
        return 1
    fi
    
    local cache_path="$CACHE_DIR/$name"
    
    if [[ ! -d "$cache_path" ]]; then
        echo -e "${RED}Error: No cached session found for '$name'${NC}" >&2
        echo "Available caches: $(ls "$CACHE_DIR" 2>/dev/null | tr '\n' ' ')" >&2
        return 1
    fi
    
    # Read session ID from cache
    local session_id_file="$cache_path/session-id.txt"
    if [[ ! -f "$session_id_file" ]]; then
        echo -e "${RED}Error: Cache is missing session-id.txt${NC}" >&2
        return 1
    fi
    
    local session_id
    session_id=$(cat "$session_id_file")
    local session_dir="$SESSION_STATE_DIR/$session_id"
    
    # Check if session already exists locally
    if [[ -d "$session_dir" ]] && [[ "$force" != "true" ]]; then
        echo -e "${YELLOW}Session already exists locally${NC}"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            return 0
        fi
    fi
    
    # Show metadata if available
    if [[ -f "$cache_path/metadata.json" ]]; then
        echo -e "${CYAN}Cache metadata:${NC}"
        if command -v jq &>/dev/null; then
            jq . "$cache_path/metadata.json"
        else
            cat "$cache_path/metadata.json"
        fi
        echo ""
    fi
    
    echo -e "${CYAN}Pulling session '$name' from cache...${NC}"
    echo "  Session ID: ${session_id:0:8}..."
    
    # Create session directory
    mkdir -p "$session_dir"
    
    # Copy files (exclude metadata and session-id.txt)
    find "$cache_path" -mindepth 1 -maxdepth 1 ! -name "metadata.json" ! -name "session-id.txt" -exec cp -r {} "$session_dir/" \;
    
    # Update bookmark with current hostname
    local current_host
    current_host=$(get_short_hostname)
    COPILOT_SESSIONS_HOST["$name"]="$current_host"
    COPILOT_SESSIONS_ID["$name"]="$session_id"
    
    # Save updated bookmark
    local backup_file="${BOOKMARKS_FILE}.bak-$(date +%Y%m%d%H%M%S)"
    cp "$BOOKMARKS_FILE" "$backup_file" 2>/dev/null
    
    {
        echo '#!/usr/bin/env bash'
        echo '# Copilot Session Bookmarks'
        echo '# This file stores bookmarked Copilot sessions with hostname tracking'
        echo '# Format: Two parallel associative arrays (bash doesn'"'"'t support nested arrays)'
        echo '#   COPILOT_SESSIONS_HOST[name]="hostname"'
        echo '#   COPILOT_SESSIONS_ID[name]="session-id"'
        echo ''
        echo '# Require Bash 4+ for associative arrays'
        echo 'if ((BASH_VERSINFO[0] < 4)); then'
        echo '    echo "Error: Bash 4.0 or higher required for Copilot session management" >&2'
        echo '    return 1 2>/dev/null || exit 1'
        echo 'fi'
        echo ''
        echo '# Initialize associative arrays'
        echo 'declare -gA COPILOT_SESSIONS_HOST'
        echo 'declare -gA COPILOT_SESSIONS_ID'
        echo ''
        echo '# Bookmark data (synced across machines via OneDrive)'
        echo 'COPILOT_SESSIONS_HOST=('
        
        for key in "${!COPILOT_SESSIONS_HOST[@]}"; do
            echo "    [$key]=\"${COPILOT_SESSIONS_HOST[$key]}\""
        done
        
        echo ')'
        echo ''
        echo 'COPILOT_SESSIONS_ID=('
        
        for key in "${!COPILOT_SESSIONS_ID[@]}"; do
            echo "    [$key]=\"${COPILOT_SESSIONS_ID[$key]}\""
        done
        
        echo ')'
    } > "$BOOKMARKS_FILE"
    
    echo -e "${GREEN}✓${NC} Session pulled from cache successfully"
    echo -e "${GREEN}✓${NC} Updated bookmark to current host ($current_host)"
    echo "  Session directory: $session_dir"
}

# Show Copilot Cache (cpc)
# Lists all cached sessions or clears cache
# Args: [--clear <name>] [--clear-all]
show_copilot_cache() {
    local clear_name=""
    local clear_all=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --clear)
                if [[ -z "$2" ]]; then
                    echo -e "${RED}Error: --clear requires a session name${NC}" >&2
                    return 1
                fi
                clear_name="$2"
                shift 2
                ;;
            --clear-all)
                clear_all=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option '$1'${NC}" >&2
                echo "Usage: cpc [--clear <name>] [--clear-all]" >&2
                return 1
                ;;
        esac
    done
    
    # Handle --clear <name>
    if [[ -n "$clear_name" ]]; then
        local cache_path="$CACHE_DIR/$clear_name"
        
        if [[ ! -d "$cache_path" ]]; then
            echo -e "${RED}Error: Cache '$clear_name' not found${NC}" >&2
            return 1
        fi
        
        echo -e "${YELLOW}Remove cache '$clear_name'?${NC}"
        read -p "This will delete all cached files. Continue? (y/N): " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            return 0
        fi
        
        rm -rf "$cache_path"
        echo -e "${GREEN}✓${NC} Cleared cache: $clear_name"
        return 0
    fi
    
    # Handle --clear-all
    if [[ "$clear_all" == "true" ]]; then
        if [[ ! -d "$CACHE_DIR" ]] || [[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]]; then
            echo "No cached sessions to clear"
            return 0
        fi
        
        local count
        count=$(find "$CACHE_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l)
        
        echo -e "${YELLOW}Clear ALL cached sessions?${NC}"
        echo "  This will remove $count cached session(s)"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            return 0
        fi
        
        rm -rf "$CACHE_DIR"/*
        echo -e "${GREEN}✓${NC} Cleared all caches ($count session(s))"
        return 0
    fi
    
    # Default: List cached sessions
    echo -e "${BOLD}${CYAN}Cached Copilot Sessions${NC}"
    echo ""
    
    if [[ ! -d "$CACHE_DIR" ]] || [[ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]]; then
        echo "No cached sessions found"
        echo ""
        echo -e "${BOLD}Usage:${NC}"
        echo "  cppush <name>        Push bookmarked session to cache"
        echo "  cppull <name>        Pull session from cache"
        echo "  cpc --clear <name>   Clear specific cached session"
        echo "  cpc --clear-all      Clear all cached sessions"
        return 0
    fi
    
    local current_host
    current_host=$(get_short_hostname)
    
    for cache_name in "$CACHE_DIR"/*; do
        [[ -d "$cache_name" ]] || continue
        
        local name
        name=$(basename "$cache_name")
        local metadata_file="$cache_name/metadata.json"
        local session_id_file="$cache_name/session-id.txt"
        
        local session_id=""
        [[ -f "$session_id_file" ]] && session_id=$(cat "$session_id_file")
        
        local status=""
        if [[ -n "$session_id" ]] && test_session_exists "$session_id"; then
            status="${GREEN}[local]${NC}"
        else
            status="${GRAY}[remote]${NC}"
        fi
        
        echo -e "  ${BOLD}$name${NC} $status"
        
        if [[ -f "$metadata_file" ]]; then
            if command -v jq &>/dev/null; then
                local pushed_by pushed_at size_mb file_count
                pushed_by=$(jq -r '.pushedBy' "$metadata_file")
                pushed_at=$(jq -r '.pushedAt' "$metadata_file")
                size_bytes=$(jq -r '.sizeBytes' "$metadata_file")
                file_count=$(jq -r '.fileCount' "$metadata_file")
                size_mb=$(awk "BEGIN {printf \"%.2f\", $size_bytes/1048576}")
                
                echo -e "     Pushed by: ${YELLOW}$pushed_by${NC} at ${GRAY}$pushed_at${NC}"
                echo -e "     Size: ${size_mb} MB ($file_count files)"
            else
                echo -e "     ${GRAY}(install jq for detailed metadata)${NC}"
            fi
        fi
        
        [[ -n "$session_id" ]] && echo -e "     ID: ${CYAN}${session_id:0:8}${NC}..."
        echo ""
    done
    
    echo -e "${BOLD}Usage:${NC}"
    echo "  cppush <name>        Push bookmarked session to cache"
    echo "  cppull <name>        Pull session from cache"
    echo "  cpc --clear <name>   Clear specific cached session"
    echo "  cpc --clear-all      Clear all cached sessions"
}
