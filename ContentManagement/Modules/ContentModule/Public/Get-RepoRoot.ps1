function Get-RepoRoot {
  param (
    [string]$StartingPath = "$PSScriptRoot\..\.."
  )

  if ([string]::IsNullOrWhiteSpace($StartingPath)) {
    $StartingPath = Get-Location
  }

  $current = $StartingPath
  while ($null -ne $current -and (Test-Path $current)) {
    if (Test-Path (Join-Path $current '.git')) {
      return (Resolve-Path $current).Path
    }

    $parent = Split-Path $current -Parent
    if ($parent -eq $current) {
      break
    }
    $current = $parent
  }

  return $null
}
