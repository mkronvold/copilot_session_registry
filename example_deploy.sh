#!/bin/bash
# Example deployment script for Copilot Session Registry
# This script deploys the session management system to both PowerShell and Bash/WSL

set -e  # Exit on error

echo "=== Copilot Session Registry Deployment ==="
echo ""

# Change to repository directory
cd ~/src/copilot_session_registry

# ============================================================================
# 1. Deploy Bash files to OneDrive/scripts
# ============================================================================
echo "1. Deploying Bash files..."

# Deploy main bash files (exclude example file)
cp bash/copilot-bookmarks.bash /mnt/c/Users/$USER/OneDrive/scripts/
cp bash/copilot-registry.bash /mnt/c/Users/$USER/OneDrive/scripts/
cp bash/copilot-init.bash /mnt/c/Users/$USER/OneDrive/scripts/

echo "   ✓ Deployed bash/*.bash to OneDrive/scripts"

# ============================================================================
# 2. Deploy PowerShell files to OneDrive/scripts
# ============================================================================
echo "2. Deploying PowerShell files..."

cp powershell/copilot-bookmarks.ps1 /mnt/c/Users/$USER/OneDrive/scripts/
cp powershell/copilot-registry.ps1 /mnt/c/Users/$USER/OneDrive/scripts/

echo "   ✓ Deployed powershell/*.ps1 to OneDrive/scripts"

# ============================================================================
# 3. Update WSL/Bash Profile
# ============================================================================
echo "3. Updating WSL/Bash profile..."

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

# ============================================================================
# 4. Update PowerShell Profile
# ============================================================================
echo "4. Updating PowerShell profile..."

POWERSHELL_PROFILE="/mnt/c/Users/$USER/OneDrive/Documents/PowerShell/Microsoft.PowerShell_profile.ps1"

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

# ============================================================================
# 5. Reload Bash environment
# ============================================================================
echo "5. Reloading bash environment..."

if [ -f ~/.bash.d/copilot-session-mgmt.sh ]; then
    source ~/.bash.d/copilot-session-mgmt.sh
    echo "   ✓ Reloaded bash environment"
    echo "   ✓ Commands available: cpl, cpr, cpb, cprm, cppush, cppull, cpc"
else
    echo "   ⚠ Bash loader not found. Run 'source ~/.bashrc' after manual setup"
fi

# ============================================================================
# Done
# ============================================================================
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Next steps:"
echo "  1. Customize COPILOT_DIR in your bash loader if needed"
echo "  2. Add PowerShell profile section if not already present"
echo "  3. Restart PowerShell and WSL terminals to load new configuration"
echo "  4. Run 'cpl' to verify installation"
echo ""
