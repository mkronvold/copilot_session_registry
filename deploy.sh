#!/bin/bash
# Example deployment script for Copilot Session Registry
# This script deploys the session management system to both PowerShell and Bash/WSL

set -e  # Exit on error

# Parse arguments
DEPLOY_BASH=false
DEPLOY_PWSH=false

for arg in "$@"; do
    case "$arg" in
        --bash) DEPLOY_BASH=true ;;
        --pwsh) DEPLOY_PWSH=true ;;
        *)
            printf "Unknown argument: %s\nUsage: %s [--bash] [--pwsh]\n" "$arg" "$0" >&2
            exit 1
            ;;
    esac
done

# Default: deploy both if no arguments given
if [[ "$DEPLOY_BASH" == false && "$DEPLOY_PWSH" == false ]]; then
    DEPLOY_BASH=true
    DEPLOY_PWSH=true
fi

echo "=== Copilot Session Registry Deployment ==="
echo ""

# Change to repository directory
cd ~/src/copilot_session_registry

# Load COPILOT_DIR from bash.d if available
if [[ -f ~/.bash.d/copilot-dir.sh ]]; then
    source ~/.bash.d/copilot-dir.sh
fi

# Resolve Windows username for PowerShell paths
WIN_USER=$(whoami.exe | tr -d '\r' | cut -d'\' -f2)
WIN_ONEDRIVE="/mnt/c/Users/$WIN_USER/OneDrive/scripts"

# ============================================================================
# 1. Deploy Bash files to OneDrive/scripts
# ============================================================================
if [[ "$DEPLOY_BASH" == true ]]; then
    echo "1. Deploying Bash files..."

    # Use COPILOT_DIR if set (e.g. from ~/.bash.d/copilot-dir.sh), otherwise fall back to default
    BASH_DEST="${COPILOT_DIR:-$WIN_ONEDRIVE}"

    # Deploy main bash files (exclude example file)
    cp bash/copilot-bookmarks.bash "$BASH_DEST"/
    cp bash/copilot-registry.bash "$BASH_DEST"/
    cp bash/copilot-init.bash "$BASH_DEST"/

    echo "   ✓ Deployed bash/*.bash to $BASH_DEST"

    # --------------------------------------------------------------------------
    # Update WSL/Bash Profile
    # --------------------------------------------------------------------------
    echo "2. Updating WSL/Bash profile..."

    # Check if using bash.d system
    if [ -d ~/.bash.d ]; then
        BASH_LOADER=~/.bash.d/copilot-session-mgmt.sh

        if [ -f "$BASH_LOADER" ]; then
            echo "   ⚠ Loader already exists: $BASH_LOADER"
            echo "   Skipping bash profile update (manually update if needed)"
        else
            # Copy example loader
            cp bash/example_copilot-session-mgmt.sh "$BASH_LOADER"
            echo "   ✓ Created: $BASH_LOADER"
            echo "   ⚠ Please edit $BASH_LOADER to customize COPILOT_DIR for your environment"
        fi
    else
        # No bash.d, check ~/.bashrc
        if grep -q "copilot-init.bash" ~/.bashrc 2>/dev/null; then
            echo "   ⚠ ~/.bashrc already contains copilot-init.bash reference"
            echo "   Skipping bash profile update"
        else
            echo "   ℹ No bash.d directory found"
            echo "   Add this to your ~/.bashrc:"
            echo ""
            echo "   # Copilot Session Management"
            echo "   export COPILOT_DIR=\"/mnt/c/Users/\$USER/OneDrive/scripts\""
            echo "   [ -f \"\${COPILOT_DIR}/copilot-init.bash\" ] && source \"\${COPILOT_DIR}/copilot-init.bash\""
            echo ""
        fi
    fi

    # --------------------------------------------------------------------------
    # Reload Bash environment
    # --------------------------------------------------------------------------
    echo "3. Reloading bash environment..."

    if [ -f ~/.bash.d/copilot-session-mgmt.sh ]; then
        source ~/.bash.d/copilot-session-mgmt.sh
        echo "   ✓ Reloaded bash environment"
        echo "   ✓ Commands available: cpl, cpr, cpb, cprm, cppush, cppull, cpc"
    else
        echo "   ⚠ Bash loader not found. Run 'source ~/.bashrc' after manual setup"
    fi
fi

# ============================================================================
# 2. Deploy PowerShell files to OneDrive/scripts
# ============================================================================
if [[ "$DEPLOY_PWSH" == true ]]; then
    echo "4. Deploying PowerShell files..."

    cp powershell/copilot-bookmarks.ps1 "$WIN_ONEDRIVE"/
    cp powershell/copilot-registry.ps1 "$WIN_ONEDRIVE"/

    echo "   ✓ Deployed powershell/*.ps1 to $WIN_ONEDRIVE"

    # --------------------------------------------------------------------------
    # Update PowerShell Profile
    # --------------------------------------------------------------------------
    echo "5. Updating PowerShell profile..."

    POWERSHELL_PROFILE="/mnt/c/Users/$WIN_USER/OneDrive/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"

    if [ ! -f "$POWERSHELL_PROFILE" ]; then
        echo "   ⚠ PowerShell profile not found: $POWERSHELL_PROFILE"
        echo "   Please create it manually and add the Copilot session management section"
    else
        # Check if already configured
        if grep -q "COPILOT SESSION MANAGEMENT" "$POWERSHELL_PROFILE" 2>/dev/null; then
            echo "   ✓ PowerShell profile already configured"
        else
            echo "   ℹ Add this to your PowerShell profile ($POWERSHELL_PROFILE):"
            echo ""
            echo "   # >>> COPILOT SESSION MANAGEMENT (managed) >>>"
            echo "   "
            echo "   # Detect OneDrive scripts directory based on hostname"
            echo "   if (-not \$env:COPILOT_DIR) {"
            echo "       \$env:COPILOT_DIR = \"\$HOME\\OneDrive\\scripts\""
            echo "   }"
            echo "   "
            echo "   # Load bookmarks from config file"
            echo "   \$CopilotBookmarksPath = \"\$env:COPILOT_DIR\\copilot-bookmarks.ps1\""
            echo "   if (Test-Path \$CopilotBookmarksPath) {"
            echo "       . \$CopilotBookmarksPath"
            echo "   } else {"
            echo "       \$Global:CopilotSessions = @{}"
            echo "   }"
            echo "   "
            echo "   # Load session management functions (includes aliases)"
            echo "   \$CopilotRegistryPath = \"\$env:COPILOT_DIR\\copilot-registry.ps1\""
            echo "   if (Test-Path \$CopilotRegistryPath) {"
            echo "       . \$CopilotRegistryPath"
            echo "   }"
            echo "   "
            echo "   # <<< COPILOT SESSION MANAGEMENT (managed) <<<"
            echo ""
        fi
    fi
fi

# ============================================================================
# Done
# ============================================================================
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Usage: deploy.sh [--bash] [--pwsh]  (default: both)"
echo ""
echo "Next steps:"
if [[ "$DEPLOY_BASH" == true ]]; then
    echo "  - Customize COPILOT_DIR in your bash loader if needed"
    echo "  - Restart WSL terminal (or run 'source ~/.bashrc') to load new configuration"
    echo "  - Run 'cpl' to verify bash installation"
fi
if [[ "$DEPLOY_PWSH" == true ]]; then
    echo "  - Add PowerShell profile section if not already present"
    echo "  - Restart PowerShell terminal to load new configuration"
fi
echo ""
