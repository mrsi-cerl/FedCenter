function Save-ProgramContent {
  param (
    [string]$ProgramsRoot,
    [string[]]$SelectedPrograms,
    [string[]]$SelectedSubCategories,
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
  if ($null -eq $SelectedPrograms -or $SelectedPrograms.Count -eq 0) {
    throw "At least one Program Area must be selected."
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

  foreach ($pa in $SelectedPrograms) {
    $paDir = Join-Path $ProgramsRoot $pa
    if (-not (Test-Path $paDir)) {
      New-Item -Path $paDir -ItemType Directory -Force | Out-Null
    }

    $filePath = Get-UniqueProgramContentFilePath -DirectoryPath $paDir -Title $Title
    $mdContent = Format-ProgramAreaMarkdownFrontmatter -ItemId $ItemId -ProgramArea $pa -PublishDate $PublishDate -EventType $EventType -StartDate $StartDate -EndDate $EndDate -ExpiryDate $ExpiryDate -SubCategories $SelectedSubCategories -Title $Title -Body $BodyText

    # Write UTF-8 without BOM or standard UTF8
    [System.IO.File]::WriteAllText($filePath, $mdContent, [System.Text.Encoding]::UTF8)
    $createdFiles += $filePath
  }

  return [string[]]$createdFiles
}