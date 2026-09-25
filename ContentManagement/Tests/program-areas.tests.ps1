BeforeAll {
  # Dynamically locate the module relative to the running script
  $ModulePath = "$PSScriptRoot\..\Modules\ContentModule\ContentModule.psm1"

  # Import the shared functions
  Import-Module $ModulePath -Force
}

Describe 'Program Area' {
  It 'Verifies the # of Program Areas' {
    $pa = Get-ProgramAreas
    $paKeys = $pa.Keys
    $paKeys.Count | Should -Be 18
  }
}

Describe  'PFAS Sub-Categories' {
  It 'Verifies # of PFAS sub-categories' {
    $sc = Get-SubCategoriesForProgram "PFAS"
    $sc.Count | Should -Be 8
  }
}

