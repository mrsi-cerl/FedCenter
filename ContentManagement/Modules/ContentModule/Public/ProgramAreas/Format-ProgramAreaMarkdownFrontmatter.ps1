function Format-ProgramAreaMarkdownFrontmatter {
  param (
    [string]$ItemId,
    [hashtable]$ProgramAreaAndCategory,
    [string]$PublishDate,
    [string]$EventType,
    [string]$StartDate,
    [string]$EndDate,
    [string]$ExpiryDate,
    [string]$Title,
    [string]$Body
  )

  $sb = [System.Text.StringBuilder]::new()
  [void]$sb.AppendLine("---")
  [void]$sb.AppendLine("item_id: '$ItemId'")

  # Format title cleanly
  if ($Title -match "[:'#]") {
    $escapedTitle = $Title -replace "'", "''"
    [void]$sb.AppendLine("title: '$escapedTitle'")
  }
  else {
    [void]$sb.AppendLine("title: $Title")
  }

  Write-Host "Preparing to write programArea and subCategories"
  [void]$sb.AppendLine("programAreas:")
  foreach ($pa in $ProgramAreaAndCategory.Keys) {
    [void]$sb.AppendLine("  - $pa")

    $subCategories = $ProgramAreaAndCategory[$pa]
    if ($null -ne $subCategories -and $subCategories.Count -gt 0) {
      foreach ($sc in $subCategories) {
        if (-not [string]::IsNullOrWhiteSpace($sc)) {
          Write-Host "Writing Category: " $sc
          [void]$sb.AppendLine("    - $sc")
        }
      }
    }
    else {
      [void]$sb.AppendLine("    - General")
    }
  }
  Write-Host "Done writing program areas and subcategories"

  [void]$sb.AppendLine("publishDate: $PublishDate")
  # Optional expiry date
  if (-not [string]::IsNullOrWhiteSpace($ExpiryDate)) { [void]$sb.AppendLine("expiryDate: $ExpiryDate") }

  # Optional eventType field and dates
  if (-not [string]::IsNullOrWhiteSpace($EventType)) { [void]$sb.AppendLine("eventType: $EventType") }
  if (-not [string]::IsNullOrWhiteSpace($StartDate)) { [void]$sb.AppendLine("startDate: $StartDate") }
  if (-not [string]::IsNullOrWhiteSpace($EndDate)) { [void]$sb.AppendLine("endDate: $EndDate") }

  [void]$sb.AppendLine("---")
  [void]$sb.AppendLine("")
  [void]$sb.AppendLine($Body.Trim())

  return $sb.ToString()
}