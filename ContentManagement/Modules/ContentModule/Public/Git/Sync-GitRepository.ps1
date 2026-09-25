function Sync-GitRepository {
  param (
    [string]$StartingPath = $PSScriptRoot
  )

  $repoRoot = Get-RepoRoot -StartingPath $StartingPath
  if (-not $repoRoot) {
    return [pscustomobject]@{
      Success  = $false
      RepoRoot = $null
      Message  = "Could not locate a git repository root."
    }
  }

  $fetchOut = & git -C $repoRoot fetch 2>&1
  if ($LASTEXITCODE -ne 0) {
    return [pscustomobject]@{
      Success  = $false
      RepoRoot = $repoRoot
      Message  = "git fetch failed:`n$fetchOut"
    }
  }

  # Store the commit hash prior to pulling so we can tell if menu.ps1 changed
  $oldHead = & git -C $repoRoot rev-parse HEAD 2>&1

  $pullOut = & git -C $repoRoot pull --ff-only 2>&1
  if ($LASTEXITCODE -ne 0) {
    return [pscustomobject]@{
      Success  = $false
      RepoRoot = $repoRoot
      Message  = "Git pull could not be completed automatically. Resolve conflicts or local branch divergence, then pull again.`n`ngit output:`n$pullOut"
    }
  }

  # Define the specific file you want to monitor
  $targetFile = "ContentManagement/Scripts/menu.ps1"

  # If we're already up to day we don't need to diff anything
  if (($LASTEXITCODE -eq 0) -and ($pullOut -ne "Already up to date.")) {
    # Use git diff with --quiet to check for modifications to that file
    # --quiet sets the $LASTEXITCODE to 1 if there are changes, and 0 if none.
    $diff = & git -C $repoRoot diff --quiet $oldHead HEAD -- $targetFile

    # 5. Evaluate the exit code
    if ($LASTEXITCODE -eq 1) {
      return [pscustomobject]@{
        Success  = $false
        RepoRoot = $repoRoot
        Message  = "[!] The Menu file was changed - please quit and run the Menu script again.`n`ngit output:`n$diff"
      }
    }
    else {
      # Don't need to tell user if menu.ps1 wasn't changed
      # Write-Host "[-] No changes detected for '$targetFile'." -ForegroundColor Gray
    }
  }

  return [pscustomobject]@{
    Success  = $true
    RepoRoot = $repoRoot
    Message  = [string]$pullOut
  }
}