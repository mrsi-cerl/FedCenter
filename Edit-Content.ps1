# ==============================================================================
# Script: Edit-Content.ps1
# Description: PowerShell GUI tool for locating and editing existing program
#              content Markdown files by item_id or title.
# ==============================================================================

try
{
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
  Add-Type -AssemblyName System.Drawing -ErrorAction Stop
} catch
{
  Write-Verbose "WinForms assemblies unavailable in current environment."
}

. (Join-Path $PSScriptRoot 'Create-Content.ps1')

function Search-ProgramContentEntries
{
  param (
    [string]$ProgramsRoot,
    [string]$Query,
    [ValidateSet('Auto', 'Item ID', 'Title')]
    [string]$SearchMode = 'Auto'
  )

  if (-not $ProgramsRoot -or -not (Test-Path $ProgramsRoot))
  {
    return @()
  }

  Write-Host "  Searching for program content files in '$ProgramsRoot'..."

  $normalizedQuery = if ($null -eq $Query) { '' } else { $Query.Trim() }
  $allEntries = New-Object System.Collections.Generic.List[object]

  foreach ($file in (Get-ChildItem -Path $ProgramsRoot -Filter '*.md' -Recurse -File | Sort-Object FullName))
  {
    try
    {
      $parsed = Read-ProgramContentFile -FilePath $file.FullName
      $entry = [pscustomobject]@{
        Display      = "[{0}] {1} ({2})" -f $parsed.ItemId, $parsed.Title, $parsed.ProgramArea
        FilePath     = $file.FullName
        FileName     = $file.Name
        ItemId       = $parsed.ItemId
        Title        = $parsed.Title
        ProgramArea  = $parsed.ProgramArea
        SubCategories = [string[]]$parsed.SubCategories
        PubDate      = $parsed.PubDate
        ExpiryDate   = $parsed.ExpiryDate
        EventType    = $parsed.EventType
        StartDate    = $parsed.StartDate
        EndDate      = $parsed.EndDate
        Body         = $parsed.Body
      }

      if ([string]::IsNullOrWhiteSpace($normalizedQuery))
      {
        [void]$allEntries.Add($entry)
        continue
      }

      $matchesItemId = $entry.ItemId -like "*$normalizedQuery*"
      $matchesTitle = $entry.Title -like "*$normalizedQuery*"

      switch ($SearchMode)
      {
        'Item ID'
        {
          if ($matchesItemId) { [void]$allEntries.Add($entry) }
        }
        'Title'
        {
          if ($matchesTitle) { [void]$allEntries.Add($entry) }
        }
        default
        {
          if ($matchesItemId -or $matchesTitle) { [void]$allEntries.Add($entry) }
        }
      }
    } catch
    {
      Write-Verbose "Skipping unreadable file '$($file.FullName)': $_"
    }
  }

  return [object[]]$allEntries
}

function Get-ProgramContentEntriesByItemId
{
  param (
    [string]$ProgramsRoot,
    [string]$ItemId
  )

  if ([string]::IsNullOrWhiteSpace($ItemId))
  {
    return @()
  }

  return @(Search-ProgramContentEntries -ProgramsRoot $ProgramsRoot -Query $ItemId -SearchMode 'Item ID' |
      Where-Object { $_.ItemId -eq $ItemId } |
      Sort-Object ProgramArea, FilePath)
}

function Get-ProgramContentLocationsText
{
  param (
    [object[]]$Entries
  )

  if ($null -eq $Entries -or $Entries.Count -eq 0)
  {
    return ''
  }

  $lines = foreach ($entry in $Entries)
  {
    $subCategories = if ($entry.SubCategories -and $entry.SubCategories.Count -gt 0)
    {
      $entry.SubCategories -join ', '
    }
    else
    {
      'General'
    }

    "{0}`r`n  SubCategory: {1}`r`n  File: {2}" -f $entry.ProgramArea, $subCategories, $entry.FilePath
  }

  return ($lines -join "`r`n`r`n")
}

