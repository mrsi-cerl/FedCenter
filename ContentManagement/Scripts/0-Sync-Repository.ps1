# Dynamically locate the module relative to the running script
$ModulePath = "$PSScriptRoot\..\Modules\ContentModule\ContentModule.psm1"

# Import the shared functions
Import-Module $ModulePath -Force

# ------------------------------------------------------------------------------
# Entry Point Execution
# ------------------------------------------------------------------------------
$repoSync = Sync-GitRepository

if (-not $repoSync.Success) {
  [System.Windows.Forms.MessageBox]::Show(
    $repoSync.Message,
    "Git Sync Warning",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Warning)
}
else {
  Write-Host $repoSync.Message -ForegroundColor GREEN
}
