# GitHub Copilot CLI Session Registry

Cross-platform session management for GitHub Copilot CLI with hostname-aware bookmarks and OneDrive cache synchronization.

## Quick Start

### Automated Deployment

1. Clone the repository:
   ```bash
   git clone git@github.com:mkronvold/copilot_session_registry.git ~/src/copilot_session_registry
   ```

2. Run the deployment script:
   ```bash
   cd ~/src/copilot_session_registry
   bash example_deploy.sh
   ```

   The script will:
   - Copy all files to `~/OneDrive/scripts/`
   - Create bash loader in `~/.bash.d/` (if using bash.d system)
   - Provide instructions for PowerShell profile setup
   - Reload bash environment if possible

3. Follow the on-screen instructions to complete setup

### Manual Installation

For manual setup or customization, see the detailed installation instructions below.

## Features

- 📚 **Bookmark Sessions** - Save and name your Copilot sessions
- 🌐 **Hostname Awareness** - Track which machine each session belongs to
- 📍 **Location Indicators** - See `[local]` vs `[remote:hostname]` status
- 💾 **Session Transfer** - Push/pull sessions between machines via OneDrive cache
- 🔄 **Cross-Platform** - Works in both PowerShell and Bash/WSL
- 🔒 **Safe Operations** - Automatic backups, confirmation prompts
- ⚡ **Quick Resume** - Resume by name or short ID (8+ chars)

## Installation

### PowerShell (Windows)

1. Copy files to OneDrive scripts directory:
   ```powershell
   cp powershell/copilot-bookmarks.ps1 ~/OneDrive/scripts/
   cp powershell/copilot-registry.ps1 ~/OneDrive/scripts/
   ```

2. Add to your PowerShell profile (`$PROFILE`):
   ```powershell
   # Set COPILOT_DIR environment variable (customize if needed)
   # This example uses the default ~/OneDrive/scripts path
   if (-not $env:COPILOT_DIR) {
       $env:COPILOT_DIR = "$HOME\OneDrive\scripts"
   }
   
   # Load Copilot session management (includes aliases)
   $bookmarksPath = "$env:COPILOT_DIR\copilot-bookmarks.ps1"
   $registryPath = "$env:COPILOT_DIR\copilot-registry.ps1"
   
   if (Test-Path $bookmarksPath) { . $bookmarksPath }
   if (Test-Path $registryPath) { . $registryPath }
   ```

   **Note:** Aliases (`cpl`, `cpr`, `cpb`, `cprm`, `cppush`, `cppull`, `cpc`) are automatically defined when you load `copilot-registry.ps1`.

### Bash/WSL (Linux)

1. Copy files to OneDrive scripts directory:
   ```bash
   cp bash/copilot-bookmarks.bash /mnt/c/Users/$USER/OneDrive/scripts/
   cp bash/copilot-registry.bash /mnt/c/Users/$USER/OneDrive/scripts/
   cp bash/copilot-init.bash /mnt/c/Users/$USER/OneDrive/scripts/
   ```

2. Add to your `~/.bashrc` (or custom loader like `~/.bash.d/copilot-session-mgmt.sh`):
   ```bash
   # Set COPILOT_DIR environment variable (customize if needed)
   # Example for different usernames on different machines:
   hn=$(hostname -s)
   if [ "$hn" == "machine1" ]; then
       COPILOT_DIR="/mnt/c/Users/username1/OneDrive/scripts"
   else
       COPILOT_DIR="/mnt/c/Users/username2/OneDrive/scripts"
   fi
   export COPILOT_DIR
   
   # Load Copilot session management
   [[ -f "${COPILOT_DIR}/copilot-init.bash" ]] && \
       source "${COPILOT_DIR}/copilot-init.bash"
   ```

   **Note:** The `copilot-init.bash` script automatically loads the bookmarks, registry, and defines all aliases. If you don't set `COPILOT_DIR`, it will attempt to auto-detect the OneDrive path.

3. Reload your shell:
   ```bash
   source ~/.bashrc
   ```

## Usage

### List Sessions
```bash
cpl           # Show 10 recent sessions (default)
cpl 5         # Show 5 recent sessions
cpl 20        # Show 20 recent sessions
```

Displays sessions in a table format with columns:
- **ID**: Short session ID (8 chars)
- **LastUsed**: Last modified date/time
- **Bookmark**: Bookmark name if assigned
- **Location**: `[local]` or `[remote:hostname]`
- **Plan**: ✓ if plan.md exists
- **Files**: ✓ if files/ directory has content
- **Description**: First line of plan.md

Also shows bookmarked sessions separately below the table.

### Resume Session
```bash
cpr <name>        # Resume by bookmark name
cpr <short-id>    # Resume by short ID (min 8 chars)
```

### Bookmark Session
```bash
cpb <name> <session-id>           # Bookmark and persist
cpb <name> <session-id> --no-persist  # Temporary bookmark (bash)
cpb <name> <session-id> -NoPersist    # Temporary bookmark (PowerShell)
```