function Update-ProgramContentGroup
{
  param (
    [object[]]$Entries,
    [string]$Title,
    [string]$PubDate,
    [string]$ExpiryDate,
    [string]$EventType,
    [string]$StartDate,
    [string]$EndDate,
    [string]$BodyText
  )

  if ($null -eq $Entries -or $Entries.Count -eq 0)
  {
    throw 'No content files were selected to update.'
  }

  if ([string]::IsNullOrWhiteSpace($Title))
  {
    throw 'Title cannot be empty.'
  }

  foreach ($entry in $Entries)
  {
    $current = Read-ProgramContentFile -FilePath $entry.FilePath
    $markdown = Format-MarkdownFrontmatter `
      -ItemId $current.ItemId `
      -ProgramArea $current.ProgramArea `
      -PubDate $PubDate `
      -EventType $EventType `
      -StartDate $StartDate `
      -EndDate $EndDate `
      -ExpiryDate $ExpiryDate `
      -SubCategories $current.SubCategories `
      -Title $Title `
      -Body $BodyText

    [System.IO.File]::WriteAllText($entry.FilePath, $markdown, [System.Text.Encoding]::UTF8)
  }
}

function Start-EditContentGui
{
  param (
    [string]$ProgramsRoot
  )

  if (-not (([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type))
  {
    Write-Error 'Windows Forms is not supported or loaded in this environment.'
    return
  }

  [System.Windows.Forms.Application]::EnableVisualStyles()

  Write-Host "Starting FedCenter Program Content Editor"
  Write-Host "  Ensuring your content is current..."
  $repoSync = Sync-FedCenterRepository -StartingPath $ProgramsRoot
  if (-not $repoSync.Success)
  {
    [System.Windows.Forms.MessageBox]::Show(
      $repoSync.Message,
      'Git Sync Warning',
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Warning)
  }

  $editorState = [pscustomobject]@{
    LoadedEntries = @()
  }

  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'FedCenter - Edit Program Content'
  $form.Size = New-Object System.Drawing.Size(1100, 900)
  $form.MinimumSize = New-Object System.Drawing.Size(980, 760)
  $form.StartPosition = 'CenterScreen'
  $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
  $form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

  $mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
  $mainPanel.Dock = 'Fill'
  $mainPanel.Padding = New-Object System.Windows.Forms.Padding(12)
  $mainPanel.RowCount = 4
  $mainPanel.ColumnCount = 1
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 250)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 58)))

  $headerLabel = New-Object System.Windows.Forms.Label
  $headerLabel.Text = 'Program Content Editor'
  $headerLabel.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
  $headerLabel.ForeColor = [System.Drawing.Color]::FromArgb(24, 43, 73)
  $headerLabel.AutoSize = $true
  $headerLabel.Anchor = 'Left'
  $mainPanel.Controls.Add($headerLabel, 0, 0)

  $searchGroup = New-Object System.Windows.Forms.GroupBox
  $searchGroup.Text = '1. Search and Select Content Files'
  $searchGroup.Dock = 'Fill'
  $searchGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

  $searchLayout = New-Object System.Windows.Forms.TableLayoutPanel
  $searchLayout.Dock = 'Fill'
  $searchLayout.RowCount = 3
  $searchLayout.ColumnCount = 4
  [void]$searchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90)))
  [void]$searchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
  [void]$searchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
  [void]$searchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 170)))
  [void]$searchLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 36)))
  [void]$searchLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
  [void]$searchLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 34)))

  $lblSearchBy = New-Object System.Windows.Forms.Label
  $lblSearchBy.Text = 'Search By:'
  $lblSearchBy.Anchor = 'Left'

  $cbSearchMode = New-Object System.Windows.Forms.ComboBox
  $cbSearchMode.Dock = 'Fill'
  $cbSearchMode.DropDownStyle = 'DropDownList'
  [void]$cbSearchMode.Items.AddRange(@('Auto', 'Item ID', 'Title'))
  $cbSearchMode.SelectedItem = 'Auto'

  $txtSearch = New-Object System.Windows.Forms.TextBox
  $txtSearch.Dock = 'Fill'
  $txtSearch.Font = New-Object System.Drawing.Font('Segoe UI', 10.0)

  $searchButtonPanel = New-Object System.Windows.Forms.FlowLayoutPanel
  $searchButtonPanel.Dock = 'Fill'
  $searchButtonPanel.FlowDirection = 'RightToLeft'

  $btnSearch = New-Object System.Windows.Forms.Button
  $btnSearch.Text = 'Search'
  $btnSearch.Size = New-Object System.Drawing.Size(80, 28)

  $btnLoadSelection = New-Object System.Windows.Forms.Button
  $btnLoadSelection.Text = 'Load Selection'
  $btnLoadSelection.Size = New-Object System.Drawing.Size(120, 28)

  $searchButtonPanel.Controls.Add($btnLoadSelection)
  $searchButtonPanel.Controls.Add($btnSearch)

  $lstResults = New-Object System.Windows.Forms.ListBox
  $lstResults.Dock = 'Fill'
  $lstResults.SelectionMode = 'MultiExtended'
  $lstResults.DisplayMember = 'Display'
  $lstResults.Font = New-Object System.Drawing.Font('Consolas', 9.0)

  $lblSearchHelp = New-Object System.Windows.Forms.Label
  $lblSearchHelp.Text = 'Select an item to edit. If multiple files share the same Item ID, all will be updated with the same shared field values.'
  $lblSearchHelp.Dock = 'Fill'
  $lblSearchHelp.TextAlign = 'MiddleLeft'

  $searchLayout.Controls.Add($lblSearchBy, 0, 0)
  $searchLayout.Controls.Add($cbSearchMode, 1, 0)
  $searchLayout.Controls.Add($txtSearch, 2, 0)
  $searchLayout.Controls.Add($searchButtonPanel, 3, 0)
  $searchLayout.Controls.Add($lstResults, 0, 1)
  $searchLayout.SetColumnSpan($lstResults, 4)
  $searchLayout.Controls.Add($lblSearchHelp, 0, 2)
  $searchLayout.SetColumnSpan($lblSearchHelp, 4)
  $searchGroup.Controls.Add($searchLayout)
  $mainPanel.Controls.Add($searchGroup, 0, 1)

  $editorGroup = New-Object System.Windows.Forms.GroupBox
  $editorGroup.Text = '2. Edit Shared Fields'
  $editorGroup.Dock = 'Fill'
  $editorGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

  $editorLayout = New-Object System.Windows.Forms.TableLayoutPanel
  $editorLayout.Dock = 'Fill'
  $editorLayout.RowCount = 9
  $editorLayout.ColumnCount = 2
  [void]$editorLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 110)))
  [void]$editorLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
  [void]$editorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
  [void]$editorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
  [void]$editorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
  [void]$editorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
  [void]$editorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
  [void]$editorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
  [void]$editorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 100)))
  [void]$editorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
  [void]$editorLayout.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 28)))

  $lblItemId = New-Object System.Windows.Forms.Label
  $lblItemId.Text = 'Item ID:'
  $lblItemId.Anchor = 'Left'
  $txtItemId = New-Object System.Windows.Forms.TextBox
  $txtItemId.Dock = 'Fill'
  $txtItemId.ReadOnly = $true

  $lblTitle = New-Object System.Windows.Forms.Label
  $lblTitle.Text = 'Title:'
  $lblTitle.Anchor = 'Left'
  $txtTitle = New-Object System.Windows.Forms.TextBox
  $txtTitle.Dock = 'Fill'
  $txtTitle.Font = New-Object System.Drawing.Font('Segoe UI', 10.0)

  $lblPubDate = New-Object System.Windows.Forms.Label
  $lblPubDate.Text = 'Pub Date:'
  $lblPubDate.Anchor = 'Left'
  $dtpPubDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpPubDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
  $dtpPubDate.Dock = 'Fill'

  $lblExpiryDate = New-Object System.Windows.Forms.Label
  $lblExpiryDate.Text = 'Expiry Date:'
  $lblExpiryDate.Anchor = 'Left'
  $dtpExpiryDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpExpiryDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
  $dtpExpiryDate.ShowCheckBox = $true
  $dtpExpiryDate.Checked = $false
  $dtpExpiryDate.Dock = 'Fill'

  $lblEventType = New-Object System.Windows.Forms.Label
  $lblEventType.Text = 'Event Type:'
  $lblEventType.Anchor = 'Left'
  $cbEventType = New-Object System.Windows.Forms.ComboBox
  $cbEventType.Dock = 'Fill'
  $cbEventType.DropDownStyle = 'DropDownList'
  [void]$cbEventType.Items.AddRange(@('Training', 'Conferences', 'Meetings', 'Other'))
  $cbEventType.SelectedIndex = -1

  $datePanel = New-Object System.Windows.Forms.TableLayoutPanel
  $datePanel.Dock = 'Fill'
  $datePanel.RowCount = 1
  $datePanel.ColumnCount = 4
  [void]$datePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 75)))
  [void]$datePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))
  [void]$datePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 65)))
  [void]$datePanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 50)))

  $lblStartDate = New-Object System.Windows.Forms.Label
  $lblStartDate.Text = 'Start:'
  $lblStartDate.Anchor = 'Left'
  $dtpStartDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpStartDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
  $dtpStartDate.CustomFormat = 'M/d/yyyy HH:mm'
  $dtpStartDate.ShowCheckBox = $true
  $dtpStartDate.Checked = $false
  $dtpStartDate.Dock = 'Fill'

  $lblEndDate = New-Object System.Windows.Forms.Label
  $lblEndDate.Text = 'End:'
  $lblEndDate.Anchor = 'Left'
  $dtpEndDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpEndDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
  $dtpEndDate.CustomFormat = 'M/d/yyyy HH:mm'
  $dtpEndDate.ShowCheckBox = $true
  $dtpEndDate.Checked = $false
  $dtpEndDate.Dock = 'Fill'

  $datePanel.Controls.Add($lblStartDate, 0, 0)
  $datePanel.Controls.Add($dtpStartDate, 1, 0)
  $datePanel.Controls.Add($lblEndDate, 2, 0)
  $datePanel.Controls.Add($dtpEndDate, 3, 0)

  $lblLocations = New-Object System.Windows.Forms.Label
  $lblLocations.Text = 'Areas:'
  $lblLocations.Anchor = 'Left'
  $txtLocations = New-Object System.Windows.Forms.TextBox
  $txtLocations.Dock = 'Fill'
  $txtLocations.Multiline = $true
  $txtLocations.ReadOnly = $true
  $txtLocations.ScrollBars = 'Vertical'
  $txtLocations.Font = New-Object System.Drawing.Font('Consolas', 9.0)

  $editorPanel = New-Object System.Windows.Forms.Panel
  $editorPanel.Dock = 'Fill'

  $toolbar = New-Object System.Windows.Forms.ToolStrip
  $toolbar.GripStyle = 'Hidden'

  $btnBold = New-Object System.Windows.Forms.ToolStripButton
  $btnBold.Text = 'B'
  $btnBold.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
  $btnBold.ToolTipText = 'Bold Selected Text'

  $btnItalic = New-Object System.Windows.Forms.ToolStripButton
  $btnItalic.Text = 'I'
  $btnItalic.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Italic)
  $btnItalic.ToolTipText = 'Italicize Selected Text'

  $btnBullet = New-Object System.Windows.Forms.ToolStripButton
  $btnBullet.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
  $btnBullet.Text = [char]0x2022 + ' Bullet List'
  $btnBullet.ToolTipText = 'Toggle Bullet List'

  $btnH2 = New-Object System.Windows.Forms.ToolStripButton
  $btnH2.Text = 'H2 Header'
  $btnH2.ToolTipText = 'Insert Heading 2'

  $btnLink = New-Object System.Windows.Forms.ToolStripButton
  $btnLink.Text = 'Insert Link'
  $btnLink.ToolTipText = 'Insert Markdown Link'

  $btnClearFmt = New-Object System.Windows.Forms.ToolStripButton
  $btnClearFmt.Text = 'Clear Text'
  $btnClearFmt.ToolTipText = 'Clear Body Text'

  [void]$toolbar.Items.Add($btnBold)
  [void]$toolbar.Items.Add($btnItalic)
  [void]$toolbar.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  [void]$toolbar.Items.Add($btnH2)
  [void]$toolbar.Items.Add($btnBullet)
  [void]$toolbar.Items.Add($btnLink)
  [void]$toolbar.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
  [void]$toolbar.Items.Add($btnClearFmt)

  $rtbBody = New-Object System.Windows.Forms.RichTextBox
  $rtbBody.Dock = 'Fill'
  $rtbBody.Font = New-Object System.Drawing.Font('Consolas', 10.0)
  $rtbBody.AcceptsTab = $true

  $btnBold.add_Click({
      if ($rtbBody.SelectionLength -gt 0)
      {
        $sel = $rtbBody.SelectedText
        $rtbBody.SelectedText = "**$sel**"
      }
      else
      {
        $rtbBody.AppendText('**bold text**')
      }
    })

  $btnItalic.add_Click({
      if ($rtbBody.SelectionLength -gt 0)
      {
        $sel = $rtbBody.SelectedText
        $rtbBody.SelectedText = "*$sel*"
      }
      else
      {
        $rtbBody.AppendText('*italic text*')
      }
    })

  $btnH2.add_Click({
      if ($rtbBody.SelectionLength -gt 0)
      {
        $sel = $rtbBody.SelectedText
        $rtbBody.SelectedText = "`n## $sel`n"
      }
      else
      {
        $rtbBody.AppendText("`n## Section Header`n")
      }
    })

  $btnBullet.add_Click({
      if ($rtbBody.SelectionLength -gt 0)
      {
        $lines = $rtbBody.SelectedText -split "\r?\n"
        $bLines = $lines | ForEach-Object { "- $_" }
        $rtbBody.SelectedText = ($bLines -join "`n")
      }
      else
      {
        $rtbBody.AppendText("`n- Bullet point item`n")
      }
    })

  $btnLink.add_Click({
      $linkText = if ($rtbBody.SelectionLength -gt 0)
      { $rtbBody.SelectedText
      }
      else
      { 'Link Text'
      }
      $rtbBody.SelectedText = "[$linkText](https://example.gov)"
    })

  $btnClearFmt.add_Click({
      $rtbBody.Clear()
    })

  $editorPanel.Controls.Add($rtbBody)
  $editorPanel.Controls.Add($toolbar)

  $lblEditorHelp = New-Object System.Windows.Forms.Label
  $lblEditorHelp.Text = 'Shared fields save to every file with this Item ID. Program Area and SubCategory remain unchanged in each file.'
  $lblEditorHelp.Dock = 'Fill'
  $lblEditorHelp.TextAlign = 'MiddleLeft'

  $editorLayout.Controls.Add($lblItemId, 0, 0)
  $editorLayout.Controls.Add($txtItemId, 1, 0)
  $editorLayout.Controls.Add($lblTitle, 0, 1)
  $editorLayout.Controls.Add($txtTitle, 1, 1)
  $editorLayout.Controls.Add($lblPubDate, 0, 2)
  $editorLayout.Controls.Add($dtpPubDate, 1, 2)
  $editorLayout.Controls.Add($lblExpiryDate, 0, 3)
  $editorLayout.Controls.Add($dtpExpiryDate, 1, 3)
  $editorLayout.Controls.Add($lblEventType, 0, 4)
  $editorLayout.Controls.Add($cbEventType, 1, 4)
  $editorLayout.Controls.Add($lblStartDate, 0, 5)
  $editorLayout.Controls.Add($datePanel, 1, 5)
  $editorLayout.Controls.Add($lblLocations, 0, 6)
  $editorLayout.Controls.Add($txtLocations, 1, 6)
  $editorLayout.Controls.Add($editorPanel, 0, 7)
  $editorLayout.SetColumnSpan($editorPanel, 2)
  $editorLayout.Controls.Add($lblEditorHelp, 0, 8)
  $editorLayout.SetColumnSpan($lblEditorHelp, 2)

  $editorGroup.Controls.Add($editorLayout)
  $mainPanel.Controls.Add($editorGroup, 0, 2)

  $actionPanel = New-Object System.Windows.Forms.FlowLayoutPanel
  $actionPanel.Dock = 'Fill'
  $actionPanel.FlowDirection = 'RightToLeft'
  $actionPanel.Padding = New-Object System.Windows.Forms.Padding(0, 6, 0, 0)

  $btnSave = New-Object System.Windows.Forms.Button
  $btnSave.Text = 'Save Changes'
  $btnSave.Size = New-Object System.Drawing.Size(140, 36)
  $btnSave.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 180)
  $btnSave.ForeColor = [System.Drawing.Color]::White
  $btnSave.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
  $btnSave.FlatStyle = 'Flat'

  $btnCommit = New-Object System.Windows.Forms.Button
  $btnCommit.Text = 'Publish Changes'
  $btnCommit.Size = New-Object System.Drawing.Size(130, 36)
  $btnCommit.BackColor = [System.Drawing.Color]::FromArgb(34, 139, 34)
  $btnCommit.ForeColor = [System.Drawing.Color]::White
  $btnCommit.Font = New-Object System.Drawing.Font('Segoe UI', 9.0, [System.Drawing.FontStyle]::Bold)
  $btnCommit.FlatStyle = 'Flat'

  $btnClear = New-Object System.Windows.Forms.Button
  $btnClear.Text = 'Clear Selection'
  $btnClear.Size = New-Object System.Drawing.Size(120, 36)

  $btnExit = New-Object System.Windows.Forms.Button
  $btnExit.Text = 'Close'
  $btnExit.Size = New-Object System.Drawing.Size(90, 36)

  $actionPanel.Controls.Add($btnSave)
  $actionPanel.Controls.Add($btnCommit)
  $actionPanel.Controls.Add($btnClear)
  $actionPanel.Controls.Add($btnExit)
  $mainPanel.Controls.Add($actionPanel, 0, 3)

  $form.Controls.Add($mainPanel)

  $runSearch = {
    $lstResults.BeginUpdate()
    $lstResults.Items.Clear()
    $entries = Search-ProgramContentEntries -ProgramsRoot $ProgramsRoot -Query $txtSearch.Text -SearchMode $cbSearchMode.SelectedItem.ToString()
    foreach ($entry in $entries)
    {
      [void]$lstResults.Items.Add($entry)
    }
    $lstResults.EndUpdate()
  }

  $loadEntries = {
    $selectedEntries = @($lstResults.SelectedItems)
    if ($selectedEntries.Count -eq 0)
    {
      [System.Windows.Forms.MessageBox]::Show(
        'Select at least one content file from the search results.',
        'Selection Required',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
      return
    }

    $itemIds = @($selectedEntries | Select-Object -ExpandProperty ItemId -Unique)
    if ($itemIds.Count -ne 1)
    {
      [System.Windows.Forms.MessageBox]::Show(
        'All selected results must share the same Item ID.',
        'Invalid Selection',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
      return
    }

    $editorState.LoadedEntries = @(Get-ProgramContentEntriesByItemId -ProgramsRoot $ProgramsRoot -ItemId $itemIds[0])
    Write-Host "Loaded $($editorState.LoadedEntries.Count) file(s) for Item ID $($itemIds[0])."
    if ($editorState.LoadedEntries.Count -eq 0)
    {
      [System.Windows.Forms.MessageBox]::Show(
        'No files were found for the selected Item ID.',
        'Load Error',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error)
      return
    }

    $primaryEntry = $editorState.LoadedEntries[0]
    $txtItemId.Text = $primaryEntry.ItemId
    $txtTitle.Text = $primaryEntry.Title
    $txtLocations.Text = Get-ProgramContentLocationsText -Entries $editorState.LoadedEntries
    $rtbBody.Text = $primaryEntry.Body

    try { $dtpPubDate.Value = [datetime]::Parse($primaryEntry.PubDate, [System.Globalization.CultureInfo]::GetCultureInfo('en-US')) }
    catch { $dtpPubDate.Value = Get-Date }

    if (-not [string]::IsNullOrWhiteSpace($primaryEntry.ExpiryDate))
    {
      try { $dtpExpiryDate.Value = [datetime]::Parse($primaryEntry.ExpiryDate, [System.Globalization.CultureInfo]::GetCultureInfo('en-US')); $dtpExpiryDate.Checked = $true }
      catch { $dtpExpiryDate.Checked = $false }
    }
    else { $dtpExpiryDate.Checked = $false }

    if (-not [string]::IsNullOrWhiteSpace($primaryEntry.EventType))
    {
      $eventType = $primaryEntry.EventType.Trim()
      if ($eventType -notin $cbEventType.Items) { $eventType = 'Other' }
      $cbEventType.SelectedItem = $eventType
    }
    else
    {
      $cbEventType.SelectedIndex = -1
    }

    if (-not [string]::IsNullOrWhiteSpace($primaryEntry.StartDate))
    {
      try { $dtpStartDate.Value = [datetime]::Parse($primaryEntry.StartDate, [System.Globalization.CultureInfo]::GetCultureInfo('en-US')); $dtpStartDate.Checked = $true }
      catch { $dtpStartDate.Checked = $false }
    }
    else { $dtpStartDate.Checked = $false }

    if (-not [string]::IsNullOrWhiteSpace($primaryEntry.EndDate))
    {
      try { $dtpEndDate.Value = [datetime]::Parse($primaryEntry.EndDate, [System.Globalization.CultureInfo]::GetCultureInfo('en-US')); $dtpEndDate.Checked = $true }
      catch { $dtpEndDate.Checked = $false }
    }
    else { $dtpEndDate.Checked = $false }

    $form.Text = 'FedCenter - Edit Program Content: ' + $primaryEntry.ItemId
  }

  $btnSearch.add_Click($runSearch)
  $btnLoadSelection.add_Click($loadEntries)
  $txtSearch.add_KeyDown({ if ($_.KeyCode -eq 'Enter') { & $runSearch } })
  $lstResults.add_DoubleClick($loadEntries)

  $btnSave.add_Click({
      try
      {
        if ($editorState.LoadedEntries.Count -eq 0)
        {
          [System.Windows.Forms.MessageBox]::Show(
            'Load a content item before saving changes.',
            'Nothing Loaded',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
          return
        }

        $title = $txtTitle.Text.Trim()
        $bodyText = Convert-RtfToMarkdown -RichTextBox $rtbBody
        $pubDate = $dtpPubDate.Value.ToString('M/d/yyyy')
        $expiryDate = if ($dtpExpiryDate.Checked) { $dtpExpiryDate.Value.ToString('M/d/yyyy') } else { '' }
        $eventType = if ($cbEventType.SelectedIndex -ge 0) { $cbEventType.SelectedItem.ToString() } else { '' }
        $startDate = if ($dtpStartDate.Checked) { $dtpStartDate.Value.ToString('M/d/yyyy HH:mm') } else { '' }
        $endDate = if ($dtpEndDate.Checked) { $dtpEndDate.Value.ToString('M/d/yyyy HH:mm') } else { '' }

        Update-ProgramContentGroup -Entries $editorState.LoadedEntries -Title $title -PubDate $pubDate -ExpiryDate $expiryDate -EventType $eventType -StartDate $startDate -EndDate $endDate -BodyText $bodyText

        [System.Windows.Forms.MessageBox]::Show(
          "Updated $($editorState.LoadedEntries.Count) file(s) for Item ID $($txtItemId.Text).",
          'Success',
          [System.Windows.Forms.MessageBoxButtons]::OK,
          [System.Windows.Forms.MessageBoxIcon]::Information)

        & $runSearch
      }
      catch
      {
        [System.Windows.Forms.MessageBox]::Show(
          "Failed to save content changes:`n$_",
          'Save Error',
          [System.Windows.Forms.MessageBoxButtons]::OK,
          [System.Windows.Forms.MessageBoxIcon]::Error)
      }
    })

  $btnCommit.add_Click({
      try
      {
        Invoke-FedCenterContentCommitPush -StartingPath $ProgramsRoot -ParentWindow $form
      }
      catch
      {
        [System.Windows.Forms.MessageBox]::Show(
          "Commit/Push failed:`n$_",
          'Error',
          [System.Windows.Forms.MessageBoxButtons]::OK,
          [System.Windows.Forms.MessageBoxIcon]::Error)
      }
    })

  $btnClear.add_Click({
      $lstResults.ClearSelected()
      $txtSearch.Clear()
      $txtItemId.Clear()
      $txtTitle.Clear()
      $txtLocations.Clear()
      $rtbBody.Clear()
      $cbEventType.SelectedIndex = -1
      $dtpPubDate.Value = Get-Date
      $dtpExpiryDate.Checked = $false
      $dtpStartDate.Checked = $false
      $dtpEndDate.Checked = $false
      $editorState.LoadedEntries = @()
      $form.Text = 'FedCenter - Edit Program Content'
    })

  $btnExit.add_Click({ $form.Close() })

  & $runSearch
  [void]$form.ShowDialog()
}

if ($MyInvocation.InvocationName -ne '.')
{
  $programsRootPath = Get-FedCenterProgramsRoot
  if (-not $programsRootPath)
  {
    Write-Warning "Could not automatically locate 'src/content/programs' directory."
  }
  elseif (([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type)
  {
    Start-EditContentGui -ProgramsRoot $programsRootPath
  }
  else
  {
    Write-Host 'PowerShell script loaded.'
    Write-Host "Run 'Start-EditContentGui' to proceed."
  }
}