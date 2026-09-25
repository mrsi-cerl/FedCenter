BeforeAll {
  # Dynamically locate the module relative to the running script
  $ModulePath = "$PSScriptRoot\..\Modules\ContentModule\ContentModule.psm1"

  # Import the shared functions
  Import-Module $ModulePath -Force
}

Describe 'File' {
  It 'Sanitizes a title for use as a filename' {
    # Removes invalid path characters: \ / : * ? " < > |
    $invalidCharacters = '[\\/*?:"<>|]'
    $fn = New-SanitizedFilename "<Title>Test | slug:name?"
    $found = $fn -notmatch $invalidCharacters
    $found | Should -Be $true
  }
}
