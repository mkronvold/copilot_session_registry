# GitHub Copilot CLI Session Management
# Example loader script for bash environments
# 
# This file should be copied to your bash initialization directory
# and customized for your environment.
# 
# Examples:
#   - Copy to ~/.bash.d/copilot-session-mgmt.sh (if using bash.d system)
#   - Source from ~/.bashrc directly
#   - Add to your custom bash initialization system

# Set COPILOT_DIR based on hostname or username
# Customize this section for your environment
hn=$(hostname -s)

# Example 1: Hostname-based configuration
if [ "$hn" == "machine1" ]; then
    COPILOT_DIR="/mnt/c/Users/username1/OneDrive/scripts"
elif [ "$hn" == "machine2" ]; then
    COPILOT_DIR="/mnt/c/Users/username2/OneDrive/scripts"
else
    # Default path - customize this!
    COPILOT_DIR="/mnt/c/Users/$USER/OneDrive/scripts"
fi

# Example 2: Simple single-user configuration
# COPILOT_DIR="/mnt/c/Users/mike/OneDrive/scripts"

# Example 3: Auto-detect based on existing directory
# if [ -d "/mnt/c/Users/mike/OneDrive/scripts" ]; then
#     COPILOT_DIR="/mnt/c/Users/mike/OneDrive/scripts"
# elif [ -d "/mnt/c/Users/mkronvold/OneDrive/scripts" ]; then
#     COPILOT_DIR="/mnt/c/Users/mkronvold/OneDrive/scripts"
# fi

export COPILOT_DIR

# Load the Copilot session management system
[ -f "${COPILOT_DIR}/copilot-init.bash" ] && source "${COPILOT_DIR}/copilot-init.bash"
