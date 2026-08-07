# ==============================================================================
# Script: Create-Content.ps1
# Description: PowerShell GUI tool for creating program content Markdown files
#              in src/content/programs with dynamic category and subcategory selection,
#              rich text editing, and automated frontmatter generation.
# ==============================================================================

# Ensure Windows Forms assemblies are available when running in GUI mode
try
{
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
  Add-Type -AssemblyName System.Drawing -ErrorAction Stop
} catch
{
  Write-Verbose "WinForms assemblies unavailable in current environment."
}

# ------------------------------------------------------------------------------
# Core Helper Functions
# ------------------------------------------------------------------------------

function Get-FedCenterProgramsRoot
{
  param (
    [string]$StartingPath = $PSScriptRoot
  )
  if ([string]::IsNullOrWhiteSpace($StartingPath))
  {
    $StartingPath = Get-Location
  }

  # Search upwards or locally for src/content/programs
  $current = $StartingPath
  while ($null -ne $current -and (Test-Path $current))
  {
    $candidate = Join-Path $current "src/content/programs"
    if (Test-Path $candidate -PathType Container)
    {
      return (Resolve-Path $candidate).Path
    }
    $parent = Split-Path $current -Parent
    if ($parent -eq $current)
    { break
    }
    $current = $parent
  }

  # Fallback to current directory check
  if (Test-Path "src/content/programs" -PathType Container)
  {
    return (Resolve-Path "src/content/programs").Path
  }

  return $null
}

function Get-FedCenterRepoRoot
{
  param (
    [string]$StartingPath = $PSScriptRoot
  )

  if ([string]::IsNullOrWhiteSpace($StartingPath))
  {
    $StartingPath = Get-Location
  }

  $current = $StartingPath
  while ($null -ne $current -and (Test-Path $current))
  {
    if (Test-Path (Join-Path $current '.git'))
    {
      return (Resolve-Path $current).Path
    }

    $parent = Split-Path $current -Parent
    if ($parent -eq $current)
    {
      break
    }
    $current = $parent
  }

  return $null
}

function Sync-FedCenterRepository
{
  param (
    [string]$StartingPath = $PSScriptRoot
  )

  $repoRoot = Get-FedCenterRepoRoot -StartingPath $StartingPath
  if (-not $repoRoot)
  {
    return [pscustomobject]@{
      Success = $false
      RepoRoot = $null
      Message = "Could not locate a git repository root."
    }
  }

  $fetchOut = & git -C $repoRoot fetch 2>&1
  if ($LASTEXITCODE -ne 0)
  {
    return [pscustomobject]@{
      Success = $false
      RepoRoot = $repoRoot
      Message = "git fetch failed:`n$fetchOut"
    }
  }

  $pullOut = & git -C $repoRoot pull --ff-only 2>&1
  if ($LASTEXITCODE -ne 0)
  {
    return [pscustomobject]@{
      Success = $false
      RepoRoot = $repoRoot
      Message = "Git pull could not be completed automatically. Resolve conflicts or local branch divergence, then pull again.`n`ngit output:`n$pullOut"
    }
  }

  return [pscustomobject]@{
    Success = $true
    RepoRoot = $repoRoot
    Message = [string]$pullOut
  }
}

