function Save-ProgramContent {
  param (
    [string]$ProgramsRoot,
    [hashtable]$ProgramsAndCategories,
    [string]$Title,
    [string]$BodyText,
    [string]$ItemId,
    [string]$PublishDate,
    [string]$EventType,
    [string]$StartDate,
    [string]$EndDate,
    [string]$ExpiryDate
  )

  if (-not (Test-Path $ProgramsRoot)) {
    throw "Programs root directory not found at '$ProgramsRoot'"
  }

  if ($null -eq $ProgramsAndCategories -or $ProgramsAndCategories.Count -eq 0) {
    throw "At least one Program Area and Category must be selected."
  }
  else {
    # Let's verify we got what we thought
    Write-Host "Save-ProgramContent - Areas: " $ProgramsAndCategories.Count -ForegroundColor Blue
    foreach ($key in $ProgramsAndCategories.Keys) {
      foreach ($child in $ProgramsAndCategories[$key]) {
        Write-Host "  - $key - $child" -ForegroundColor Red
      }
    }
  }

  if ([string]::IsNullOrWhiteSpace($Title)) {
    throw "Title cannot be empty."
  }

  if ([string]::IsNullOrWhiteSpace($ItemId)) {
    throw "ItemId cannot be empty."
  }
  if ([string]::IsNullOrWhiteSpace($PublishDate)) {
    $PublishDate = (Get-Date).ToString("M/d/yyyy")
  }

  $createdFiles = @()

  $filePath = Get-UniqueProgramContentFilePath -DirectoryPath $ProgramsRoot -Title $Title
  $mdContent = Format-ProgramAreaMarkdownFrontmatter -ItemId $ItemId -ProgramAreaAndCategory $ProgramsAndCategories -PublishDate $PublishDate -EventType $EventType -StartDate $StartDate -EndDate $EndDate -ExpiryDate $ExpiryDate -Title $Title -Body $BodyText

  # Write UTF-8 without BOM or standard UTF8
  [System.IO.File]::WriteAllText($filePath, $mdContent, [System.Text.Encoding]::UTF8)
  $createdFiles += $filePath

  return [string[]]$createdFiles
}