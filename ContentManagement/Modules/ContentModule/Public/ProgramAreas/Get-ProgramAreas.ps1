function Get-ProgramAreas {
  return $PROGRAM_AREAS.Keys | Sort-Object
}

function Get-ProgramAreasHash {
  return $PROGRAM_AREAS
}