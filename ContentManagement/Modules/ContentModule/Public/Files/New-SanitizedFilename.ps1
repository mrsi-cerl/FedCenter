function New-SanitizedFilename {
  param (
    [string]$Title
  )
  if ([string]::IsNullOrWhiteSpace($Title)) {
    return "Untitled.md"
  }

  # Remove invalid path characters: \ / : * ? " < > |
  $clean = $Title -replace '[\\/*?:"<>|]', ''
  $clean = $clean.Trim().TrimEnd('.')
  if ([string]::IsNullOrWhiteSpace($clean)) {
    $clean = "Untitled"
  }

  if ($clean.Length -gt 15) {
    $clean = $clean.Substring(0, 15).TrimEnd()
  }

  if ([string]::IsNullOrWhiteSpace($clean)) {
    $clean = 'Untitled'
  }

  return "$clean.md"
}
