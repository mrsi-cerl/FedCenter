function Show-Menu {
  param (
    [string]$Title = 'FedCenter Content Management'
  )
  Clear-Host

  # Virtual Terminal escape sequences for bold/italics
  $boldStart = "`e[1m"
  $emStart = "`e[3m"
  $formatEnd = "`e[m"

  Write-Host "================ $Title ================" -ForegroundColor WHITE -BackgroundColor Blue

  Write-Host "You should synchronize your local repository before each content update.`n`n" -ForegroundColor YELLOW
  Write-Host "  Publishing changes to GitHub will trigger a rebuild and deploy to the Production website." -ForegroundColor Yellow

  Write-Host "$boldStart 0: Sync Repository - Do this first! $formatEnd " -ForegroundColor Green
  Write-Host " ---------------------------- "
  Write-Host " 1: Create Program Area Content"
  Write-Host " 2: Create Grants"
  Write-Host " 3: Create Partnerships"
  Write-Host " 4: Create Awards"
  Write-Host " ---------------------------- "
  Write-Host " 5: Edit Program Area Content"
  Write-Host " 6: Edit Grants"
  Write-Host " 7: Edit Partnerships"
  Write-Host " 8: Edit Awards"
  Write-Host " 9: Publish Changes to GitHub" -ForegroundColor Magenta
  Write-Host " ---------------------------- "
  Write-Host " Q: $emStart Quit $formatEnd`n" -ForegroundColor Red
}

do {
  Show-Menu -Title "FedCenter Content Management"
  $selection = Read-Host "Please make a selection"
  switch ($selection) {
    '0' {
      Write-Host "Sync Repository..." -ForegroundColor BLUE
      . "./ContentManagement/Scripts/0-Sync-Repository.ps1"
    } '1' {
      Write-Host 'Create Program Area Content...' -ForegroundColor BLUE
      Pause
      . "./ContentManagement/Scripts/1-Create-ProgramContent.ps1"
    } '2' {
      Write-Host 'Create Grants...' -ForegroundColor BLUE
      Pause
      . "./ContentManagement/Scripts/2-Create-Grant.ps1"
    } '3' {
      Write-Host 'Create Partnerships...' -ForegroundColor BLUE
      Pause
      . "./ContentManagement/Scripts/3-Create-Partnership.ps1"
    } '4' {
      Write-Host 'Create Awards...' -ForegroundColor BLUE
      Pause
      . "./ContentManagement/Scripts/4-Create-Award.ps1"
    } '5' {
      Write-Host 'Edit Program Area Content...' -ForegroundColor BLUE
      Pause
      . "./ContentManagement/Scripts/5-Edit-ProgramContent.ps1"
    } '6' {
      Write-Host 'Edit Grants...' -ForegroundColor BLUE
      Pause
      . "./ContentManagement/Scripts/6-Edit-Grant.ps1"
    } '7' {
      Write-Host 'Edit Partnerships...' -ForegroundColor BLUE
      Pause
      . "./ContentManagement/Scripts/7-Edit-Partnership.ps1"
    } '8' {
      Write-Host 'Edit Awards...' -ForegroundColor Blue
      Pause
      . "./ContentManagement/Scripts/8-Edit-Award.ps1"
    } '9' {
      Write-Host 'Publish Changes...' -ForegroundColor Blue
      Pause
      . "./ContentManagement/Scripts/8-Publish-Changes.ps1"
    }
  }
  Pause
}
until ($selection -eq 'q')
