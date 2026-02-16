# Copilot Session Registry Functions
# Session management functions for GitHub Copilot CLI
# Provides bookmark management with hostname awareness for cross-machine sync

# Helper function: Get short hostname
function Get-ShortHostname {
    return $env:COMPUTERNAME.ToLower()
}

# Helper function: Check if session exists locally
function Test-SessionExists {
    param([string]$SessionId)
    return (Test-Path "$HOME\.copilot\session-state\$SessionId")
}

# Helper function: Get bookmark information
function Get-BookmarkInfo {
    param([string]$Name)
    
    if (-not $Global:CopilotSessions.ContainsKey($Name)) {
        return $null
    }
    
    $bookmark = $Global:CopilotSessions[$Name]
    
    # Handle old format (simple string) - auto-migrate
    if ($bookmark -is [string]) {
        $bookmark = @{
            Host = (Get-ShortHostname)
            Id = $bookmark
        }
        $Global:CopilotSessions[$Name] = $bookmark
    }
    
    $currentHost = Get-ShortHostname
    return @{
        Name = $Name
        Host = $bookmark.Host
        Id = $bookmark.Id
        IsLocal = ($bookmark.Host -eq $currentHost)
        Exists = (Test-SessionExists $bookmark.Id)
    }
}

# List recent Copilot sessions
function Show-CopilotSessions {
    [CmdletBinding()]
    param(
        [int]$Count = 10
    )
    
    # Reload bookmarks from config file
    $CopilotBookmarksPath = "$HOME\OneDrive\scripts\copilot-bookmarks.ps1"
    if (Test-Path $CopilotBookmarksPath) {
        . $CopilotBookmarksPath
    }
    
    Write-Host "`nRecent Copilot Sessions:" -ForegroundColor Cyan
    Write-Host ("=" * 90) -ForegroundColor Cyan
    
    Get-ChildItem "$HOME\.copilot\session-state" -Directory -ErrorAction SilentlyContinue | 
        Where-Object { $_.Name -match '^[0-9a-f-]{36}$' } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $Count |
        ForEach-Object {
            $sessionId = $_.Name
            $shortId = $sessionId.Substring(0, 8)
            $hasPlan = Test-Path (Join-Path $_.FullName "plan.md")
            $hasFiles = (Get-ChildItem (Join-Path $_.FullName "files") -ErrorAction SilentlyContinue).Count -gt 0
            
            # Check if bookmarked (handle both old and new format)
            $bookmarkEntry = $Global:CopilotSessions.GetEnumerator() | Where-Object { 
                $value = $_.Value
                if ($value -is [string]) {
                    $value -eq $sessionId
                } else {
                    $value.Id -eq $sessionId
                }
            } | Select-Object -First 1
            
            $bookmarkName = if ($bookmarkEntry) { " [$($bookmarkEntry.Name)]" } else { "" }
            $location = "-"
            if ($bookmarkEntry) {
                $info = Get-BookmarkInfo $bookmarkEntry.Name
                if ($info.IsLocal) {
                    $location = "[local]"
                } else {
                    $location = "[remote:$($info.Host)]"
                }
            }
            
            # Get description from plan if available
            $description = ""
            if ($hasPlan) {
                $planFile = Join-Path $_.FullName "plan.md"
                $firstLine = Get-Content $planFile -First 10 | Where-Object { $_ -match '^#\s+' } | Select-Object -First 1
                if ($firstLine) {
                    $description = ($firstLine -replace '^#\s+', '').Trim()
                }
            }
            
            [PSCustomObject]@{
                ID = $shortId
                LastUsed = $_.LastWriteTime.ToString("MM/dd HH:mm")
                Bookmark = if ($bookmarkName) { $bookmarkName } else { "-" }
                Location = $location
                Plan = if ($hasPlan) { "✓" } else { "-" }
                Files = if ($hasFiles) { "✓" } else { "-" }
                Description = if ($description) { $description.Substring(0, [Math]::Min(40, $description.Length)) } else { "" }
            }
        } | Format-Table -AutoSize
    
    Write-Host "`nBookmarked Sessions:" -ForegroundColor Yellow
    if ($Global:CopilotSessions.Count -gt 0) {
        $currentHost = Get-ShortHostname
        $Global:CopilotSessions.GetEnumerator() | ForEach-Object {
            $info = Get-BookmarkInfo $_.Name
            
            # Color code based on location and availability
            $color = if ($info.IsLocal -and $info.Exists) { 
                "Green" 
            } elseif ($info.IsLocal -and -not $info.Exists) { 
                "Yellow" 
            } else { 
                "DarkGray" 
            }
            
            Write-Host "  $($_.Name) " -NoNewline -ForegroundColor $color
            
            if ($info.IsLocal) {
                Write-Host "[local] " -NoNewline -ForegroundColor Green
            } else {
                Write-Host "[remote:$($info.Host)] " -NoNewline -ForegroundColor Yellow
            }
            
            Write-Host "→ $($info.Id.Substring(0,8))... " -NoNewline -ForegroundColor Gray
            
            if (-not $info.Exists) {
                Write-Host "(not available locally)" -ForegroundColor Red
            } else {
                Write-Host "" # newline
            }
        }
    } else {
        Write-Host "  (none)" -ForegroundColor Gray
    }
    
    Write-Host "`nUsage:" -ForegroundColor Cyan
    Write-Host "  cpr <bookmark>     " -NoNewline -ForegroundColor White
    Write-Host "- Resume bookmarked session" -ForegroundColor Gray
    Write-Host "  cpr <ID>           " -NoNewline -ForegroundColor White
    Write-Host "- Resume by short ID" -ForegroundColor Gray
    Write-Host "  cpb <name> <id>    " -NoNewline -ForegroundColor White
    Write-Host "- Bookmark session (saves to config)" -ForegroundColor Gray
    Write-Host "  cpb <name> <id> -NoPersist " -NoNewline -ForegroundColor White
    Write-Host "- Bookmark temporarily" -ForegroundColor Gray
    Write-Host "  cprm <bookmark>    " -NoNewline -ForegroundColor White
    Write-Host "- Remove bookmark from config" -ForegroundColor Gray
    Write-Host "  cppush <bookmark>  " -NoNewline -ForegroundColor White
    Write-Host "- Push session to OneDrive cache" -ForegroundColor Gray
    Write-Host "  cppull <bookmark>  " -NoNewline -ForegroundColor White
    Write-Host "- Pull session from OneDrive cache" -ForegroundColor Gray
    Write-Host "  cpc                " -NoNewline -ForegroundColor White
    Write-Host "- List cached sessions" -ForegroundColor Gray
    Write-Host "  copilot --resume   " -NoNewline -ForegroundColor White
    Write-Host "- Resume last session" -ForegroundColor Gray
}

