function Search-ProgramContentEntries {
  param (
    [string]$ProgramsRoot,
    [string]$Query,
    [ValidateSet('Auto', 'Item ID', 'Title')]
    [string]$SearchMode = 'Auto'
  )

  if (-not $ProgramsRoot -or -not (Test-Path $ProgramsRoot)) {
    return @()
  }

  Write-Host "  Searching for program content files in '$ProgramsRoot'..."

  $normalizedQuery = if ($null -eq $Query) { '' } else { $Query.Trim() }
  $allEntries = New-Object System.Collections.Generic.List[object]

  # TODO: remove the 000 from the filter - is only here to speed up startup and testing
  foreach ($file in (Get-ChildItem -Path $ProgramsRoot -Filter '000*.md' -Recurse -File | Sort-Object FullName)) {
    try {
      $parsed = ConvertFrom-Markdown -FilePath $file.FullName
      $entry = [pscustomobject]@{
        Display      = "[{0}] {1}" -f $parsed.ItemId, $parsed.Title
        FilePath     = $file.FullName
        FileName     = $file.Name
        ItemId       = $parsed.ItemId
        Title        = $parsed.Title
        ProgramAreas = $parsed.ProgramAreas
        PublishDate  = $parsed.PublishDate
        ExpiryDate   = $parsed.ExpiryDate
        EventType    = $parsed.EventType
        StartDate    = $parsed.StartDate
        EndDate      = $parsed.EndDate
        Body         = $parsed.Body
      }

      if ([string]::IsNullOrWhiteSpace($normalizedQuery)) {
        [void]$allEntries.Add($entry)
        continue
      }

      $matchesItemId = $entry.ItemId -like "*$normalizedQuery*"
      $matchesTitle = $entry.Title -like "*$normalizedQuery*"

      switch ($SearchMode) {
        'Item ID' {
          if ($matchesItemId) { [void]$allEntries.Add($entry) }
        }
        'Title' {
          if ($matchesTitle) { [void]$allEntries.Add($entry) }
        }
        default {
          if ($matchesItemId -or $matchesTitle) { [void]$allEntries.Add($entry) }
        }
      }
    }
    catch {
      Write-Verbose "Skipping unreadable file '$($file.FullName)': $_"
    }
  }

  return [object[]]$allEntries
}
