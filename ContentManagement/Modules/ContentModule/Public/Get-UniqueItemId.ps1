function Get-NextUniqueItemId {
  param (
    [string]$ProgramsRoot
  )
  $maxId = 44000
  if ($ProgramsRoot -and (Test-Path $ProgramsRoot)) {
    $mdFiles = Get-ChildItem -Path $ProgramsRoot -Filter "*.md" -Recurse -File
    foreach ($file in $mdFiles) {
      try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        if ($content -match "item_id:\s*['""]?(\d+)['""]?") {
          $val = [int]$matches[1]
          if ($val -gt $maxId) {
            $maxId = $val
          }
        }
      }
      catch {
      }
    }
  }
  return ($maxId + 1).ToString()
}
