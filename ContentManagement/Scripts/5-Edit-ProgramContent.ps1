# ==============================================================================
# Script: Edit-ProgramContent.ps1
# Description: PowerShell GUI tool for locating and editing existing program
#              content Markdown files by item_id or title.
# ==============================================================================

# Ensure Windows Forms assemblies are available when running in GUI mode
try {
  Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
  Add-Type -AssemblyName System.Drawing -ErrorAction Stop
}
catch {
  Write-Verbose "WinForms assemblies unavailable in current environment."
  exit
}

# Create a shorter alias for MessageBox
$MsgBox = [System.Windows.Forms.MessageBox]

# Dynamically locate the module relative to the running script
$ModulePath = "$PSScriptRoot\..\Modules\ContentModule\ContentModule.psm1"

# Import the shared functions
Import-Module $ModulePath -Force

# So we can parse YAML easily
Install-Module -Name powershell-yaml -Scope CurrentUser

# ------------------------------------------------------------------------------
# GUI Construction (Windows Forms)
# ------------------------------------------------------------------------------

function Start-EditContentGui {
  param (
    [string]$ProgramsRoot
  )

  [System.Windows.Forms.Application]::EnableVisualStyles()

  Write-Host "Starting FedCenter Program Content Editor"

  $editorState = [pscustomobject]@{
    SelectedEntry = {}
  }

  $form = New-Object System.Windows.Forms.Form
  $form.Text = 'FedCenter - Edit Program Content'
  $form.Size = New-Object System.Drawing.Size(1100, 1000)
  $form.MinimumSize = New-Object System.Drawing.Size(1000, 800)
  $form.StartPosition = 'CenterScreen'
  $form.BackColor = [System.Drawing.Color]::FromArgb(245, 247, 250)
  $form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

  $mainPanel = New-Object System.Windows.Forms.TableLayoutPanel
  $mainPanel.Dock = 'Fill'
  $mainPanel.Padding = New-Object System.Windows.Forms.Padding(12)
  $mainPanel.RowCount = 4
  $mainPanel.ColumnCount = 2

  # Row styles
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 48)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 250)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 370)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))
  [void]$mainPanel.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 58)))

  # Column styles: 40% left, 60% right
  [void]$mainPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 40)))
  [void]$mainPanel.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 60)))

  $headerLabel = New-Object System.Windows.Forms.Label
  $headerLabel.Text = 'Program Content Editor'
  $headerLabel.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
  $headerLabel.ForeColor = [System.Drawing.Color]::FromArgb(24, 43, 73)
  $headerLabel.AutoSize = $true
  $headerLabel.Anchor = 'Left'
  $mainPanel.Controls.Add($headerLabel, 0, 0)
  $mainPanel.SetColumnSpan($headerLabel, 2)

  # Top Group - Search Panel
  $searchGroup = New-Object System.Windows.Forms.GroupBox
  $searchGroup.Text = '1. Search and Select Content Files'
  $searchGroup.Dock = 'Fill'
  $searchGroup.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)

  $searchLayout = New-Object System.Windows.Forms.TableLayoutPanel
  $searchLayout.Dock = 'Fill'
  $searchLayout.RowCount = 3
  $searchLayout.ColumnCount = 5
  [void]$searchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90)))
  [void]$searchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 150)))
  [void]$searchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))
  [void]$searchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
  [void]$searchLayout.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 90)))
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

  $btnSearch = New-Object System.Windows.Forms.Button
  $btnSearch.Text = 'Search'
  $btnSearch.Size = New-Object System.Drawing.Size(80, 28)

  $btnLoadSelection = New-Object System.Windows.Forms.Button
  $btnLoadSelection.Text = 'Load Selection'
  $btnLoadSelection.Size = New-Object System.Drawing.Size(120, 28)

  $lstResults = New-Object System.Windows.Forms.ListBox
  $lstResults.Dock = 'Fill'
  $lstResults.SelectionMode = 'One'
  $lstResults.DisplayMember = 'Display'
  $lstResults.Font = New-Object System.Drawing.Font('Consolas', 9.0)

  $lblSearchHelp = New-Object System.Windows.Forms.Label
  $lblSearchHelp.Text = 'Select an item to edit. If multiple files share the same Item ID, all will be updated with the same shared field values.'
  $lblSearchHelp.Dock = 'Fill'
  $lblSearchHelp.TextAlign = 'MiddleLeft'

  $searchLayout.Controls.Add($lblSearchBy, 0, 0)
  $searchLayout.Controls.Add($cbSearchMode, 1, 0)
  $searchLayout.Controls.Add($txtSearch, 2, 0)
  $searchLayout.Controls.Add($btnSearch, 3, 0)
  $searchLayout.Controls.Add($btnLoadSelection, 4, 0)
  $searchLayout.Controls.Add($lstResults, 0, 1)
  $searchLayout.SetColumnSpan($lstResults, 5)
  $searchLayout.Controls.Add($lblSearchHelp, 0, 2)
  $searchLayout.SetColumnSpan($lblSearchHelp, 5)
  $searchGroup.Controls.Add($searchLayout)
  $mainPanel.Controls.Add($searchGroup, 0, 1)
  $mainPanel.SetColumnSpan($searchGroup, 2)

  # #### Info Group ####
  $grpPrograms = New-Object System.Windows.Forms.GroupBox
  $grpPrograms.Text = '2. Edit Programs and Fields'
  $grpPrograms.Dock = 'Fill'
  $grpPrograms.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
  $programAreas = Get-ProgramAreasHash
  $treeView = New-ProgramAreaTreeView -ProgramAreas $programAreas
  $grpPrograms.Controls.Add($treeView)
  $mainPanel.Controls.Add($grpPrograms, 0, 2)

  $grpContent = New-Object System.Windows.Forms.GroupBox
  $grpContent.Text = "Entry Details"
  $grpContent.Dock = "Fill"
  $grpContent.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)

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

  $lblPublishDate = New-Object System.Windows.Forms.Label
  $lblPublishDate.Text = 'Publish Date:'
  $lblPublishDate.Anchor = 'Left'
  $dtpPublishDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpPublishDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
  $dtpPublishDate.Dock = 'Fill'

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
  $txtLocations.AcceptsReturn = $true
  $txtLocations.WordWrap = $true
  $txtLocations.ScrollBars = 'Vertical'
  $txtLocations.Font = New-Object System.Drawing.Font('Consolas', 9.0)

  $editorLayout.Controls.Add($lblItemId, 0, 0)
  $editorLayout.Controls.Add($txtItemId, 1, 0)
  $editorLayout.Controls.Add($lblTitle, 0, 1)
  $editorLayout.Controls.Add($txtTitle, 1, 1)
  $editorLayout.Controls.Add($lblPublishDate, 0, 2)
  $editorLayout.Controls.Add($dtpPublishDate, 1, 2)
  $editorLayout.Controls.Add($lblExpiryDate, 0, 3)
  $editorLayout.Controls.Add($dtpExpiryDate, 1, 3)
  $editorLayout.Controls.Add($lblEventType, 0, 4)
  $editorLayout.Controls.Add($cbEventType, 1, 4)
  $editorLayout.Controls.Add($lblStartDate, 0, 5)
  $editorLayout.Controls.Add($datePanel, 1, 5)
  $editorLayout.Controls.Add($lblLocations, 0, 6)
  $editorLayout.Controls.Add($txtLocations, 1, 6)

  $grpContent.Controls.Add($editorLayout)
  $mainPanel.Controls.Add($grpContent, 1, 2)

  # 4. Body Content Editor
  $grpBody = New-Object System.Windows.Forms.GroupBox
  $grpBody.Text = "3. Item Body Content"
  $grpBody.Dock = "Fill"
  $grpBody.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)

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
      if ($rtbContent.SelectionLength -gt 0) {
        $sel = $rtbContent.SelectedText
        $rtbContent.SelectedText = "**$sel**"
      }
      else {
        $rtbContent.AppendText("**bold text**")
      }
    })

  $btnItalic.add_Click({
      if ($rtbContent.SelectionLength -gt 0) {
        $sel = $rtbContent.SelectedText
        $rtbContent.SelectedText = "*$sel*"
      }
      else {
        $rtbContent.AppendText("*italic text*")
      }
    })

  $btnH2.add_Click({
      if ($rtbContent.SelectionLength -gt 0) {
        $sel = $rtbContent.SelectedText
        $rtbContent.SelectedText = "`n## $sel`n"
      }
      else {
        $rtbContent.AppendText("`n## Section Header`n")
      }
    })

  $btnBullet.add_Click({
      if ($rtbContent.SelectionLength -gt 0) {
        $lines = $rtbContent.SelectedText -split "\r?\n"
        $bLines = $lines | ForEach-Object { "- $_" }
        $rtbContent.SelectedText = ($bLines -join "`n")
      }
      else {
        $rtbContent.AppendText("`n- Bullet point item`n")
      }
    })

  $btnLink.add_Click({
      $linkText = if ($rtbContent.SelectionLength -gt 0) {
        $rtbContent.SelectedText
      }
      else {
        "Link Text"
      }
      $rtbContent.SelectedText = "[$linkText](https://example.gov)"
    })

  $btnClearFmt.add_Click({
      $rtbContent.Clear()
    })

  $editorPanel.Controls.Add($rtbContent)
  $editorPanel.Controls.Add($toolbar)

  $grpBody.Controls.Add($editorPanel)
  $mainPanel.Controls.Add($grpBody, 0, 3)
  $mainPanel.SetColumnSpan($grpBody, 2)

  # ################## Button Panel
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

  $btnExit = New-Object System.Windows.Forms.Button
  $btnExit.Text = 'Close'
  $btnExit.Size = New-Object System.Drawing.Size(90, 36)

  $actionPanel.Controls.Add($btnSave)
  $actionPanel.Controls.Add($btnExit)
  $mainPanel.Controls.Add($actionPanel, 0, 4)
  $mainPanel.SetColumnSpan($actionPanel, 2)

  $form.Controls.Add($mainPanel)

  $runSearch = {
    $lstResults.BeginUpdate()
    $lstResults.Items.Clear()
    $entries = Search-ProgramContentEntries -ProgramsRoot $ProgramsRoot -Query $txtSearch.Text -SearchMode $cbSearchMode.SelectedItem.ToString()
    foreach ($entry in $entries) {
      [void]$lstResults.Items.Add($entry)
    }
    $lstResults.EndUpdate()
  }

  $loadEntries = {
    $selectedEntry = $lstResults.SelectedItems
    $editorState.SelectedEntry = $selectedEntry

    Write-Host "Selected Entry: " $selectedEntry

    if ($selectedEntry.Count -ne 1) {
      $MsgBox::Show(
        'Select one content file from the search results.',
        'Selection Required',
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
      return
    }

    $txtItemId.Text = $selectedEntry.ItemId
    $txtTitle.Text = $selectedEntry.Title
    $rtbContent.Text = $selectedEntry.Body

    # Set Program Areas from the file
    $pa = $selectedEntry.ProgramAreas
    $paQuickView = ""
    for ($i = 0; $i -lt $pa.Count; $i++) {
      foreach ($entry in $pa[$i].GetEnumerator()) {
        $paQuickView += "Area: $($entry.Key)`r`n"
        Write-Host "Key: $($entry.Key)" -ForegroundColor Cyan
        $cats = $entry.Value
        foreach ($cat in $cats) {
          $paQuickView += "  - $($cat)`r`n"
          Write-Host "  - " $cat -ForegroundColor DarkCyan
          Set-CheckedState -TreeView $treeView -AreaName $entry.Key -SubcategoryName $cat -IsChecked $true
        }
      }
    }
    $txtLocations.Text = $paQuickView

    try { $dtpPublishDate.Value = [datetime]::Parse($selectedEntry.PublishDate, [System.Globalization.CultureInfo]::GetCultureInfo('en-US')) }
    catch { $dtpPublishDate.Value = Get-Date }

    if (-not [string]::IsNullOrWhiteSpace($selectedEntry.ExpiryDate)) {
      try { $dtpExpiryDate.Value = [datetime]::Parse($selectedEntry.ExpiryDate, [System.Globalization.CultureInfo]::GetCultureInfo('en-US')); $dtpExpiryDate.Checked = $true }
      catch { $dtpExpiryDate.Checked = $false }
    }
    else { $dtpExpiryDate.Checked = $false }

    if (-not [string]::IsNullOrWhiteSpace($selectedEntry.EventType)) {
      $eventType = $selectedEntry.EventType.Trim()
      if ($eventType -notin $cbEventType.Items) { $eventType = 'Other' }
      $cbEventType.SelectedItem = $eventType
    }
    else {
      $cbEventType.SelectedIndex = -1
    }

    if (-not [string]::IsNullOrWhiteSpace($selectedEntry.StartDate)) {
      try { $dtpStartDate.Value = [datetime]::Parse($selectedEntry.StartDate, [System.Globalization.CultureInfo]::GetCultureInfo('en-US')); $dtpStartDate.Checked = $true }
      catch { $dtpStartDate.Checked = $false }
    }
    else { $dtpStartDate.Checked = $false }

    if (-not [string]::IsNullOrWhiteSpace($selectedEntry.EndDate)) {
      try { $dtpEndDate.Value = [datetime]::Parse($selectedEntry.EndDate, [System.Globalization.CultureInfo]::GetCultureInfo('en-US')); $dtpEndDate.Checked = $true }
      catch { $dtpEndDate.Checked = $false }
    }
    else { $dtpEndDate.Checked = $false }
  }

  $btnSearch.add_Click($runSearch)
  $txtSearch.add_KeyDown({ if ($_.KeyCode -eq 'Enter') { & $runSearch } })

  # Loads the selected item
  $btnLoadSelection.add_Click($loadEntries)
  $lstResults.add_DoubleClick($loadEntries)

  $btnSave.add_Click({
      try {
        if ($null -eq $editorState.SelectedEntry) {
          $MsgBox::Show(
            'Load a content item before saving changes.',
            'Nothing Loaded',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
          return
        }

        $title = $txtTitle.Text.Trim()
        $bodyText = Convert-RtfToMarkdown -RichTextBox $rtbContent
        $publishDate = $dtpPublishDate.Value.ToString('M/d/yyyy')
        $expiryDate = if ($dtpExpiryDate.Checked) { $dtpExpiryDate.Value.ToString('M/d/yyyy') } else { '' }
        $eventType = if ($cbEventType.SelectedIndex -ge 0) { $cbEventType.SelectedItem.ToString() } else { '' }
        $startDate = if ($dtpStartDate.Checked) { $dtpStartDate.Value.ToString('M/d/yyyy HH:mm') } else { '' }
        $endDate = if ($dtpEndDate.Checked) { $dtpEndDate.Value.ToString('M/d/yyyy HH:mm') } else { '' }

        # TODO: Add changes to program areas and subcategories
        $programAreas = Get-CheckedSubcategories($treeView)
        Update-ProgramContentGroup -Entry $editorState.SelectedEntry -Title $title -ProgramAreas $programAreas -PublishDate $publishDate -ExpiryDate $expiryDate -EventType $eventType -StartDate $startDate -EndDate $endDate -BodyText $bodyText

        $MsgBox::Show(
          "Updated $($loadEntries.selectedEntry) file(s) for Item ID $($title).",
          'Success',
          [System.Windows.Forms.MessageBoxButtons]::OK,
          [System.Windows.Forms.MessageBoxIcon]::Information)

        & $runSearch
      }
      catch {
        $MsgBox::Show(
          "Failed to save content changes:`n$_",
          'Save Error',
          [System.Windows.Forms.MessageBoxButtons]::OK,
          [System.Windows.Forms.MessageBoxIcon]::Error)
      }
    })

  $btnExit.add_Click({ $form.Close() })

  # Load up all entries... I don't think this is necessary
  # & $runSearch

  [void]$form.ShowDialog()
}

# Fire it up

$programsRootPath = Get-ContentRoot "Programs"
if (-not $programsRootPath) {
  Write-Warning "Could not automatically locate 'src/content/programs' directory."
}
elseif (([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type) {
  Start-EditContentGui -ProgramsRoot $programsRootPath
}
else {
  Write-Host 'PowerShell script loaded.'
  Write-Host "Run 'Start-EditContentGui' to proceed."
}