function New-ProgramAreaTreeView {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$ProgramAreas
  )

  # 1. Create and Configure the TreeView
  $treeView = New-Object System.Windows.Forms.TreeView
  $treeView.Location = New-Object System.Drawing.Point(15, 45)
  $treeView.Size = New-Object System.Drawing.Size(370, 300)
  $treeView.CheckBoxes = $true
  $treeView.DrawMode = "OwnerDrawAll"

  # 2. Dynamically populate the TreeView from the Hashtable
  foreach ($key in $ProgramAreas.Keys | Sort-Object) {
    $parentNode = New-Object System.Windows.Forms.TreeNode($key)
    foreach ($item in $ProgramAreas[$key]) {
      [void]$parentNode.Nodes.Add($item)
    }
    [void]$treeView.Nodes.Add($parentNode)
  }

  $treeView.ExpandAll()

  # 3. Custom Rendering: Draw +/- indicators and hide checkboxes on Parents
  $treeView.Add_DrawNode({
      param($source, $e)

      # Level 0 = Parent Nodes
      if ($e.Node.Level -eq 0) {
        # Fill background to erase the default checkbox
        $backBrush = New-Object System.Drawing.SolidBrush($e.Node.TreeView.BackColor)
        $e.Graphics.FillRectangle($backBrush, $e.Bounds)

        # Standard hyphen rendering
        $glyph = if ($e.Node.IsExpanded) { "-" } else { "+" }

        $glyphFont = New-Object System.Drawing.Font("Courier New", 10, [System.Drawing.FontStyle]::Bold)
        $textFont = if ($e.Node.IsSelected) { New-Object System.Drawing.Font($e.Node.TreeView.Font, [System.Drawing.FontStyle]::Bold) } else { $e.Node.TreeView.Font }

        $glyphBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::DimGray)
        $textBrush = New-Object System.Drawing.SolidBrush($e.Node.TreeView.ForeColor)

        # Position elements carefully inside the row bounds
        $glyphLocation = New-Object System.Drawing.PointF(($e.Bounds.X + 4), ($e.Bounds.Y + 2))
        $textLocation = New-Object System.Drawing.PointF(($e.Bounds.X + 22), ($e.Bounds.Y + 2))

        # Render characters
        $e.Graphics.DrawString($glyph, $glyphFont, $glyphBrush, $glyphLocation)
        $e.Graphics.DrawString($e.Node.Text, $textFont, $textBrush, $textLocation)
      }
      else {
        # Level 1+ = Child Nodes behave exactly as default
        $e.DrawDefault = $true
      }
    })

  # Prevent checking top-level rows
  $treeView.Add_BeforeCheck({
      param($source, $e)
      if ($e.Node.Level -eq 0) {
        $e.Cancel = $true
      }
    })

  # --- ANTI-BOUNCE SELECTION ENGINE ---
  # Script-scoped flag gate to track when an expand action is legally requested
  $script:allowToggle = $false

  # Intercept ALL automatic parent toggles and block them by default
  $treeView.Add_BeforeExpand({
      param($source, $e)
      if ($e.Node.Level -eq 0 -and -not $script:allowToggle) {
        $e.Cancel = $true
      }
    })
  $treeView.Add_BeforeCollapse({
      param($source, $e)
      if ($e.Node.Level -eq 0 -and -not $script:allowToggle) {
        $e.Cancel = $true
      }
    })

  # Only unlock the gate when the user clicks EXACTLY on the first 25 pixels of a parent row
  $treeView.Add_NodeMouseClick({
      param($source, $e)
      if ($e.Node.Level -eq 0) {
        # If click is on the left-most icon area (0 to 25 pixels wide)
        if ($e.X -le 25) {
          $script:allowToggle = $true  # Unlock the gate
          if ($e.Node.IsExpanded) {
            $e.Node.Collapse()
          }
          else {
            $e.Node.Expand()
          }
          $script:allowToggle = $false # Lock it right back up
        }
      }
    })

  return $treeView
}

# Initializes the tree from a given hashtable
# The hashtable should have string keys (Areas) and string array values (Subcategories)
function Initialize-FromHashtable($treeView, [hashtable] $Data) {
  $treeView.Nodes.Clear()

  foreach ($area in $Data.Keys) {
    # Create the top-level node for the area
    $areaNode = New-Object System.Windows.Forms.TreeNode($area)

    # Add subcategory nodes under the area node
    foreach ($subcategory in $Data[$area]) {
      $subcategoryNode = New-Object System.Windows.Forms.TreeNode($subcategory)
      $areaNode.Nodes.Add($subcategoryNode) | Out-Null
    }

    $treeView.Nodes.Add($areaNode) | Out-Null
  }
}

# Sets the checked state for one or more subcategories within a specific area
# To check all subcategories in an area, use "*" for the subcategory name
function Set-CheckedState($TreeView, [string] $AreaName, [string] $SubcategoryName, [bool] $IsChecked) {
  $areaNode = $TreeView.Nodes | Where-Object { $_.Text -eq $AreaName }

  if ($areaNode) {
    $targetNodes = if ($SubcategoryName -eq '*') {
      $areaNode.Nodes
    }
    else {
      $areaNode.Nodes | Where-Object { $_.Text -eq $SubcategoryName }
    }

    foreach ($node in $targetNodes) {
      $node.Checked = $IsChecked
      $node.Expand()
      $node.EnsureVisible()
    }
  }
  else {
    Write-Warning "Area '$AreaName' not found."
  }
}

# Returns an object of all checked subcategories, grouped by area
function Get-CheckedSubcategories($treeView) {
  $checkedItems = @{}

  foreach ($areaNode in $treeView.Nodes) {
    $checkedSubcategories = @()
    foreach ($subcategoryNode in $areaNode.Nodes) {
      if ($subcategoryNode.Checked) {
        $checkedSubcategories += $subcategoryNode.Text
      }
    }

    if ($checkedSubcategories.Count -gt 0) {
      $checkedItems[$areaNode.Text] = $checkedSubcategories
    }
  }

  return $checkedItems
}
