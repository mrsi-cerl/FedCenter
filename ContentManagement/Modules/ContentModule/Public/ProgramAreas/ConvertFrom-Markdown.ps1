function ConvertFrom-Markdown {
  <#
  .SYNOPSIS
    Parses an existing program content Markdown file and returns a hashtable
    of the frontmatter fields plus the body text.
  #>
  param (
    [string]$FilePath
  )

  $result = @{
    ItemId       = ''
    ProgramAreas = ''
    PublishDate  = ''
    ExpiryDate   = ''
    EventType    = ''
    StartDate    = ''
    EndDate      = ''
    Title        = ''
    Body         = ''
  }


  # 1. Read the full markdown file content as a single string
  $mdContent = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8

  # 2. Extract the front matter using regex
  if ($mdContent -match "(?s)^---\r?\n(.*?)\r?\n---\r?\n(.*)") {
    $frontMatterText = $Matches[1]
    $bodyText = $Matches[2]

    # 3. Convert YAML to a PowerShell object
    $metadata = ConvertFrom-Yaml -Yaml $frontMatterText

    # 4. Add the body as a new property on that object
    Add-Member -InputObject $metadata -NotePropertyName "body" -NotePropertyValue $bodyText.Trim()

    # 4. Access your data natively
    $result.ItemId = $metadata.item_id
    $result.PublishDate = $metadata.publishDate
    $result.ExpiryDate = $metadata.expiryDate
    $result.EventType = $metadata.eventType
    $result.StartDate = $metadata.startDate
    $result.EndDate = $metadata.endDate
    $result.Title = $metadata.title
    $result.ProgramAreas = $metadata.programAreas
    $result.Body = $metadata.body
  }
  else {
    Write-Warning "No valid front matter found in the file."
  }

  return $result
}