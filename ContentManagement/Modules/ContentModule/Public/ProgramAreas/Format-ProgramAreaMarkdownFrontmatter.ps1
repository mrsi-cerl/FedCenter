function Format-ProgramAreaMarkdownFrontmatter {
  param (
    [string]$ItemId,
    [string]$ProgramArea,
    [string]$PublishDate,
    [string]$EventType,
    [string]$StartDate,
    [string]$EndDate,
    [string]$ExpiryDate,
    [string[]]$SubCategories,
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

  [void]$sb.AppendLine("programArea: $ProgramArea")
  [void]$sb.AppendLine("subCategory:")

  if ($null -ne $SubCategories -and $SubCategories.Count -gt 0) {
    foreach ($sc in $SubCategories) {
      if (-not [string]::IsNullOrWhiteSpace($sc)) {
        [void]$sb.AppendLine("- $sc")
      }
    }
  }
  else {
    [void]$sb.AppendLine("- General")
  }

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