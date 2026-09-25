# ==============================================================================
# Script: Create-ProgramContent.ps1
# Description: PowerShell GUI tool for creating program content Markdown files
#              in src/content/programs with dynamic category and subcategory selection,
#              rich text editing, and automated frontmatter generation.
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

# Dynamically locate the module relative to the running script
$ModulePath = "$PSScriptRoot\..\Modules\ContentModule\ContentModule.psm1"

# Import the shared functions
Import-Module $ModulePath -Force

# ------------------------------------------------------------------------------
# GUI Construction (Windows Forms)
# ------------------------------------------------------------------------------

function Start-ProgramContentGui {
  param (
    [string]$ProgramsRoot
  )

  [System.Windows.Forms.Application]::EnableVisualStyles()

  # TODO: consider checking git status and notify if not up-to-date

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
  foreach ($pa in $programAreas) {
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
      Write-Host "Selected Program Area: " $selectedPA
      $lstSubCategories.Items.Clear()
      if (-not [string]::IsNullOrWhiteSpace($selectedPA)) {
        $availableSubs = Get-SubCategoriesForProgram -ProgramArea $selectedPA
        foreach ($sub in $availableSubs) {
          [void]$lstSubCategories.Items.Add($sub, $false)
        }
      }
    })

  $btnSubSelectAll.add_Click({
      for ($i = 0; $i -lt $lstSubCategories.Items.Count; $i++) {
        $lstSubCategories.SetItemChecked($i, $true)
      }
    })

  $btnSubClearAll.add_Click({
      for ($i = 0; $i -lt $lstSubCategories.Items.Count; $i++) {
        $lstSubCategories.SetItemChecked($i, $false)
      }
    })

  # 4. Details & Content Editor Group Box (Spans Row 2 across both columns)
  $grpContent = New-Object System.Windows.Forms.GroupBox
  $grpContent.Text = "3. Entry Details \& Content"
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
  $lblPublishDate = New-Object System.Windows.Forms.Label
  $lblPublishDate.Text = "Pub Date:"
  $lblPublishDate.Anchor = "Left"
  $dtpPublishDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpPublishDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Short
  $dtpPublishDate.Dock = "Fill"

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
  $dtpStartDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
  $dtpStartDate.CustomFormat = "M/d/yyyy HH:mm"
  $dtpStartDate.ShowCheckBox = $true
  $dtpStartDate.Checked = $false
  $dtpStartDate.Dock = "Fill"

  # End Date (optional)
  $lblEndDate = New-Object System.Windows.Forms.Label
  $lblEndDate.Text = "End Date:"
  $lblEndDate.Anchor = "Left"
  $dtpEndDate = New-Object System.Windows.Forms.DateTimePicker
  $dtpEndDate.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
  $dtpEndDate.CustomFormat = "M/d/yyyy HH:mm"
  $dtpEndDate.ShowCheckBox = $true
  $dtpEndDate.Checked = $false
  $dtpEndDate.Dock = "Fill"

  $contentContainer.Controls.Add($lblPublishDate, 0, 2)
  $contentContainer.Controls.Add($dtpPublishDate, 1, 2)
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

      try {
        # Verify required fields have data before continuing
        # Program Area
        $selectedPA = $lstPrograms.SelectedItem
        if ([string]::IsNullOrWhiteSpace($selectedPA)) {
          [System.Windows.Forms.MessageBox]::Show("Please select a Program Area.", "Validation Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
          return
        }

        # Sub-Categories
        if ($lstSubCategories.CheckedItems.Count -le 0) {
          [System.Windows.Forms.MessageBox]::Show("Please select sub-categories.", "Validation Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
          $lstSubCategories.Focus()
          return
        }

        $selectedSubs = @()
        foreach ($sub in $lstSubCategories.CheckedItems) {
          $selectedSubs += $sub.ToString()
        }

        # Title
        $title = $txtTitle.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($title)) {
          [System.Windows.Forms.MessageBox]::Show("Please enter a Title.", "Validation Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
          $txtTitle.Focus()
          return
        }

        # Body Content
        $text = $rtbContent.Text.Trim()
        if ([string]::IsNullOrWhiteSpace($text)) {
          [System.Windows.Forms.MessageBox]::Show("Please enter body content.", "Validation Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
          $rtbContent.Focus()
          return
        }

        # Get the rest of the data and save it
        $bodyText = Convert-RtfToMarkdown -RichTextBox $rtbContent
        # Publication date (required)
        $publishDate = $dtpPublishDate.Value.ToString("M/d/yyyy")
        # Optional eventType
        $eventType = if ($cbEventType.SelectedIndex -ge 0) { $cbEventType.SelectedItem.ToString() } else { "" }
        # Optional dates
        $startDate = if ($dtpStartDate.Checked) { $dtpStartDate.Value.ToString("M/d/yyyy HH:mm") } else { "" }
        $endDate = if ($dtpEndDate.Checked) { $dtpEndDate.Value.ToString("M/d/yyyy HH:mm") } else { "" }
        $expiryDate = if ($dtpExpiryDate.Checked) { $dtpExpiryDate.Value.ToString("M/d/yyyy") } else { "" }

        $savedFiles = Save-ProgramContent -ProgramsRoot $ProgramsRoot -SelectedPrograms @($selectedPA) -SelectedSubCategories $selectedSubs -Title $title -BodyText $bodyText -ItemId $txtItemId.Text.Trim() -PublishDate $publishDate -EventType $eventType -StartDate $startDate -EndDate $endDate -ExpiryDate $expiryDate

        $msg = "Successfully saved markdown file:`n`n" + ($savedFiles -join "`n")
        [System.Windows.Forms.MessageBox]::Show($msg, "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

        # Set content READ-ONLY to ensure they don't change between program area selections
        $grpContent.Enabled = $false

      }
      catch {
        [System.Windows.Forms.MessageBox]::Show("Error saving markdown file: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
      }
    })

  $btnClear.add_Click({
      $txtTitle.Clear()
      $rtbContent.Clear()
      $lstPrograms.ClearSelected()
      $lstSubCategories.Items.Clear()
      $cbEventType.SelectedIndex = -1
      $dtpPublishDate.Value = Get-Date
      $dtpStartDate.Checked = $false
      $dtpEndDate.Checked = $false
      $dtpExpiryDate.Checked = $false
      $form.Text = "FedCenter - Create Program Content"
      $currentItemId = if ($txtItemId.Text.Trim() -as [int]) {
        (([int]$txtItemId.Text.Trim()) + 1).ToString()
      }
      else {
        Get-NextUniqueItemId -ProgramsRoot $ProgramsRoot
      }
      $txtItemId.Text = $currentItemId

      # enable content inputs for new item
      $grpContent.Enabled = $true
    })

  $btnCommit.add_Click({
      try {
        Invoke-FedCenterContentCommitPush -StartingPath $ProgramsRoot -ParentWindow $form
      }
      catch {
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

# #### Fire it up

$programsRootPath = Get-ContentRoot "Programs"
if (-not $programsRootPath) {
  Write-Warning "Could not automatically locate 'src/content/programs' directory."
}
else {
  Write-Host "Found FedCenter programs root at: $programsRootPath"
}

if (([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type) {
  Start-ProgramContentGui -ProgramsRoot $programsRootPath
}
else {
  Write-Host "PowerShell script loaded."
  Write-Host "Run 'Start-ProgramContentGui' or 'Save-ProgramContent' to proceed."
}