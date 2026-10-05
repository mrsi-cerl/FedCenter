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
    ProgramAreas   = ''
    PublishDate   = ''
    ExpiryDate    = ''
    EventType     = ''
    StartDate     = ''
    EndDate       = ''
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

  foreach ($line in ($yamlBlock -split '[\r\n]+')) {
    $trimmed = $line.Trim()
    if ($trimmed -match '^item_id:\s*[''"\s]*(.*?)[''"\s]*$') { $result.ItemId = $matches[1].Trim(); continue }
    if ($trimmed -match '^programAreas:\s*(.+)$') { $result.ProgramAreas = $matches[1].Trim(); continue }
    if ($trimmed -match '^publishDate:\s*(.+)$') { $result.PublishDate = $matches[1].Trim(); continue }
    if ($trimmed -match '^expiryDate:\s*(.+)$') { $result.ExpiryDate = $matches[1].Trim(); continue }
    if ($trimmed -match '^eventType:\s*(.+)$') { $result.EventType = $matches[1].Trim(); continue }
    if ($trimmed -match '^startDate:\s*(.+)$') { $result.StartDate = $matches[1].Trim(); continue }
    if ($trimmed -match '^endDate:\s*(.+)$') { $result.EndDate = $matches[1].Trim(); continue }
    if ($trimmed -match '^title:\s*[''"\s]*(.*?)[''"\s]*$') { $result.Title = $matches[1].Trim(); continue }
  }

  return $result
}