function Invoke-FedCenterContentCommitPush
{
  param (
    [string]$StartingPath = $PSScriptRoot,
    [System.Windows.Forms.IWin32Window]$ParentWindow = $null,
    [string]$ContentRelativePath = 'src/content',
    [string]$DefaultCommitMessage = 'Update program content'
  )

  $repoRoot = Get-FedCenterRepoRoot -StartingPath $StartingPath
  if (-not $repoRoot)
  {
    [System.Windows.Forms.MessageBox]::Show(
      $ParentWindow,
      'Could not locate a git repository root.',
      'Git Error',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error)
    return
  }

  $gitStatus = & git -C $repoRoot status --porcelain -- "$ContentRelativePath/**/*.md" "$ContentRelativePath/*.md" 2>&1
  $stagedLines = $gitStatus | Where-Object { $_ -match '^.{1,2}\s' }
  if (-not $stagedLines)
  {
    [System.Windows.Forms.MessageBox]::Show(
      $ParentWindow,
      'No modified Markdown files found under src/content.',
      'Nothing to Commit',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Information)
    return
  }

  $dlg = New-Object System.Windows.Forms.Form
  $dlg.Text = 'Publish Changes'
  $dlg.Size = New-Object System.Drawing.Size(520, 380)
  $dlg.StartPosition = 'CenterParent'
  $dlg.FormBorderStyle = 'FixedDialog'
  $dlg.MaximizeBox = $false
  $dlg.MinimizeBox = $false
  $dlg.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

  $dlgLayout = New-Object System.Windows.Forms.TableLayoutPanel
  $dlgLayout.Dock = 'Fill'
  $dlgLayout.RowCount = 4
  $dlgLayout.ColumnCount = 1
  $dlgLayout.Padding = New-Object System.Windows.Forms.Padding(10)
  [void]$dlgLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 24)))
  [void]$dlgLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 40)))
  [void]$dlgLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 60)))
  [void]$dlgLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 44)))

  $lblFiles = New-Object System.Windows.Forms.Label
  $lblFiles.Text = 'Files to be published:'
  $lblFiles.Dock = 'Fill'
  $dlgLayout.Controls.Add($lblFiles, 0, 0)

  $lstFiles = New-Object System.Windows.Forms.ListBox
  $lstFiles.Dock = 'Fill'
  $lstFiles.Font = New-Object System.Drawing.Font('Consolas', 9.0)
  foreach ($filePath in ($stagedLines | ForEach-Object { $_.Substring(3).Trim() }))
  {
    [void]$lstFiles.Items.Add($filePath)
  }
  $dlgLayout.Controls.Add($lstFiles, 0, 1)

  $msgPanel = New-Object System.Windows.Forms.Panel
  $msgPanel.Dock = 'Fill'
  $lblMsg = New-Object System.Windows.Forms.Label
  $lblMsg.Text = 'Change Description:'
  $lblMsg.Dock = 'Top'
  $lblMsg.Height = 20
  $txtMsg = New-Object System.Windows.Forms.TextBox
  $txtMsg.Dock = 'Fill'
  $txtMsg.Multiline = $true
  $txtMsg.ScrollBars = 'Vertical'
  $txtMsg.Text = $DefaultCommitMessage
  $msgPanel.Controls.Add($txtMsg)
  $msgPanel.Controls.Add($lblMsg)
  $dlgLayout.Controls.Add($msgPanel, 0, 2)

  $dlgButtons = New-Object System.Windows.Forms.FlowLayoutPanel
  $dlgButtons.Dock = 'Fill'
  $dlgButtons.FlowDirection = 'RightToLeft'
  $dlgOK = New-Object System.Windows.Forms.Button
  $dlgOK.Text = 'Publish Changes'
  $dlgOK.Size = New-Object System.Drawing.Size(120, 32)
  $dlgOK.BackColor = [System.Drawing.Color]::FromArgb(34, 139, 34)
  $dlgOK.ForeColor = [System.Drawing.Color]::White
  $dlgOK.FlatStyle = 'Flat'
  $dlgOK.DialogResult = [System.Windows.Forms.DialogResult]::OK
  $dlgCancel = New-Object System.Windows.Forms.Button
  $dlgCancel.Text = 'Cancel'
  $dlgCancel.Size = New-Object System.Drawing.Size(80, 32)
  $dlgCancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
  $dlgButtons.Controls.Add($dlgOK)
  $dlgButtons.Controls.Add($dlgCancel)
  $dlgLayout.Controls.Add($dlgButtons, 0, 3)

  $dlg.Controls.Add($dlgLayout)
  $dlg.AcceptButton = $dlgOK
  $dlg.CancelButton = $dlgCancel

  if ($dlg.ShowDialog($ParentWindow) -ne [System.Windows.Forms.DialogResult]::OK)
  {
    return
  }

  $commitMsg = $txtMsg.Text.Trim()
  if ([string]::IsNullOrWhiteSpace($commitMsg))
  {
    [System.Windows.Forms.MessageBox]::Show(
      $ParentWindow,
      'Please enter a change description.',
      'Validation',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Warning)
    return
  }

  $addResult = [pscustomobject]@{
    Output = (& git -C $repoRoot add -- "$ContentRelativePath/**/*.md" "$ContentRelativePath/*.md" 2>&1)
    ExitCode = $LASTEXITCODE
  }
  if ($addResult.ExitCode -ne 0)
  {
    [System.Windows.Forms.MessageBox]::Show(
      $ParentWindow,
      "git add failed:`n$($addResult.Output)",
      'Git Error',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error)
    return
  }

  $commitOut = & git -C $repoRoot commit -m $commitMsg 2>&1
  if ($LASTEXITCODE -ne 0)
  {
    [System.Windows.Forms.MessageBox]::Show(
      $ParentWindow,
      "git commit failed:`n$commitOut",
      'Git Error',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error)
    return
  }

  $pushOut = & git -C $repoRoot push 2>&1
  if ($LASTEXITCODE -ne 0)
  {
    [System.Windows.Forms.MessageBox]::Show(
      $ParentWindow,
      "git push failed:`n$pushOut",
      'Git Error',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Error)
    return
  }

  [System.Windows.Forms.MessageBox]::Show(
    $ParentWindow,
    'Changes committed and pushed successfully.',
    'Success',
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information)
}

function Get-ProgramAreas
{
  param (
    [string]$ProgramsRoot
  )
  if (-not $ProgramsRoot -or -not (Test-Path $ProgramsRoot))
  {
    return @()
  }
  $dirs = Get-ChildItem -Path $ProgramsRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object
  return $dirs
}

function Get-SubCategoriesForPrograms
{
  param (
    [string]$ProgramsRoot,
    [string[]]$ProgramAreas
  )
  if (-not $ProgramsRoot -or -not (Test-Path $ProgramsRoot) -or $null -eq $ProgramAreas -or $ProgramAreas.Count -eq 0)
  {
    return @()
  }

  $subCategories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

  foreach ($pa in $ProgramAreas)
  {
    $paPath = Join-Path $ProgramsRoot $pa
    if (Test-Path $paPath)
    {
      $mdFiles = Get-ChildItem -Path $paPath -Filter "*.md" -File
      foreach ($file in $mdFiles)
      {
        try
        {
          $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
          if ($content -match "^---\s*[\r\n]+([\s\S]*?)[\r\n]+---")
          {
            $yamlBlock = $matches[1]
            $lines = $yamlBlock -split "[\r\n]+"
            $inSubCat = $false
            foreach ($line in $lines)
            {
              $trimmed = $line.Trim()
              if ($trimmed -like "subCategory:*")
              {
                $inSubCat = $true
                continue
              }
              if ($inSubCat)
              {
                if ($trimmed.StartsWith("-"))
                {
                  $sc = $trimmed.Substring(1).Trim().Trim('"').Trim("'")
                  if (-not [string]::IsNullOrWhiteSpace($sc))
                  {
                    [void]$subCategories.Add($sc)
                  }
                } elseif ($trimmed -match "^\w+:")
                {
                  $inSubCat = $false
                }
              }
            }
          }
        } catch
        {
          # Continue reading remaining files if one fails
        }
      }
    }
  }

  $result = [string[]]($subCategories | Sort-Object)
  return $result
}

