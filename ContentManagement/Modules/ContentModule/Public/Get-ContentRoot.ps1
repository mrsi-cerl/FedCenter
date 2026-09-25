function Get-ContentRoot {
  param (
    [Parameter(Mandatory)]
    [ValidateSet("Programs", "Grants", "Training")]
    [string]$ContentType,

    [string]$StartingPath = $PSScriptRoot
  )
  if ([string]::IsNullOrWhiteSpace($StartingPath)) {
    $StartingPath = Get-Location
  }

  $contentPath = "src/content/"
  switch ($ContentType) {
    "Programs" { $contentPath += "programs" }
    "Grants" { $contentPath += "grants" }
    "Training" { $contentPath += "training" }
    default {
      Write-Host "Unknown Content Type."
      return $null
    }
  }

  # Search upwards or locally for src/content/*
  $current = $StartingPath
  while ($null -ne $current -and (Test-Path $current)) {
    $candidate = Join-Path $current $contentPath
    if (Test-Path $candidate -PathType Container) {
      return (Resolve-Path $candidate).Path
    }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current) {
      break
    }
    $current = $parent
  }

  # Fallback to current directory check
  if (Test-Path $contentPath -PathType Container) {
    return (Resolve-Path $contentPath).Path
  }

  return $null
}