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
    }
    elseif ($line.StartsWith("\t• ")) {
      $mdLines += "  - " + $line.Substring(4).Trim()
    }
    else {
      $mdLines += $line
    }
  }
  return ($mdLines -join "`n")
}