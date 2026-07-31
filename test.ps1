
# ==============================================================================
# Script: New-ProgramContent.ps1
# Description: PowerShell GUI tool for creating program content Markdown files
#              in src/content/programs with dynamic category and subcategory selection,
#              rich text editing, and automated frontmatter generation.
# ==============================================================================

# Ensure Windows Forms assemblies are available when running in GUI mode
try {
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop } catch {
    Write-Verbose "WinForms assemblies unavailable in current environment."
}

# ------------------------------------------------------------------------------
# Core Helper Functions
# ------------------------------------------------------------------------------

function Get-FedCenterProgramsRoot {
    param (
        [string]$StartingPath = $PSScriptRoot
    )
    if ([string]::IsNullOrWhiteSpace($StartingPath)) {
        $StartingPath = Get-Location
    }

    # Search upwards or locally for src/content/programs
    $current = $StartingPath
    while ($null -ne $current -and (Test-Path $current)) {
        $candidate = Join-Path $current "src/content/programs"
        if (Test-Path $candidate -PathType Container) {
            return (Resolve-Path $candidate).Path
        }
        $parent = Split-Path $current -Parent
        if ($parent -eq $current) { break }
        $current = $parent
    }

    # Fallback to current directory check
    if (Test-Path "src/content/programs" -PathType Container) {
        return (Resolve-Path "src/content/programs").Path
    }

    return $null
}

function Get-ProgramAreas {
    param (
        [string]$ProgramsRoot
    )
    if (-not $ProgramsRoot -or -not (Test-Path $ProgramsRoot)) {
        return @()
    }
    $dirs = Get-ChildItem -Path $ProgramsRoot -Directory | Select-Object -ExpandProperty Name | Sort-Object
    return $dirs
}

function Get-SubCategoriesForPrograms {
    param (
        [string]$ProgramsRoot,
        [string[]]$ProgramAreas
    )
    if (-not $ProgramsRoot -or -not (Test-Path $ProgramsRoot) -or $null -eq $ProgramAreas -or $ProgramAreas.Count -eq 0) {
        return @()
    }

    $subCategories = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($pa in $ProgramAreas) {
        $paPath = Join-Path $ProgramsRoot $pa
        if (Test-Path $paPath) {
            $mdFiles = Get-ChildItem -Path $paPath -Filter "*.md" -File
            foreach ($file in $mdFiles) {
                try {
                    $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
                    if ($content -match "^---\s*[\r\n]+([\s\S]*?)[\r\n]+---") {
                        $yamlBlock = $matches[1]
                        $lines = $yamlBlock -split "[\r\n]+"
                        $inSubCat = $false
                        foreach ($line in $lines) {
                            $trimmed = $line.Trim()
                            if ($trimmed -like "subCategory:*") {
                                $inSubCat = $true
                                continue
                            }
                            if ($inSubCat) {
                                if ($trimmed.StartsWith("-")) {
                                    $sc = $trimmed.Substring(1).Trim().Trim('"').Trim("'")
                                    if (-not [string]::IsNullOrWhiteSpace($sc)) {
                                        [void]$subCategories.Add($sc)
                                    }
                                } elseif ($trimmed -match "^\w+:") {
                                    $inSubCat = $false
                                }
                            }
                        }
                    }
                } catch {
                    # Continue reading remaining files if one fails
                }
            }
        }
    }

    $result = [string[]]($subCategories | Sort-Object)
    return $result
}

function New-SanitizedFilename {
    param (
        [string]$Title
    )
    if ([string]::IsNullOrWhiteSpace($Title)) {
        return "Untitled.md"
    }
    # Remove invalid path characters: \ / : * ? " < > |
    $clean = $Title -replace '[\\/*?:"<>|]', ''
    $clean = $clean.Trim()
    if ([string]::IsNullOrWhiteSpace($clean)) {
        $clean = "Untitled"
    }
    return "$clean.md"
}

