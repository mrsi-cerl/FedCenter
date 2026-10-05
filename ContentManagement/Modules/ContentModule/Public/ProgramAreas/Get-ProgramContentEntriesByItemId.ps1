function Get-ProgramContentEntriesByItemId {
  param (
    [string]$ProgramsRoot,
    [string]$ItemId
  )

  if ([string]::IsNullOrWhiteSpace($ItemId)) {
    return @()
  }

  return @(Search-ProgramContentEntries -ProgramsRoot $ProgramsRoot -Query $ItemId -SearchMode 'Item ID' |
    Where-Object { $_.ItemId -eq $ItemId } |
    Sort-Object ProgramArea, FilePath)
}