function New-SanitizedFilename
{
  param (
    [string]$Title
  )
  if ([string]::IsNullOrWhiteSpace($Title))
  {
    return "Untitled.md"
  }
  # Remove invalid path characters: \ / : * ? " < > |
  $clean = $Title -replace '[\\/*?:"<>|]', ''
  $clean = $clean.Trim()
  if ([string]::IsNullOrWhiteSpace($clean))
  {
    $clean = "Untitled"
  }
  return "$clean.md"
}

function Format-MarkdownFrontmatter
{
  param (
    [string]$ItemId,
    [string]$ProgramArea,
    [string]$PubDate,
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
  if ($Title -match "[:'#]")
  {
    $escapedTitle = $Title -replace "'", "''"
    [void]$sb.AppendLine("title: '$escapedTitle'")
  } else
  {
    [void]$sb.AppendLine("title: $Title")
  }

  [void]$sb.AppendLine("programArea: $ProgramArea")
  [void]$sb.AppendLine("subCategory:")

  if ($null -ne $SubCategories -and $SubCategories.Count -gt 0)
  {
    foreach ($sc in $SubCategories)
    {
      if (-not [string]::IsNullOrWhiteSpace($sc))
      {
        [void]$sb.AppendLine("- $sc")
      }
    }
  } else
  {
    [void]$sb.AppendLine("- General")
  }

  [void]$sb.AppendLine("pubDate: $PubDate")
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

function Convert-RtfToMarkdown
{
  param (
    [System.Windows.Forms.RichTextBox]$RichTextBox
  )
  if ($null -eq $RichTextBox -or [string]::IsNullOrWhiteSpace($RichTextBox.Text))
  {
    return ""
  }

  # If simple text without rich formatting, return cleaned lines
  $text = $RichTextBox.Text

  # Convert bullets if any
  $lines = $text -split "\r?\n"
  $mdLines = @()
  foreach ($line in $lines)
  {
    if ($line.StartsWith("•\t") -or $line.StartsWith("• "))
    {
      $mdLines += "- " + $line.Substring(2).Trim()
    } elseif ($line.StartsWith("\t• "))
    {
      $mdLines += "  - " + $line.Substring(4).Trim()
    } else
    {
      $mdLines += $line
    }
  }
  return ($mdLines -join "`n")
}

function Get-NextUniqueItemId
{
  param (
    [string]$ProgramsRoot
  )
  $maxId = 44000
  if ($ProgramsRoot -and (Test-Path $ProgramsRoot))
  {
    $mdFiles = Get-ChildItem -Path $ProgramsRoot -Filter "*.md" -Recurse -File
    foreach ($file in $mdFiles)
    {
      try
      {
        $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
        if ($content -match "item_id:\s*['""]?(\d+)['""]?")
        {
          $val = [int]$matches[1]
          if ($val -gt $maxId)
          {
            $maxId = $val
          }
        }
      } catch
      {
      }
    }
  }
  return ($maxId + 1).ToString()
}

function Read-ProgramContentFile
{
  <#
  .SYNOPSIS
    Parses an existing program content Markdown file and returns a hashtable
    of the frontmatter fields plus the body text.
  #>
  param (
    [string]$FilePath
  )

  $result = @{
    ItemId      = ''
    ProgramArea = ''
    PubDate     = ''
    ExpiryDate  = ''
    EventType   = ''
    StartDate   = ''
    EndDate     = ''
    SubCategories = @()
    Title       = ''
    Body        = ''
  }

  $raw = Get-Content -LiteralPath $FilePath -Raw -Encoding UTF8
  if (-not ($raw -match "(?s)^---\r?\n(.*?)\r?\n---\r?\n?(.*)"))
  {
    # No frontmatter – treat everything as body
    $result.Body = $raw.Trim()
    return $result
  }

  $yamlBlock = $matches[1]
  $result.Body = $matches[2].Trim()

  $subCats = [System.Collections.Generic.List[string]]::new()
  $inSubCat = $false

  foreach ($line in ($yamlBlock -split '[\r\n]+'))
  {
    $trimmed = $line.Trim()
    if ($trimmed -match '^item_id:\s*[''"\s]*(.*?)[''"\s]*$')        { $result.ItemId      = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^programArea:\s*(.+)$')                     { $result.ProgramArea = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^pubDate:\s*(.+)$')                         { $result.PubDate     = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^expiryDate:\s*(.+)$')                      { $result.ExpiryDate  = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^eventType:\s*(.+)$')                       { $result.EventType   = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^startDate:\s*(.+)$')                       { $result.StartDate   = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^endDate:\s*(.+)$')                         { $result.EndDate     = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -match '^title:\s*[''"\s]*(.*?)[''"\s]*$')          { $result.Title       = $matches[1].Trim(); $inSubCat = $false; continue }
    if ($trimmed -eq 'subCategory:')                                 { $inSubCat = $true; continue }
    if ($inSubCat)
    {
      if ($trimmed.StartsWith('-'))
      {
        $sc = $trimmed.Substring(1).Trim().Trim('"').Trim("'")
        if (-not [string]::IsNullOrWhiteSpace($sc)) { [void]$subCats.Add($sc) }
      }
      elseif ($trimmed -match "^\w+:") { $inSubCat = $false }
    }
  }

  $result.SubCategories = [string[]]$subCats
  return $result
}

function Save-ProgramContent
{
  param (
    [string]$ProgramsRoot,
    [string[]]$SelectedPrograms,
    [string[]]$SelectedSubCategories,
    [string]$Title,
    [string]$BodyText,
    [string]$ItemId,
    [string]$PubDate,
    [string]$EventType,
    [string]$StartDate,
    [string]$EndDate,
    [string]$ExpiryDate
  )

  if (-not (Test-Path $ProgramsRoot))
  {
    throw "Programs root directory not found at '$ProgramsRoot'"
  }
  if ($null -eq $SelectedPrograms -or $SelectedPrograms.Count -eq 0)
  {
    throw "At least one Program Area must be selected."
  }
  if ([string]::IsNullOrWhiteSpace($Title))
  {
    throw "Title cannot be empty."
  }

  if ([string]::IsNullOrWhiteSpace($ItemId))
  {
    throw "ItemId cannot be empty."
  }
  if ([string]::IsNullOrWhiteSpace($PubDate))
  {
    $PubDate = (Get-Date).ToString("M/d/yyyy")
  }

  $fileName = New-SanitizedFilename -Title $Title
  $createdFiles = @()

  foreach ($pa in $SelectedPrograms)
  {
    $paDir = Join-Path $ProgramsRoot $pa
    if (-not (Test-Path $paDir))
    {
      New-Item -Path $paDir -ItemType Directory -Force | Out-Null
    }

    $filePath = Join-Path $paDir $fileName
    $mdContent = Format-MarkdownFrontmatter -ItemId $ItemId -ProgramArea $pa -PubDate $PubDate -EventType $EventType -StartDate $StartDate -EndDate $EndDate -ExpiryDate $ExpiryDate -SubCategories $SelectedSubCategories -Title $Title -Body $BodyText

    # Write UTF-8 without BOM or standard UTF8
    [System.IO.File]::WriteAllText($filePath, $mdContent, [System.Text.Encoding]::UTF8)
    $createdFiles += $filePath
  }

  return [string[]]$createdFiles
}

# ------------------------------------------------------------------------------
# GUI Construction (Windows Forms)
# ------------------------------------------------------------------------------

function Start-ProgramContentGui
{
  param (
    [string]$ProgramsRoot
  )

  if (-not (([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type))
  {
    Write-Error "Windows Forms is not supported or loaded in this environment."
    return
  }

  [System.Windows.Forms.Application]::EnableVisualStyles()

  $repoSync = Sync-FedCenterRepository -StartingPath $ProgramsRoot
  if (-not $repoSync.Success)
  {
    [System.Windows.Forms.MessageBox]::Show(
      $repoSync.Message,
      "Git Sync Warning",
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Warning)
  }

  $currentItemId = Get-NextUniqueItemId -ProgramsRoot $ProgramsRoot

  # Form Setup
  $form = New-Object System.Windows.Forms.Form
  $form.Text = "FedCenter - Create Program Content"
  $form.Size = New-Object System.Drawing.Size(950, 950)
  $form.MinimumSize = New-Object System.Drawing.Size(800, 650)
  $form.StartPosition = "CenterScreen"
  $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
  $form.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

  # Main Split Layout Panel
  $mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
  $mainPanel.Dock = "Fill"
  $mainPanel.Padding = New-Object System.Windows.Forms.Padding(12)
  $mainPanel.RowCount = 4
  $mainPanel.ColumnCount = 2

  # Row styles: Header (50px), Metadata/Category Selection (260px), Content Editor (100% fill), Action Bar (55px)
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 50)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 260)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 55)))

  # Column styles: 50% left, 50% right
  [void]$mainPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
  [void]$mainPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))

  # 1. Header Banner
  $headerLabel = New-Object System.Windows.Forms.Label
  $headerLabel.Text = "Program Area Content Creator"
  $headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
  $headerLabel.ForeColor = [System.Drawing.Color]::FromArgb(24, 43, 73)
  $headerLabel.AutoSize = $true
  $headerLabel.Anchor = "Left"
  $mainPanel.Controls.Add($headerLabel, 0, 0)
  $mainPanel.SetColumnSpan($headerLabel, 2)

  # 2. Program Area Group Box (Left Panel - Single Select)
  $grpPrograms = New-Object System.Windows.Forms.GroupBox
  $grpPrograms.Text = "1. Select Program Area"
  $grpPrograms.Dock = "Fill"
  $grpPrograms.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)

  $lstPrograms = New-Object System.Windows.Forms.ListBox
  $lstPrograms.Dock = "Fill"
  $lstPrograms.SelectionMode = "One"
  $lstPrograms.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)

  # Populate Program Areas
  $programAreas = Get-ProgramAreas -ProgramsRoot $ProgramsRoot
  foreach ($pa in $programAreas)
  {
    [void]$lstPrograms.Items.Add($pa)
  }

  $grpPrograms.Controls.Add($lstPrograms)
  $mainPanel.Controls.Add($grpPrograms, 0, 1)

  # 3. SubCategory Group Box (Right Panel)
  $grpSubCat = New-Object System.Windows.Forms.GroupBox
  $grpSubCat.Text = "2. Select SubCategory"
  $grpSubCat.Dock = "Fill"
  $grpSubCat.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)

  $subCatPanel = New-Object System.Windows.Forms.Panel
  $subCatPanel.Dock = "Fill"

  $subHeaderPanel = New-Object System.Windows.Forms.Panel
  $subHeaderPanel.Dock = "Top"
  $subHeaderPanel.Height = 30

  $btnSubSelectAll = New-Object System.Windows.Forms.Button
  $btnSubSelectAll.Text = "Select All"
  $btnSubSelectAll.Size = New-Object System.Drawing.Size(75, 24)
  $btnSubSelectAll.Location = New-Object System.Drawing.Point(0, 3)
  $btnSubSelectAll.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Regular)

  $btnSubClearAll = New-Object System.Windows.Forms.Button
  $btnSubClearAll.Text = "Clear All"
  $btnSubClearAll.Size = New-Object System.Drawing.Size(75, 24)
  $btnSubClearAll.Location = New-Object System.Drawing.Point(80, 3)
  $btnSubClearAll.Font = New-Object System.Drawing.Font("Segoe UI", 8.5, [System.Drawing.FontStyle]::Regular)

  $subHeaderPanel.Controls.Add($btnSubSelectAll)
  $subHeaderPanel.Controls.Add($btnSubClearAll)

  $lstSubCategories = New-Object System.Windows.Forms.CheckedListBox
  $lstSubCategories.Dock = "Fill"
  $lstSubCategories.CheckOnClick = $true
  $lstSubCategories.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)

  $subCatPanel.Controls.Add($lstSubCategories)
  $subCatPanel.Controls.Add($subHeaderPanel)
  $grpSubCat.Controls.Add($subCatPanel)
  $mainPanel.Controls.Add($grpSubCat, 1, 1)

  # Update SubCategories when single Program Area selection changes
  $lstPrograms.add_SelectedIndexChanged({
      $selectedPA = $lstPrograms.SelectedItem
      $lstSubCategories.Items.Clear()
      if (-not [string]::IsNullOrWhiteSpace($selectedPA))
      {
        $availableSubs = Get-SubCategoriesForPrograms -ProgramsRoot $ProgramsRoot -ProgramAreas @($selectedPA)
        foreach ($sub in $availableSubs)
        {
          [void]$lstSubCategories.Items.Add($sub, $false)
        }
      }
    })

  $btnSubSelectAll.add_Click({
      for ($i=0; $i -lt $lstSubCategories.Items.Count; $i++)
      {
        $lstSubCategories.SetItemChecked($i, $true)
      }
    })

  $btnSubClearAll.add_Click({
      for ($i=0; $i -lt $lstSubCategories.Items.Count; $i++)
      {
        $lstSubCategories.SetItemChecked($i, $false)
      }
    })

  # 4. Details & Content Editor Group Box (Spans Row 2 across both columns)
  $grpContent = New-Object System.Windows.Forms.GroupBox
  $grpContent.Text = "3. Entry Details & Content"
  $grpContent.Dock = "Fill"
  $grpContent.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)

  $contentContainer = New-Object System.Windows.Forms.TableLayoutPanel
  $contentContainer.Dock = "Fill"
  $contentContainer.RowCount = 8
  $contentContainer.ColumnCount = 2

  [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35))) # Row 0: Item ID
  [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35))) # Row 1: Title
  [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35))) # Row 2: Pub Date
  [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35))) # Row 3: Expiry Date
  [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35))) # Row 4: Event Type
  [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35))) # Row 5: Start Date
  [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35))) # Row 6: End Date
  [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100))) # Row 7: Editor

  [void]$contentContainer.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
  [void]$contentContainer.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))

  # Item ID Display
  $lblItemId = New-Object System.Windows.Forms.Label
  $lblItemId.Text = "Item ID:"
  $lblItemId.Anchor = "Left"
  $txtItemId = New-Object System.Windows.Forms.TextBox
  $txtItemId.Dock = "Fill"
  $txtItemId.Font = New-Object System.Drawing.Font("Segoe UI", 10.0)
  $txtItemId.ReadOnly = $true
  $txtItemId.TabStop = $false
  $txtItemId.Text = $currentItemId

  $contentContainer.Controls.Add($lblItemId, 0, 0)
  $contentContainer.Controls.Add($txtItemId, 1, 0)

  # Title Input
  $lblTitle = New-Object System.Windows.Forms.Label
  $lblTitle.Text = "Title:"
  $lblTitle.Anchor = "Left"
  $txtTitle = New-Object System.Windows.Forms.TextBox
  $txtTitle.Dock = "Fill"
  $txtTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10.0)

  $contentContainer.Controls.Add($lblTitle, 0, 1)
  $contentContainer.Controls.Add($txtTitle, 1, 1)

  # Publication Date Input (required)
  $lblPubDate = New-Object System.Windows.Forms.Label
  $lblPubDate.Text = "Pub Date:"
  $lblPubDate.Anchor = "Left"
  $dtpPubDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpPubDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
  $dtpPubDate.Dock = "Fill"

    # Expiry Date (optional)
  $lblExpiryDate = New-Object System.Windows.Forms.Label
  $lblExpiryDate.Text = "Expiry:"
  $lblExpiryDate.Anchor = "Left"
  $dtpExpiryDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpExpiryDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
  $dtpExpiryDate.ShowCheckBox = $true
  $dtpExpiryDate.Checked = $false
  $dtpExpiryDate.Dock = "Fill"

  # Event Type Dropdown (optional, nothing selected by default)
  $lblEventType = New-Object System.Windows.Forms.Label
  $lblEventType.Text = "Event:"
  $lblEventType.Anchor = "Left"
  $cbEventType = New-Object System.Windows.Forms.ComboBox
  $cbEventType.Dock = "Fill"
  $cbEventType.DropDownStyle = "DropDownList"
  $cbEventType.Items.AddRange(@("Training", "Conferences", "Meetings", "Other"))
  $cbEventType.SelectedIndex = -1  # Nothing selected

  # Start Date (optional)
  $lblStartDate = New-Object System.Windows.Forms.Label
  $lblStartDate.Text = "Start Date:"
  $lblStartDate.Anchor = "Left"
  $dtpStartDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpStartDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
  $dtpStartDate.ShowCheckBox = $true
  $dtpStartDate.Checked = $false
  $dtpStartDate.Dock = "Fill"

  # End Date (optional)
  $lblEndDate = New-Object System.Windows.Forms.Label
  $lblEndDate.Text = "End Date:"
  $lblEndDate.Anchor = "Left"
  $dtpEndDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpEndDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
  $dtpEndDate.ShowCheckBox = $true
  $dtpEndDate.Checked = $false
  $dtpEndDate.Dock = "Fill"

  $contentContainer.Controls.Add($lblPubDate, 0, 2)
  $contentContainer.Controls.Add($dtpPubDate, 1, 2)
  $contentContainer.Controls.Add($lblExpiryDate, 0, 3)
  $contentContainer.Controls.Add($dtpExpiryDate, 1, 3)
  $contentContainer.Controls.Add($lblEventType, 0, 4)
  $contentContainer.Controls.Add($cbEventType, 1, 4)
  $contentContainer.Controls.Add($lblStartDate, 0, 5)
  $contentContainer.Controls.Add($dtpStartDate, 1, 5)
  $contentContainer.Controls.Add($lblEndDate, 0, 6)
  $contentContainer.Controls.Add($dtpEndDate, 1, 6)

  # Rich Text Editor Box with Formatting Toolbar
  $editorPanel = New-Object System.Windows.Forms.Panel
  $editorPanel.Dock = "Fill"

  $toolbar = New-Object System.Windows.Forms.ToolStrip
  $toolbar.GripStyle = "Hidden"

  $btnBold = New-Object System.Windows.Forms.ToolStripButton
  $btnBold.Text = "B"
  $btnBold.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
  $btnBold.ToolTipText = "Bold Selected Text"

  $btnItalic = New-Object System.Windows.Forms.ToolStripButton
  $btnItalic.Text = "I"
  $btnItalic.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Italic)
  $btnItalic.ToolTipText = "Italicize Selected Text"

  $btnBullet = New-Object System.Windows.Forms.ToolStripButton
  $btnBullet.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)
  #
  $btnBullet.Text = [char]0x2022 + " Bullet List"
  $btnBullet.ToolTipText = "Toggle Bullet List"

  $btnH2 = New-Object System.Windows.Forms.ToolStripButton
  $btnH2.Text = "H2 Header"
  $btnH2.ToolTipText = "Insert Heading 2"

  $btnLink = New-Object System.Windows.Forms.ToolStripButton
  $btnLink.Text = "Insert Link"
  $btnLink.ToolTipText = "Insert Markdown Link"

  $btnClearFmt = New-Object System.Windows.Forms.ToolStripButton
  $btnClearFmt.Text = "Clear Text"
  $btnClearFmt.ToolTipText = "Clear Body Text"

  [void]$toolbar.Items.Add($btnBold)
  [void]$toolbar.Items.Add($btnItalic)
  [void]$toolbar.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  [void]$toolbar.Items.Add($btnH2)
  [void]$toolbar.Items.Add($btnBullet)
  [void]$toolbar.Items.Add($btnLink)
  [void]$toolbar.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  [void]$toolbar.Items.Add($btnClearFmt)

  $rtbContent = New-Object System.Windows.Forms.RichTextBox
  $rtbContent.Dock = "Fill"
  $rtbContent.Font = New-Object System.Drawing.Font("Consolas", 10.0)
  $rtbContent.AcceptsTab = $true

  # Toolbar Button Event Handlers
  $btnBold.add_Click({
      if ($rtbContent.SelectionLength -gt 0)
      {
        $sel = $rtbContent.SelectedText
        $rtbContent.SelectedText = "**$sel**"
      } else
      {
        $rtbContent.AppendText("**bold text**")
      }
    })

  $btnItalic.add_Click({
      if ($rtbContent.SelectionLength -gt 0)
      {
        $sel = $rtbContent.SelectedText
        $rtbContent.SelectedText = "*$sel*"
      } else
      {
        $rtbContent.AppendText("*italic text*")
      }
    })

  $btnH2.add_Click({
      if ($rtbContent.SelectionLength -gt 0)
      {
        $sel = $rtbContent.SelectedText
        $rtbContent.SelectedText = "`n## $sel`n"
      } else
      {
        $rtbContent.AppendText("`n## Section Header`n")
      }
    })

  $btnBullet.add_Click({
      if ($rtbContent.SelectionLength -gt 0)
      {
        $lines = $rtbContent.SelectedText -split "\r?\n"
        $bLines = $lines | ForEach-Object { "- $_" }
        $rtbContent.SelectedText = ($bLines -join "`n")
      } else
      {
        $rtbContent.AppendText("`n- Bullet point item`n")
      }
    })

  $btnLink.add_Click({
      $linkText = if ($rtbContent.SelectionLength -gt 0)
      { $rtbContent.SelectedText
      } else
      { "Link Text"
      }
      $rtbContent.SelectedText = "[$linkText](https://example.gov)"
    })

  $btnClearFmt.add_Click({
      $rtbContent.Clear()
    })

  $editorPanel.Controls.Add($rtbContent)
  $editorPanel.Controls.Add($toolbar)

  $contentContainer.Controls.Add($editorPanel, 0, 7)
  $contentContainer.SetColumnSpan($editorPanel, 2)

  $grpContent.Controls.Add($contentContainer)
  $mainPanel.Controls.Add($grpContent, 0, 2)
  $mainPanel.SetColumnSpan($grpContent, 2)

  # 5. Bottom Action Bar (Row 3)
  $actionPanel = New-Object System.Windows.Forms.FlowLayoutPanel
  $actionPanel.Dock = "Fill"
  $actionPanel.FlowDirection = "RightToLeft"
  $actionPanel.Padding = New-Object System.Windows.Forms.Padding(0, 5, 0, 0)

  $btnSave = New-Object System.Windows.Forms.Button
  $btnSave.Text = "Save Content"
  $btnSave.Size = New-Object System.Drawing.Size(140, 36)
  $btnSave.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 180)
  $btnSave.ForeColor = [System.Drawing.Color]::White
  $btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
  $btnSave.FlatStyle = "Flat"

  $btnCommit = New-Object System.Windows.Forms.Button
  $btnCommit.Text = "Publish Changes"
  $btnCommit.Size = New-Object System.Drawing.Size(130, 36)
  $btnCommit.BackColor = [System.Drawing.Color]::FromArgb(34, 139, 34)
  $btnCommit.ForeColor = [System.Drawing.Color]::White
  $btnCommit.Font = New-Object System.Drawing.Font("Segoe UI", 9.0, [System.Drawing.FontStyle]::Bold)
  $btnCommit.FlatStyle = "Flat"

  $btnClear = New-Object System.Windows.Forms.Button
  $btnClear.Text = "New Item"
  $btnClear.Size = New-Object System.Drawing.Size(100, 36)
  $btnClear.Font = New-Object System.Drawing.Font("Segoe UI", 9.0)

  $btnExit = New-Object System.Windows.Forms.Button
  $btnExit.Text = "Close"
  $btnExit.Size = New-Object System.Drawing.Size(90, 36)
  $btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 9.0)

  # $btnLoad = New-Object System.Windows.Forms.Button
  # $btnLoad.Text = "Load File"
  # $btnLoad.Size = New-Object System.Drawing.Size(100, 36)
  # $btnLoad.Font = New-Object System.Drawing.Font("Segoe UI", 9.0)

  $actionPanel.Controls.Add($btnSave)
  $actionPanel.Controls.Add($btnCommit)
  $actionPanel.Controls.Add($btnClear)
  # $actionPanel.Controls.Add($btnLoad)
  $actionPanel.Controls.Add($btnExit)

  $mainPanel.Controls.Add($actionPanel, 0, 3)
  $mainPanel.SetColumnSpan($actionPanel, 2)

  $form.Controls.Add($mainPanel)

  # Form Button Event Handlers
  $btnSave.add_Click({
      try
      {
        $selectedPA = $lstPrograms.SelectedItem
        if ([string]::IsNullOrWhiteSpace($selectedPA))
        {
          [System.Windows.Forms.MessageBox]::Show("Please select a Program Area.", "Validation Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
          return
        }

        $title = $txtTitle.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($title))
        {
          [System.Windows.Forms.MessageBox]::Show("Please enter a Title.", "Validation Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
          $txtTitle.Focus()
          return
        }

        $selectedSubs = @()
        foreach ($sub in $lstSubCategories.CheckedItems)
        {
          $selectedSubs += $sub.ToString()
        }

        $bodyText = Convert-RtfToMarkdown -RichTextBox $rtbContent
        # Publication date (required)
        $pubDate = $dtpPubDate.Value.ToString("M/d/yyyy")
        # Optional eventType
        $eventType = if ($cbEventType.SelectedIndex -ge 0) { $cbEventType.SelectedItem.ToString() } else { "" }
        # Optional dates
        $startDate = if ($dtpStartDate.Checked) { $dtpStartDate.Value.ToString("M/d/yyyy") } else { "" }
        $endDate = if ($dtpEndDate.Checked) { $dtpEndDate.Value.ToString("M/d/yyyy") } else { "" }
        $expiryDate = if ($dtpExpiryDate.Checked) { $dtpExpiryDate.Value.ToString("M/d/yyyy") } else { "" }

        $savedFiles = Save-ProgramContent -ProgramsRoot $ProgramsRoot -SelectedPrograms @($selectedPA) -SelectedSubCategories $selectedSubs -Title $title -BodyText $bodyText -ItemId $txtItemId.Text.Trim() -PubDate $pubDate -EventType $eventType -StartDate $startDate -EndDate $endDate -ExpiryDate $expiryDate

        $msg = "Successfully saved markdown file:`n`n" + ($savedFiles -join "`n")
        [System.Windows.Forms.MessageBox]::Show($msg, "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

      } catch
      {
        [System.Windows.Forms.MessageBox]::Show("Error saving markdown file: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
      }
    })

  $btnClear.add_Click({
      $txtTitle.Clear()
      $rtbContent.Clear()
      $lstPrograms.ClearSelected()
      $lstSubCategories.Items.Clear()
      $cbEventType.SelectedIndex = -1
      $dtpPubDate.Value = Get-Date
      $dtpStartDate.Checked = $false
      $dtpEndDate.Checked = $false
      $dtpExpiryDate.Checked = $false
      $form.Text = "FedCenter - Create Program Content"
      $currentItemId = if ($txtItemId.Text.Trim() -as [int])
      {
        (([int]$txtItemId.Text.Trim()) + 1).ToString()
      }
      else
      {
        Get-NextUniqueItemId -ProgramsRoot $ProgramsRoot
      }
      $txtItemId.Text = $currentItemId
    })

  # $btnLoad.add_Click({
  #     $ofd = New-Object System.Windows.Forms.OpenFileDialog
  #     $ofd.Title = "Open Program Content File"
  #     $ofd.Filter = "Markdown Files (*.md)|*.md"
  #     $ofd.InitialDirectory = $ProgramsRoot
  #     if ($ofd.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return }

  #     try
  #     {
  #       $parsed = Read-ProgramContentFile -FilePath $ofd.FileName
  #       $currentItemId = if ([string]::IsNullOrWhiteSpace($parsed.ItemId))
  #       {
  #         Get-NextUniqueItemId -ProgramsRoot $ProgramsRoot
  #       }
  #       else
  #       {
  #         $parsed.ItemId
  #       }
  #       $txtItemId.Text = $currentItemId

  #       # --- Title ---
  #       $txtTitle.Text = $parsed.Title

  #       # --- Program Area ---
  #       $lstPrograms.ClearSelected()
  #       $paIdx = $lstPrograms.FindStringExact($parsed.ProgramArea)
  #       if ($paIdx -ge 0) { $lstPrograms.SelectedIndex = $paIdx }

  #       # --- SubCategories (after PA triggers population) ---
  #       # Give the SelectedIndexChanged handler a moment to populate the list
  #       [System.Windows.Forms.Application]::DoEvents()
  #       for ($i = 0; $i -lt $lstSubCategories.Items.Count; $i++)
  #       {
  #         $isChecked = $parsed.SubCategories -contains $lstSubCategories.Items[$i].ToString()
  #         $lstSubCategories.SetItemChecked($i, $isChecked)
  #       }
  #       # Add any subcategories from the file that weren't already in the list
  #       foreach ($sc in $parsed.SubCategories)
  #       {
  #         $found = $false
  #         for ($i = 0; $i -lt $lstSubCategories.Items.Count; $i++)
  #         {
  #           if ($lstSubCategories.Items[$i].ToString() -ieq $sc) { $found = $true; break }
  #         }
  #         if (-not $found)
  #         {
  #           $idx = $lstSubCategories.Items.Add($sc)
  #           $lstSubCategories.SetItemChecked($idx, $true)
  #         }
  #       }

  #       # --- Pub Date ---
  #       # Use try/catch rather than [datetime]::TryParse([ref]) which fails inside PS script blocks
  #       try { $dtpPubDate.Value = [datetime]::Parse($parsed.PubDate, [System.Globalization.CultureInfo]::GetCultureInfo("en-US")) }
  #       catch { $dtpPubDate.Value = Get-Date }

  #       Write-Host "Parsed pub date: $($dtpPubDate.Value)"

  #       # --- Event Type ---
  #       if (-not [string]::IsNullOrWhiteSpace($parsed.EventType))
  #       {
  #         $eventType = ($parsed.EventType).Trim()
  #         # if eventType is not in our list, set to 'Other'
  #         if ($eventType -notin $cbEventType.Items) { $eventType = 'Other' }
  #         $cbEventType.SelectedItem = $eventType
  #       }
  #       # --- Optional dates ---
  #       if (-not [string]::IsNullOrWhiteSpace($parsed.StartDate))
  #       {
  #         try { $dtpStartDate.Value = [datetime]::Parse($parsed.StartDate, [System.Globalization.CultureInfo]::GetCultureInfo("en-US")); $dtpStartDate.Checked = $true }
  #         catch { $dtpStartDate.Checked = $false }
  #       }
  #       else { $dtpStartDate.Checked = $false }

  #       if (-not [string]::IsNullOrWhiteSpace($parsed.EndDate))
  #       {
  #         try { $dtpEndDate.Value = [datetime]::Parse($parsed.EndDate, [System.Globalization.CultureInfo]::GetCultureInfo("en-US")); $dtpEndDate.Checked = $true }
  #         catch { $dtpEndDate.Checked = $false }
  #       }
  #       else { $dtpEndDate.Checked = $false }

  #       if (-not [string]::IsNullOrWhiteSpace($parsed.ExpiryDate))
  #       {
  #         try { $dtpExpiryDate.Value = [datetime]::Parse($parsed.ExpiryDate, [System.Globalization.CultureInfo]::GetCultureInfo("en-US")); $dtpExpiryDate.Checked = $true }
  #         catch { $dtpExpiryDate.Checked = $false }
  #       }
  #       else { $dtpExpiryDate.Checked = $false }

  #       # --- Body ---
  #       $rtbContent.Text = $parsed.Body

  #       $form.Text = "FedCenter - Editing: " + [System.IO.Path]::GetFileName($ofd.FileName)
  #     }
  #     catch
  #     {
  #       [System.Windows.Forms.MessageBox]::Show(
  #         "Failed to load file:`n$_", "Load Error",
  #         [System.Windows.Forms.MessageBoxButtons]::OK,
  #         [System.Windows.Forms.MessageBoxIcon]::Error)
  #     }
  #   })

  $btnCommit.add_Click({
      try
      {
        Invoke-FedCenterContentCommitPush -StartingPath $ProgramsRoot -ParentWindow $form
      }
      catch
      {
        [System.Windows.Forms.MessageBox]::Show(
          "Commit/Push failed:`n$_", "Error",
          [System.Windows.Forms.MessageBoxButtons]::OK,
          [System.Windows.Forms.MessageBoxIcon]::Error)
      }
    })

  $btnExit.add_Click({
      # $ChangedFiles = $(git status --porcelain | Measure-Object | Select-Object -expand Count)
      # # We really only care about changed files under content directory
      # if ($ChangedFiles -gt 0)
      # {
      #   [System.Windows.Forms.MessageBox]::Show("You have uncommitted changes. Don't forgot to commit and push your changes so they can go live.`n`nChanged files: $ChangedFiles", "Uncommited Changes", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
      # }

      $form.Close()
    })

  # Show Modal Dialog
  [void]$form.ShowDialog()
}

# ------------------------------------------------------------------------------
# Entry Point Execution
# ------------------------------------------------------------------------------

if ($MyInvocation.InvocationName -ne '.')
{
  $programsRootPath = Get-FedCenterProgramsRoot
  if (-not $programsRootPath)
  {
    Write-Warning "Could not automatically locate 'src/content/programs' directory."
  } else
  {
    Write-Host "Found FedCenter programs root at: $programsRootPath"
  }

  if (([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type)
  {
    Start-ProgramContentGui -ProgramsRoot $programsRootPath
  } else
  {
    Write-Host "PowerShell script loaded."
    Write-Host "Run 'Start-ProgramContentGui' or 'Save-ProgramContent' to proceed."
  }
}