### Remove Bookmark
```bash
cprm <name>       # Remove bookmark from registry
```

### Transfer Sessions

Push session to OneDrive cache:
```bash
cppush <name>
```

Pull session from OneDrive cache:
```bash
cppull <name>
```

List cached sessions:
```bash
cpc
```

Clear cache:
```bash
cpc --clear <name>      # Clear specific cache (bash)
cpc --clear-all         # Clear all caches (bash)
cpc -Clear <name>       # Clear specific cache (PowerShell)
cpc -ClearAll           # Clear all caches (PowerShell)
```

## Architecture

```
~/OneDrive/scripts/
├── copilot-bookmarks.{ps1,bash}    # Bookmark data (synced)
├── copilot-registry.{ps1,bash}     # Functions + aliases
└── copilot-init.bash               # Bash loader script

~/.copilot/session-state/            # Session storage (local, not synced)

~/OneDrive/.copilot-cache/           # Session transfer cache (synced)
└── <bookmark-name>/
    ├── session files...
    ├── session-id.txt
    └── metadata.json
```

**PowerShell:**
- `copilot-bookmarks.ps1` - Bookmark data (hashtable)
- `copilot-registry.ps1` - Functions and aliases
- Profile sources both files

**Bash:**
- `copilot-bookmarks.bash` - Bookmark data (associative arrays)
- `copilot-registry.bash` - Functions only
- `copilot-init.bash` - Loader that sources both + defines aliases
- `.bashrc` sources `copilot-init.bash`

## Example Workflow

### Scenario: Working on multiple machines

**On Machine A (Windows with PowerShell):**
```powershell
# Start working on a feature
copilot

# Bookmark the session
cpb myfeature ccf6cdfe-f558-40c6-876d-c478f635e77f

# Push to cache for access on other machines
cppush myfeature
```

**On Machine B (WSL/Linux):**
```bash
# Pull the session from cache
cppull myfeature

# Resume working
cpr myfeature
```

## Requirements

### PowerShell
- PowerShell 5.1 or higher
- OneDrive installed and synced

### Bash
- Bash 4.0 or higher (for associative arrays)
- OneDrive accessible (e.g., via `/mnt/c/Users/.../OneDrive` in WSL)
- Optional: `jq` for pretty JSON output

## Features Comparison

| Feature | PowerShell | Bash |
|---------|-----------|------|
| Bookmark sessions | ✅ | ✅ |
| Hostname tracking | ✅ | ✅ |
| Location indicators | ✅ | ✅ |
| Session transfer (push/pull) | ✅ | ✅ |
| Cache management | ✅ | ✅ |
| Bookmark removal | ✅ | ✅ |
| Short ID expansion | ✅ | ✅ |
| Persistent bookmarks | ✅ | ✅ |
| Temporary bookmarks | ✅ | ✅ |
| Automatic backups | ✅ | ✅ |
| Conflict detection | ✅ | ✅ |
| Cache clearing | ✅ | ✅ |
| Table format listing | ✅ | ✅ |

## File Descriptions

### PowerShell Files

- **copilot-bookmarks.ps1** - Hashtable storing bookmark data with hostname tracking
- **copilot-registry.ps1** - Session management functions (9 functions + 7 aliases)

### Bash Files

- **copilot-bookmarks.bash** - Parallel associative arrays for bookmark data
- **copilot-registry.bash** - Session management functions (9 functions)
- **copilot-init.bash** - Standalone loader that sources bookmarks, registry, and defines aliases
- **example_copilot-session-mgmt.sh** - Example bash loader for customization (copy to `~/.bash.d/` or source from `.bashrc`)

### Deployment

- **example_deploy.sh** - Automated deployment script that:
  - Copies all files to OneDrive/scripts
  - Creates bash loader in ~/.bash.d/ (if applicable)
  - Provides PowerShell profile setup instructions
  - Reloads bash environment

## Available Commands

All commands work identically in both PowerShell and Bash:

| Command | Description |
|---------|-------------|
| `cpl` | List sessions in table format (optional count: `cpl 5`) |
| `cpr <name>` | Resume bookmarked session by name |
| `cpr <shortid>` | Resume session by short ID (8+ chars) |
| `cpb <name> <id>` | Bookmark a session (default: persistent) |
| `cprm <name>` | Remove a bookmark from registry |
| `cppush <name>` | Push bookmarked session to OneDrive cache |
| `cppull <name>` | Pull session from OneDrive cache |
| `cpc` | List cached sessions |
| `cpc --clear <name>` | Clear specific cache (bash) |
| `cpc -Clear <name>` | Clear specific cache (PowerShell) |
| `cpc --clear-all` | Clear all caches (bash) |
| `cpc -ClearAll` | Clear all caches (PowerShell) |

## License

MIT License - Feel free to use and modify

## Contributing

Contributions welcome! Please ensure:
- Cross-platform compatibility (test on both PowerShell and Bash)
- Feature parity between implementations
- Proper error handling and user feedback

## Author

Created for managing GitHub Copilot CLI sessions across multiple machines with OneDrive synchronization.
