# Dynamically locate the module relative to the running script
$ModulePath = "$PSScriptRoot\..\Modules\ContentModule\ContentModule.psm1"

# Import the shared functions
Import-Module $ModulePath -Force