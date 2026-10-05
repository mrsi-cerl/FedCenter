function Update-ProgramContentGroup {
  param (
    [object[]]$Entry,
    [string]$Title,
    [hashtable]$ProgramAreas,
    [string]$PublishDate,
    [string]$ExpiryDate,
    [string]$EventType,
    [string]$StartDate,
    [string]$EndDate,
    [string]$BodyText
  )

  if ($null -eq $Entry) {
    throw 'No content file wa selected to update.'
  }

  if ([string]::IsNullOrWhiteSpace($Title)) {
    throw 'Title cannot be empty.'
  }

  # Only get read-only info from $Entry, other stuff may have changed
  $frontmatter = @{
    item_id = $Entry.ItemId
    title   = $Title
  }

  $sbPA = [System.Text.StringBuilder]::new()
  foreach ($key in $ProgramAreas.Keys | Sort-Object) {
    $sbPa.AppendLine("  - $($key):")
    foreach ($item in $ProgramAreas[$key]) {
      $sbPa.AppendLine("    - $($item)")
    }
  }

  Write-Host "ProgramAreas: " $sbPA.ToString()
  $frontmatter.programAreas = $sbPa.ToString()


  if (![string]::IsNullOrWhiteSpace($PublishDate)) {
    $frontmatter.publishDate = $PublishDate
  }
  if (![string]::IsNullOrWhiteSpace($ExpiryDate)) {
    $frontmatter.expiryDate = $ExpiryDate
  }
  if (![string]::IsNullOrWhiteSpace($EventType)) {
    $frontmatter.eventType = $EventType
  }
  if (![string]::IsNullOrWhiteSpace($StartDate)) {
    $frontmatter.startDate = $StartDate
  }
  if (![string]::IsNullOrWhiteSpace($EndDate)) {
    $frontmatter.endDate = $EndDate
  }

  $yamlString = ConvertTo-Yaml -Data $frontmatter
  $markdown = "---`n" + $yamlString + "`n---`n" + $BodyText
  Write-Host "YAML Out:`n" $markdown
  [System.IO.File]::WriteAllText($Entry.FilePath, $markdown, [System.Text.Encoding]::UTF8)
}
