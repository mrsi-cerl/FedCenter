function Get-SubCategoriesForProgram {
  param (
    [string]$ProgramArea
  )
  if ($null -eq $ProgramArea) {
    return @()
  }

  # Write-Host "Getting sub-categories for program area: " $ProgramArea
  $subCategories = $PROGRAM_AREAS[$ProgramArea]

  return $subCategories
}