function Format-MarkdownFrontmatter {
    param (
        [string]$ItemId,
        [string]$ProgramArea,
        [string]$PubDate,
        [string[]]$SubCategories,
        [string]$Title,
        [string]$Body
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("item_id: '$ItemId'")
    [void]$sb.AppendLine("programArea: $ProgramArea")
    [void]$sb.AppendLine("pubDate: $PubDate")
    [void]$sb.AppendLine("subCategory:")

    if ($null -ne $SubCategories -and $SubCategories.Count -gt 0) {
        foreach ($sc in $SubCategories) {
            if (-not [string]::IsNullOrWhiteSpace($sc)) {
                [void]$sb.AppendLine("- $sc")
            }
        }
    } else {
        [void]$sb.AppendLine("- General")
    }

    # Format title cleanly
    if ($Title -match "[:'#]") {
        $escapedTitle = $Title -replace "'", "''"
        [void]$sb.AppendLine("title: '$escapedTitle'")
    } else {
        [void]$sb.AppendLine("title: $Title")
    }

    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine($Body.Trim())

    return $sb.ToString()
}

function Convert-RtfToMarkdown {
    param (
        [System.Windows.Forms.RichTextBox]$RichTextBox
    )
    if ($null -eq $RichTextBox -or [string]::IsNullOrWhiteSpace($RichTextBox.Text)) {
        return ""
    }

    # If simple text without rich formatting, return cleaned lines
    $text = $RichTextBox.Text

    # Convert bullets if any
    $lines = $text -split "\r?\n"
    $mdLines = @()
    foreach ($line in $lines) {
        if ($line.StartsWith("•\t") -or $line.StartsWith("• ")) {
            $mdLines += "- " + $line.Substring(2).Trim()
        } elseif ($line.StartsWith("\t• ")) {
            $mdLines += "  - " + $line.Substring(4).Trim()
        } else {
            $mdLines += $line
        }
    }
    return ($mdLines -join "`n")
}

function Get-NextUniqueItemId {
    param (
        [string]$ProgramsRoot
    )
    $maxId = 44000
    if ($ProgramsRoot -and (Test-Path $ProgramsRoot)) {
        $mdFiles = Get-ChildItem -Path $ProgramsRoot -Filter "*.md" -Recurse -File
        foreach ($file in $mdFiles) {
            try {
                $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
                if ($content -match "item_id:\s*['""]?(\d+)['""]?") {
                    $val = [int]$matches[1]
                    if ($val -gt $maxId) {
                        $maxId = $val
                    }
                }
            } catch {}
        }
    }
    return ($maxId + 1).ToString()
}

function Save-ProgramContent {
    param (
        [string]$ProgramsRoot,
        [string[]]$SelectedPrograms,
        [string[]]$SelectedSubCategories,
        [string]$Title,
        [string]$BodyText,
        [string]$ItemId,
        [string]$PubDate
    )

    if (-not (Test-Path $ProgramsRoot)) {
        throw "Programs root directory not found at '$ProgramsRoot'"
    }
    if ($null -eq $SelectedPrograms -or $SelectedPrograms.Count -eq 0) {
        throw "At least one Program Area must be selected."
    }
    if ([string]::IsNullOrWhiteSpace($Title)) {
        throw "Title cannot be empty."
    }

    if ([string]::IsNullOrWhiteSpace($ItemId)) {
        $ItemId = Get-NextUniqueItemId -ProgramsRoot $ProgramsRoot
    }
    if ([string]::IsNullOrWhiteSpace($PubDate)) {
        $PubDate = (Get-Date).ToString("M/d/yyyy")
    }

    $fileName = New-SanitizedFilename -Title $Title
    $createdFiles = @()

    foreach ($pa in $SelectedPrograms) {
        $paDir = Join-Path $ProgramsRoot $pa
        if (-not (Test-Path $paDir)) {
            New-Item -Path $paDir -ItemType Directory -Force | Out-Null
        }

        $filePath = Join-Path $paDir $fileName
        $mdContent = Format-MarkdownFrontmatter -ItemId $ItemId -ProgramArea $pa -PubDate $PubDate -SubCategories $SelectedSubCategories -Title $Title -Body $BodyText

        # Write UTF-8 without BOM or standard UTF8
        [System.IO.File]::WriteAllText($filePath, $mdContent, [System.Text.Encoding]::UTF8)
        $createdFiles += $filePath
    }

    return [string[]]$createdFiles
}

# ------------------------------------------------------------------------------
# GUI Construction (Windows Forms)
# ------------------------------------------------------------------------------

function Start-ProgramContentGui {
    param (
        [string]$ProgramsRoot
    )

    if (-not (([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type)) {
        Write-Error "Windows Forms is not supported or loaded in this environment."
        return
    }

    [System.Windows.Forms.Application]::EnableVisualStyles()

    # Form Setup
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "FedCenter - Create Program Content"
    $form.Size = New-Object System.Drawing.Size(950, 750)
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
        $lstSubCategories.Items.Clear()
        if (-not [string]::IsNullOrWhiteSpace($selectedPA)) {
            $availableSubs = Get-SubCategoriesForPrograms -ProgramsRoot $ProgramsRoot -ProgramAreas @($selectedPA)
            foreach ($sub in $availableSubs) {
                [void]$lstSubCategories.Items.Add($sub, $false)
            }
        }
    })

    $btnSubSelectAll.add_Click({
        for ($i=0; $i -lt $lstSubCategories.Items.Count; $i++) {
            $lstSubCategories.SetItemChecked($i, $true)
        }
    })

    $btnSubClearAll.add_Click({
        for ($i=0; $i -lt $lstSubCategories.Items.Count; $i++) {
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
    $contentContainer.RowCount = 3
    $contentContainer.ColumnCount = 2

    [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
    [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Absolute, 35)))
    [void]$contentContainer.RowStyles.Add((New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    [void]$contentContainer.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Absolute, 80)))
    [void]$contentContainer.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100)))

    # Title Input
    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "Title:"
    $lblTitle.Anchor = "Left"
    $txtTitle = New-Object System.Windows.Forms.TextBox
    $txtTitle.Dock = "Fill"
    $txtTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10.0)

    $contentContainer.Controls.Add($lblTitle, 0, 0)
    $contentContainer.Controls.Add($txtTitle, 1, 0)

    # Publication Date Input
    $lblPubDate = New-Object System.Windows.Forms.Label
    $lblPubDate.Text = "Pub Date:"
    $lblPubDate.Anchor = "Left"
    $txtPubDate = New-Object System.Windows.Forms.TextBox
    $txtPubDate.Dock = "Fill"
    $txtPubDate.Text = (Get-Date).ToString("M/d/yyyy")
    $txtPubDate.Font = New-Object System.Drawing.Font("Segoe UI", 9.5)

    $contentContainer.Controls.Add($lblPubDate, 0, 1)
    $contentContainer.Controls.Add($txtPubDate, 1, 1)

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
    $btnBullet.Text = "• Bullet List"
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
        } else {
            $rtbContent.AppendText("**bold text**")
        }
    })

    $btnItalic.add_Click({
        if ($rtbContent.SelectionLength -gt 0) {
            $sel = $rtbContent.SelectedText
            $rtbContent.SelectedText = "*$sel*"
        } else {
            $rtbContent.AppendText("*italic text*")
        }
    })

    $btnH2.add_Click({
        if ($rtbContent.SelectionLength -gt 0) {
            $sel = $rtbContent.SelectedText
            $rtbContent.SelectedText = "`n## $sel`n"
        } else {
            $rtbContent.AppendText("`n## Section Header`n")
        }
    })

    $btnBullet.add_Click({
        if ($rtbContent.SelectionLength -gt 0) {
            $lines = $rtbContent.SelectedText -split "\r?\n"
            $bLines = $lines | ForEach-Object { "- $_" }
            $rtbContent.SelectedText = ($bLines -join "`n")
        } else {
            $rtbContent.AppendText("`n- Bullet point item`n")
        }
    })

    $btnLink.add_Click({
        $linkText = if ($rtbContent.SelectionLength -gt 0) { $rtbContent.SelectedText } else { "Link Text" }
        $rtbContent.SelectedText = "[$linkText](https://example.gov)"
    })

    $btnClearFmt.add_Click({
        $rtbContent.Clear()
    })

    $editorPanel.Controls.Add($rtbContent)
    $editorPanel.Controls.Add($toolbar)

    $contentContainer.Controls.Add($editorPanel, 0, 2)
    $contentContainer.SetColumnSpan($editorPanel, 4)

    $grpContent.Controls.Add($contentContainer)
    $mainPanel.Controls.Add($grpContent, 0, 2)
    $mainPanel.SetColumnSpan($grpContent, 2)

    # 5. Bottom Action Bar (Row 3)
    $actionPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    $actionPanel.Dock = "Fill"
    $actionPanel.FlowDirection = "RightToLeft"
    $actionPanel.Padding = New-Object System.Windows.Forms.Padding(0, 5, 0, 0)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = "Save Markdown"
    $btnSave.Size = New-Object System.Drawing.Size(140, 36)
    $btnSave.BackColor = [System.Drawing.Color]::FromArgb(30, 100, 180)
    $btnSave.ForeColor = [System.Drawing.Color]::White
    $btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Bold)
    $btnSave.FlatStyle = "Flat"

    $btnClear = New-Object System.Windows.Forms.Button
    $btnClear.Text = "Clear Form"
    $btnClear.Size = New-Object System.Drawing.Size(100, 36)
    $btnClear.Font = New-Object System.Drawing.Font("Segoe UI", 9.0)

    $btnExit = New-Object System.Windows.Forms.Button
    $btnExit.Text = "Close"
    $btnExit.Size = New-Object System.Drawing.Size(90, 36)
    $btnExit.Font = New-Object System.Drawing.Font("Segoe UI", 9.0)

    $actionPanel.Controls.Add($btnSave)
    $actionPanel.Controls.Add($btnClear)
    $actionPanel.Controls.Add($btnExit)

    $mainPanel.Controls.Add($actionPanel, 0, 3)
    $mainPanel.SetColumnSpan($actionPanel, 2)

    $form.Controls.Add($mainPanel)

    # Form Button Event Handlers
    $btnSave.add_Click({
        try {
            $selectedPA = $lstPrograms.SelectedItem
            if ([string]::IsNullOrWhiteSpace($selectedPA)) {
                [System.Windows.Forms.MessageBox]::Show("Please select a Program Area.", "Validation Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                return
            }

            $title = $txtTitle.Text.Trim()
            if ([string]::IsNullOrWhiteSpace($title)) {
                [System.Windows.Forms.MessageBox]::Show("Please enter a Title.", "Validation Warning", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
                $txtTitle.Focus()
                return
            }

            $selectedSubs = @()
            foreach ($sub in $lstSubCategories.CheckedItems) {
                $selectedSubs += $sub.ToString()
            }

            $bodyText = Convert-RtfToMarkdown -RichTextBox $rtbContent
            $pubDate = $txtPubDate.Text.Trim()

            # Item ID is automatically generated as a unique ID in Save-ProgramContent
            $savedFiles = Save-ProgramContent -ProgramsRoot $ProgramsRoot -SelectedPrograms @($selectedPA) -SelectedSubCategories $selectedSubs -Title $title -BodyText $bodyText -ItemId "" -PubDate $pubDate

            $msg = "Successfully saved markdown file:`n`n" + ($savedFiles -join "`n")
            [System.Windows.Forms.MessageBox]::Show($msg, "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)

        } catch {
            [System.Windows.Forms.MessageBox]::Show("Error saving markdown file: $_", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        }
    })

    $btnClear.add_Click({
        $txtTitle.Clear()
        $rtbContent.Clear()
        $lstPrograms.ClearSelected()
        $lstSubCategories.Items.Clear()
        $txtPubDate.Text = (Get-Date).ToString("M/d/yyyy")
    })

    $btnExit.add_Click({
        $form.Close()
    })

    # Show Modal Dialog
    [void]$form.ShowDialog()
}

# ------------------------------------------------------------------------------
# Entry Point Execution
# ------------------------------------------------------------------------------

if ($MyInvocation.InvocationName -ne '.') {
    $programsRootPath = Get-FedCenterProgramsRoot
    if (-not $programsRootPath) {
        Write-Warning "Could not automatically locate 'src/content/programs' directory."
    } else {
        Write-Host "Found FedCenter programs root at: $programsRootPath"
    }

    if (([System.Management.Automation.PSTypeName]'System.Windows.Forms.Form').Type) {
        Start-ProgramContentGui -ProgramsRoot $programsRootPath
    } else {
        Write-Host "PowerShell script loaded."
        Write-Host "Run 'Start-ProgramContentGui' or 'Save-ProgramContent' to proceed."
    }
}