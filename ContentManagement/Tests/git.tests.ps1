BeforeAll {
  # Dynamically locate the module relative to the running script
  $ModulePath = "$PSScriptRoot\..\Modules\ContentModule\ContentModule.psm1"

  # Import the shared functions
  Import-Module $ModulePath -Force
}

Describe 'Git' {
  It 'Local Git repository is found' {
    $repoRoot = Get-RepoRoot
    $repoRoot | Should -Not -Be $null
  }

  It 'FedCenter Program Area Folder is Found' {
    $programsRootPath = Get-FedCenterProgramsRoot
    $programsRootPath | Should -Not -Be $null
  }
}
