function Read-ProgramContentFile {
  <#
  .SYNOPSIS
    Parses an existing program content Markdown file and returns a hashtable
    of the frontmatter fields plus the body text.
  #>
  param (
    [string]$FilePath
  )

  $result = @{
    ItemId        = ''
    ProgramArea   = ''
    PublishDate   = ''
    ExpiryDate    = ''
    EventType     = ''
    StartDate     = ''
    EndDate       = ''
    SubCategories = @()
    Title         = ''
    Body          = ''
  }

  $raw = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
  if (-not ($raw -match "(?s)^---\r?\n(.*?)\r?\n---\r?\n?(.*)")) {
    # No frontmatter – treat everything as body
    $result.Body = $raw.Trim()
    return $result
  }

  $yamlBlock = $matches[1]
  $result.Body = $matches[2].Trim()

  $subCats = [System.Collections.Generic.List[string]]::new()
  $inSubCat = $false

  foreach ($line in ($yamlBlock -split '[\r\n]+')) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^item_id:\s*[''"\s]*(.*?)[''"\s]*$') { $result.ItemId = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^programArea:\s*(.+)$') { $result.ProgramArea = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^publishDate:\s*(.+)$') { $result.PublishDate = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^expiryDate:\s*(.+)$') { $result.ExpiryDate = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^eventType:\s*(.+)$') { $result.EventType = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^startDate:\s*(.+)$') { $result.StartDate = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^endDate:\s*(.+)$') { $result.EndDate = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^title:\s*[''"\s]*(.*?)[''"\s]*$') { $result.Title = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -eq 'subCategory:') { $inSubCat = $true; continue }
    if ($inSubCat) {
      if ($trimmed.StartsWith('-')) {
        $sc = $trimmed.Substring(1).Trim().Trim('"').Trim("'")
        if (-not [string]::IsNullOrWhiteSpace($sc)) { [void]$subCats.Add($sc) }
      }
      elseif ($trimmed -match "^\w+:") { $inSubCat = $false }
    }
  }

  $result.SubCategories = [string[]]$subCats
  return $result
}