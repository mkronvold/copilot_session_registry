# GitHub Copilot CLI Session Registry

Cross-platform session management for GitHub Copilot CLI with hostname-aware bookmarks and OneDrive cache synchronization.

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
   # Load Copilot session management
   $bookmarksPath = "$HOME\OneDrive\scripts\copilot-bookmarks.ps1"
   $registryPath = "$HOME\OneDrive\scripts\copilot-registry.ps1"
   
   if (Test-Path $bookmarksPath) { . $bookmarksPath }
   if (Test-Path $registryPath) { . $registryPath }
   
   # Set up aliases
   Set-Alias cpl Show-CopilotSessions
   Set-Alias cpr Resume-CopilotSession
   Set-Alias cpb Add-CopilotBookmark
   Set-Alias cppush Push-CopilotSession
   Set-Alias cppull Get-CopilotSession
   Set-Alias cpc Show-CopilotCache
   ```

### Bash/WSL (Linux)

1. Copy files to OneDrive scripts directory:
   ```bash
   cp bash/copilot-bookmarks.bash /mnt/c/Users/$USER/OneDrive/scripts/
   cp bash/copilot-registry.bash /mnt/c/Users/$USER/OneDrive/scripts/
   cp bash/copilot-init.bash /mnt/c/Users/$USER/OneDrive/scripts/
   ```

2. Add to your `~/.bashrc`:
   ```bash
   [[ -f "/mnt/c/Users/$USER/OneDrive/scripts/copilot-init.bash" ]] && \
       source "/mnt/c/Users/$USER/OneDrive/scripts/copilot-init.bash"
   ```

3. Reload your shell:
   ```bash
   source ~/.bashrc
   ```

## Usage

### List Sessions
```bash
cpl
```
Shows bookmarked sessions with location indicators and recent sessions.

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
├── copilot-registry.{ps1,bash}     # Session management functions
└── copilot-init.bash               # Bash loader (optional)

~/.copilot/session-state/            # Session storage (local, not synced)

~/OneDrive/.copilot-cache/           # Session transfer cache (synced)
└── <bookmark-name>/
    ├── session files...
    ├── session-id.txt
    └── metadata.json
```

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
| Short ID expansion | ✅ | ✅ |
| Persistent bookmarks | ✅ | ✅ |
| Temporary bookmarks | ✅ | ✅ |
| Automatic backups | ✅ | ✅ |
| Conflict detection | ✅ | ✅ |
| Cache clearing | ✅ | ✅ |

## File Descriptions

### PowerShell Files

- **copilot-bookmarks.ps1** - Hashtable storing bookmark data with hostname tracking
- **copilot-registry.ps1** - 9 functions for session management (5 helpers + 4 commands)

### Bash Files

- **copilot-bookmarks.bash** - Parallel associative arrays for bookmark data
- **copilot-registry.bash** - 9 functions matching PowerShell feature parity
- **copilot-init.bash** - Standalone loader that sources bookmarks and registry

## License

MIT License - Feel free to use and modify

## Contributing

Contributions welcome! Please ensure:
- Cross-platform compatibility (test on both PowerShell and Bash)
- Feature parity between implementations
- Proper error handling and user feedback

## Author

Created for managing GitHub Copilot CLI sessions across multiple machines with OneDrive synchronization.