# Resume a Copilot session by bookmark name or ID
function Resume-CopilotSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$NameOrId
    )
    
    # Reload bookmarks from config file
    $CopilotBookmarksPath = "$HOME\OneDrive\scripts\copilot-bookmarks.ps1"
    if (Test-Path $CopilotBookmarksPath) {
        . $CopilotBookmarksPath
    }
    
    # Check if it's a bookmark name
    if ($Global:CopilotSessions.ContainsKey($NameOrId)) {
        $info = Get-BookmarkInfo $NameOrId
        
        # Check if session exists locally
        if (-not $info.Exists) {
            Write-Host "`n⚠ Session '$NameOrId' is bookmarked on '$($info.Host)' but not available on this machine ($(Get-ShortHostname))" -ForegroundColor Yellow
            Write-Host "`nThe session files don't exist at:" -ForegroundColor Gray
            Write-Host "  $HOME\.copilot\session-state\$($info.Id)" -ForegroundColor DarkGray
            Write-Host "`nOptions:" -ForegroundColor Cyan
            Write-Host "  1. Work on the session from '$($info.Host)'" -ForegroundColor White
            Write-Host "  2. If you have access to that machine's session folder, copy it here" -ForegroundColor White
            Write-Host "  3. Remove this bookmark: (edit $CopilotBookmarksPath)" -ForegroundColor White
            return
        }
        
        # Session exists - resume it
        if ($info.IsLocal) {
            Write-Host "Resuming local session '$NameOrId'..." -ForegroundColor Green
        } else {
            Write-Host "✓ Resuming session '$NameOrId' (bookmarked on '$($info.Host)', also available locally)" -ForegroundColor Green
            Write-Host "  Session ID: $($info.Id.Substring(0,8))..." -ForegroundColor Gray
        }
        copilot --resume $info.Id
        return
    }
    
    # Try to find by short ID
    $sessions = Get-ChildItem "$HOME\.copilot\session-state" -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^[0-9a-f-]{36}$' -and $_.Name.StartsWith($NameOrId) }
    
    if ($sessions.Count -eq 1) {
        Write-Host "Resuming session $($sessions[0].Name.Substring(0,8))..." -ForegroundColor Green
        copilot --resume $sessions[0].Name
    } elseif ($sessions.Count -gt 1) {
        Write-Host "Multiple sessions found matching '$NameOrId':" -ForegroundColor Yellow
        $sessions | ForEach-Object { Write-Host "  $($_.Name.Substring(0,8))" -ForegroundColor Gray }
        Write-Host "Please be more specific" -ForegroundColor Yellow
    } else {
        Write-Host "No session found for '$NameOrId'" -ForegroundColor Red
        Write-Host "Available bookmarks: $($Global:CopilotSessions.Keys -join ', ')" -ForegroundColor Yellow
    }
}

# Add a bookmark for a session
function Add-CopilotBookmark {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$true)]
        [string]$SessionId,
        
        [switch]$NoPersist
    )
    
    # Expand short ID if needed
    if ($SessionId.Length -eq 8) {
        $fullSession = Get-ChildItem "$HOME\.copilot\session-state" -Directory |
            Where-Object { $_.Name.StartsWith($SessionId) } |
            Select-Object -First 1
        
        if ($fullSession) {
            $SessionId = $fullSession.Name
        } else {
            Write-Host "Could not find session matching '$SessionId'" -ForegroundColor Red
            return
        }
    }
    
    # Validate session ID format
    if ($SessionId -notmatch '^[0-9a-f-]{36}$') {
        Write-Host "Invalid session ID format: $SessionId" -ForegroundColor Red
        return
    }
    
    # Get current hostname
    $currentHost = Get-ShortHostname
    
    # Reload current bookmarks
    $CopilotBookmarksPath = "$HOME\OneDrive\scripts\copilot-bookmarks.ps1"
    if (Test-Path $CopilotBookmarksPath) {
        . $CopilotBookmarksPath
    }
    
    # Add to current session with hostname
    $Global:CopilotSessions[$Name] = @{
        Host = $currentHost
        Id = $SessionId
    }
    Write-Host "✓ Bookmarked session as '$Name' on '$currentHost'" -ForegroundColor Green
    Write-Host "  Run 'cpr $Name' to resume" -ForegroundColor Cyan
    
    # Persist to config file by default (unless -NoPersist specified)
    if (-not $NoPersist) {
        try {
            # Build the hashtable content
            $hashtableLines = @()
            $hashtableLines += '$Global:CopilotSessions = @{'
            
            foreach ($entry in $Global:CopilotSessions.GetEnumerator() | Sort-Object Name) {
                $hashtableLines += "    '$($entry.Name)' = @{"
                $hashtableLines += "        Host = '$($entry.Value.Host)'"
                $hashtableLines += "        Id = '$($entry.Value.Id)'"
                $hashtableLines += "    }"
            }
            
            $hashtableLines += '}'
            
            # Create header comment
            $configContent = @"
# Copilot Session Bookmarks
# This file stores bookmarked Copilot sessions with hostname tracking
# Format: 'name' = @{ Host = 'hostname'; Id = 'session-id' }

$($hashtableLines -join "`n")
"@
            
            # Backup if file exists
            if (Test-Path $CopilotBookmarksPath) {
                $backupPath = "$CopilotBookmarksPath.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
                Copy-Item $CopilotBookmarksPath $backupPath
                Write-Host "  Backup: $backupPath" -ForegroundColor Gray
            }
            
            # Write to config file
            Set-Content -Path $CopilotBookmarksPath -Value $configContent -Encoding UTF8
            
            Write-Host "✓ Bookmark saved to $CopilotBookmarksPath (permanent)" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Failed to save bookmark: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "  Bookmark added to current session only" -ForegroundColor Gray
        }
    } else {
        Write-Host "  Bookmark added to current session only (temporary)" -ForegroundColor DarkGray
    }
}

# Remove a bookmark from the registry
function Remove-CopilotBookmark {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name
    )
    
    # Check if bookmark exists
    if (-not $Global:CopilotSessions.ContainsKey($Name)) {
        Write-Host "Error: Bookmark '$Name' not found" -ForegroundColor Red
        return
    }
    
    $bookmark = $Global:CopilotSessions[$Name]
    $sessionId = $bookmark.Id
    $host = $bookmark.Host
    
    # Remove from in-memory registry
    $Global:CopilotSessions.Remove($Name)
    
    $shortId = $sessionId.Substring(0, 8)
    Write-Host "✓" -ForegroundColor Green -NoNewline
    Write-Host " Removed bookmark '" -NoNewline
    Write-Host $Name -ForegroundColor White -NoNewline
    Write-Host "' (" -NoNewline
    Write-Host "$shortId..." -ForegroundColor Cyan -NoNewline
    Write-Host " on " -NoNewline
    Write-Host $host -ForegroundColor Yellow -NoNewline
    Write-Host ")"
    
    # Save to file
    $CopilotBookmarksPath = "$HOME\OneDrive\scripts\copilot-bookmarks.ps1"
    
    if (Test-Path $CopilotBookmarksPath) {
        try {
            # Create backup
            $backupPath = "$CopilotBookmarksPath.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
            Copy-Item $CopilotBookmarksPath $backupPath -Force
            
            # Rebuild the bookmarks file
            $content = @"
# Copilot Session Bookmarks
# This file stores bookmarked Copilot sessions with hostname tracking
# Format: 'name' = @{ Host = 'hostname'; Id = 'session-id' }

`$Global:CopilotSessions = @{
"@
            
            foreach ($key in $Global:CopilotSessions.Keys | Sort-Object) {
                $bm = $Global:CopilotSessions[$key]
                $content += @"

    '$key' = @{
        Host = '$($bm.Host)'
        Id = '$($bm.Id)'
    }
"@
            }
            
            $content += "`n}"
            
            $content | Out-File -FilePath $CopilotBookmarksPath -Encoding UTF8 -Force
            
            $backupName = Split-Path $backupPath -Leaf
            Write-Host "✓ Saved to config file (backup: $backupName)" -ForegroundColor Green
        } catch {
            Write-Host "⚠ Failed to save: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# Push a session to OneDrive cache
function Push-CopilotSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name,
        
        [switch]$Force
    )
    
    # Reload bookmarks
    $CopilotBookmarksPath = "$HOME\OneDrive\scripts\copilot-bookmarks.ps1"
    if (Test-Path $CopilotBookmarksPath) {
        . $CopilotBookmarksPath
    }
    
    # Check if bookmark exists
    if (-not $Global:CopilotSessions.ContainsKey($Name)) {
        Write-Host "⚠ Bookmark '$Name' not found" -ForegroundColor Red
        Write-Host "Available bookmarks: $($Global:CopilotSessions.Keys -join ', ')" -ForegroundColor Yellow
        return
    }
    
    $info = Get-BookmarkInfo $Name
    
    # Check if session exists locally
    if (-not $info.Exists) {
        Write-Host "⚠ Session '$Name' doesn't exist locally on this machine" -ForegroundColor Red
        Write-Host "  Expected at: $HOME\.copilot\session-state\$($info.Id)" -ForegroundColor Gray
        return
    }
    
    $sessionPath = "$HOME\.copilot\session-state\$($info.Id)"
    $cachePath = "$HOME\OneDrive\.copilot-cache\$Name"
    
    # Check if cache already exists
    if ((Test-Path $cachePath) -and -not $Force) {
        Write-Host "⚠ Cache already exists for '$Name'" -ForegroundColor Yellow
        Write-Host "  Location: $cachePath" -ForegroundColor Gray
        Write-Host "  Use -Force to overwrite" -ForegroundColor Yellow
        return
    }
    
    # Calculate session size
    $sessionSize = (Get-ChildItem $sessionPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $sizeMB = [math]::Round($sessionSize / 1MB, 2)
    
    Write-Host "`nPushing session '$Name' to OneDrive cache..." -ForegroundColor Cyan
    Write-Host "  Session ID: $($info.Id.Substring(0,8))..." -ForegroundColor Gray
    Write-Host "  Size: $sizeMB MB" -ForegroundColor Gray
    
    try {
        # Create cache directory
        if (Test-Path $cachePath) {
            Remove-Item $cachePath -Recurse -Force
        }
        New-Item -ItemType Directory -Path $cachePath -Force | Out-Null
        
        # Copy session files
        $fileCount = 0
        Get-ChildItem $sessionPath -Recurse | ForEach-Object {
            $targetPath = $_.FullName.Replace($sessionPath, $cachePath)
            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            } else {
                Copy-Item $_.FullName -Destination $targetPath -Force
                $fileCount++
            }
        }
        
        # Create session ID file
        Set-Content -Path "$cachePath\session-id.txt" -Value $info.Id -Encoding UTF8
        
        # Create metadata file
        $metadata = @{
            bookmark = $Name
            sessionId = $info.Id
            pushedBy = (Get-ShortHostname)
            pushedAt = (Get-Date -Format "o")
            fileCount = $fileCount
            sizeBytes = $sessionSize
        } | ConvertTo-Json -Depth 10
        
        Set-Content -Path "$cachePath\metadata.json" -Value $metadata -Encoding UTF8
        
        Write-Host "  ✓ Copied $fileCount files" -ForegroundColor Green
        Write-Host "  ✓ Created metadata" -ForegroundColor Green
        Write-Host "`n✓ Session cached at: $cachePath" -ForegroundColor Green
        Write-Host "  OneDrive will sync this automatically" -ForegroundColor Gray
        
    } catch {
        Write-Host "`n✗ Failed to push session: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $cachePath) {
            Remove-Item $cachePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Pull a session from OneDrive cache
function Get-CopilotSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$Name,
        
        [switch]$Force
    )
    
    # Reload bookmarks
    $CopilotBookmarksPath = "$HOME\OneDrive\scripts\copilot-bookmarks.ps1"
    if (Test-Path $CopilotBookmarksPath) {
        . $CopilotBookmarksPath
    }
    
    $cachePath = "$HOME\OneDrive\.copilot-cache\$Name"
    
    # Check if cache exists
    if (-not (Test-Path $cachePath)) {
        Write-Host "⚠ No cached session found for '$Name'" -ForegroundColor Red
        Write-Host "  Expected at: $cachePath" -ForegroundColor Gray
        Write-Host "  Run 'cpc' to see available cached sessions" -ForegroundColor Yellow
        return
    }
    
    # Read session ID from cache
    $sessionIdFile = "$cachePath\session-id.txt"
    if (-not (Test-Path $sessionIdFile)) {
        Write-Host "⚠ Invalid cache: missing session-id.txt" -ForegroundColor Red
        return
    }
    
    $sessionId = (Get-Content $sessionIdFile -Raw).Trim()
    $sessionPath = "$HOME\.copilot\session-state\$sessionId"
    
    # Check if session already exists locally
    if ((Test-Path $sessionPath) -and -not $Force) {
        Write-Host "⚠ Session already exists locally" -ForegroundColor Yellow
        
        # Compare timestamps
        $localTime = (Get-Item $sessionPath).LastWriteTime
        $cacheTime = (Get-Item $cachePath).LastWriteTime
        
        Write-Host "  Local:  last modified $($localTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
        Write-Host "  Cache:  last modified $($cacheTime.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray
        Write-Host "`nPull anyway? This will overwrite your local session." -ForegroundColor Yellow
        $response = Read-Host "Continue? [y/N]"
        
        if ($response -ne 'y') {
            Write-Host "Cancelled" -ForegroundColor Gray
            return
        }
    }
    
    Write-Host "`nPulling session '$Name' from OneDrive cache..." -ForegroundColor Cyan
    Write-Host "  Cache: $cachePath" -ForegroundColor Gray
    Write-Host "  Session ID: $($sessionId.Substring(0,8))..." -ForegroundColor Gray
    
    try {
        # Remove existing session if present
        if (Test-Path $sessionPath) {
            Remove-Item $sessionPath -Recurse -Force
        }
        
        # Create session directory
        New-Item -ItemType Directory -Path $sessionPath -Force | Out-Null
        
        # Copy files from cache (excluding metadata files)
        $fileCount = 0
        Get-ChildItem $cachePath -Recurse | Where-Object {
            $_.Name -notin @('session-id.txt', 'metadata.json')
        } | ForEach-Object {
            $targetPath = $_.FullName.Replace($cachePath, $sessionPath)
            if ($_.PSIsContainer) {
                New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
            } else {
                Copy-Item $_.FullName -Destination $targetPath -Force
                $fileCount++
            }
        }
        
        Write-Host "  ✓ Copied $fileCount files" -ForegroundColor Green
        
        # Update or create bookmark with current hostname
        $currentHost = Get-ShortHostname
        $Global:CopilotSessions[$Name] = @{
            Host = $currentHost
            Id = $sessionId
        }
        
        # Save updated bookmark
        $hashtableLines = @()
        $hashtableLines += '$Global:CopilotSessions = @{'
        
        foreach ($entry in $Global:CopilotSessions.GetEnumerator() | Sort-Object Name) {
            $hashtableLines += "    '$($entry.Name)' = @{"
            $hashtableLines += "        Host = '$($entry.Value.Host)'"
            $hashtableLines += "        Id = '$($entry.Value.Id)'"
            $hashtableLines += "    }"
        }
        
        $hashtableLines += '}'
        
        $configContent = @"
# Copilot Session Bookmarks
# This file stores bookmarked Copilot sessions with hostname tracking
# Format: 'name' = @{ Host = 'hostname'; Id = 'session-id' }

$($hashtableLines -join "`n")
"@
        
        $backupPath = "$CopilotBookmarksPath.bak-$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $CopilotBookmarksPath $backupPath -ErrorAction SilentlyContinue
        Set-Content -Path $CopilotBookmarksPath -Value $configContent -Encoding UTF8
        
        Write-Host "  ✓ Updated bookmark to current host ($currentHost)" -ForegroundColor Green
        Write-Host "`n✓ Session '$Name' is now available locally!" -ForegroundColor Green
        Write-Host "  Run 'cpr $Name' to resume" -ForegroundColor Cyan
        
    } catch {
        Write-Host "`n✗ Failed to pull session: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $sessionPath) {
            Remove-Item $sessionPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# List cached sessions in OneDrive
function Show-CopilotCache {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Clean,
        
        [switch]$CleanAll
    )
    
    $cachePath = "$HOME\OneDrive\.copilot-cache"
    
    if (-not (Test-Path $cachePath)) {
        Write-Host "`nNo cached sessions found" -ForegroundColor Yellow
        Write-Host "  Cache location: $cachePath" -ForegroundColor Gray
        Write-Host "  Use 'cppush <bookmark>' to push a session to cache" -ForegroundColor Cyan
        return
    }
    
    $caches = Get-ChildItem $cachePath -Directory
    
    if ($caches.Count -eq 0) {
        Write-Host "`nNo cached sessions found" -ForegroundColor Yellow
        Write-Host "  Use 'cppush <bookmark>' to push a session to cache" -ForegroundColor Cyan
        return
    }
    
    # Handle -CleanAll
    if ($CleanAll) {
        Write-Host "`n⚠️  Warning: This will delete ALL cached sessions!" -ForegroundColor Yellow
        Write-Host "   Cache path: $cachePath" -ForegroundColor Gray
        Write-Host "   Sessions to delete: $($caches.Count)" -ForegroundColor Gray
        $confirm = Read-Host "`nAre you sure? [y/N]"
        
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            $count = 0
            foreach ($cache in $caches) {
                Remove-Item $cache.FullName -Recurse -Force
                $count++
            }
            Write-Host "`n✅ Deleted $count cached session(s)" -ForegroundColor Green
        } else {
            Write-Host "`nCancelled" -ForegroundColor Yellow
        }
        return
    }
    
    # Handle -Clean <session>
    if ($Clean) {
        $targetPath = "$cachePath\$Clean"
        
        if (-not (Test-Path $targetPath)) {
            Write-Host "`n❌ Error: Cached session '$Clean' not found" -ForegroundColor Red
            Write-Host "   Use 'cpc' to list available cached sessions" -ForegroundColor Cyan
            return
        }
        
        # Get size for confirmation
        $size = (Get-ChildItem $targetPath -Recurse | Measure-Object -Property Length -Sum).Sum
        $sizeMB = [math]::Round($size / 1MB, 2)
        
        Write-Host "`n⚠️  Delete cached session '$Clean'?" -ForegroundColor Yellow
        Write-Host "   Path: $targetPath" -ForegroundColor Gray
        Write-Host "   Size: $sizeMB MB" -ForegroundColor Gray
        $confirm = Read-Host "`nConfirm deletion? [y/N]"
        
        if ($confirm -eq 'y' -or $confirm -eq 'Y') {
            Remove-Item $targetPath -Recurse -Force
            Write-Host "`n✅ Deleted cached session '$Clean'" -ForegroundColor Green
        } else {
            Write-Host "`nCancelled" -ForegroundColor Yellow
        }
        return
    }
    
    # Default: List cached sessions
    Write-Host "`nCached Sessions in OneDrive:" -ForegroundColor Cyan
    Write-Host ("=" * 90) -ForegroundColor Cyan
    
    $caches | ForEach-Object {
        $name = $_.Name
        $metadataPath = "$($_.FullName)\metadata.json"
        
        if (Test-Path $metadataPath) {
            $metadata = Get-Content $metadataPath | ConvertFrom-Json
            $pushedBy = $metadata.pushedBy
            $pushedAt = [DateTime]::Parse($metadata.pushedAt).ToString("MM/dd HH:mm")
            $sizeMB = [math]::Round($metadata.sizeBytes / 1MB, 2)
            $sessionId = $metadata.sessionId.Substring(0,8)
        } else {
            $pushedBy = "unknown"
            $pushedAt = "unknown"
            $sizeMB = "?"
            
            $idFile = "$($_.FullName)\session-id.txt"
            if (Test-Path $idFile) {
                $sessionId = ((Get-Content $idFile -Raw).Trim()).Substring(0,8)
            } else {
                $sessionId = "unknown"
            }
        }
        
        # Check if exists locally
        if (Test-Path "$HOME\.copilot\session-state\$($metadata.sessionId)") {
            $localStatus = "[local]"
            $localColor = "Green"
        } else {
            $localStatus = "[remote]"
            $localColor = "Yellow"
        }
        
        [PSCustomObject]@{
            Bookmark = $name
            ID = $sessionId
            PushedBy = $pushedBy
            PushedAt = $pushedAt
            Size = "$sizeMB MB"
            Status = $localStatus
        }
    } | Format-Table -AutoSize
    
    Write-Host "Use 'cpc -Clean <name>' to delete a cached session" -ForegroundColor Gray
    Write-Host "Use 'cpc -CleanAll' to delete all cached sessions" -ForegroundColor Gray
    
    Write-Host "`nCommands:" -ForegroundColor Yellow
    Write-Host "  cppull <bookmark>  " -NoNewline -ForegroundColor White
    Write-Host "- Pull session from cache" -ForegroundColor Gray
    Write-Host "  cppush <bookmark>  " -NoNewline -ForegroundColor White
    Write-Host "- Push session to cache" -ForegroundColor Gray
}
