function Get-UniqueProgramContentFilePath {
  param (
    [string]$DirectoryPath,
    [string]$Title
  )

  $fileName = New-SanitizedFilename -Title $Title
  $candidatePath = Join-Path $DirectoryPath $fileName
  if (-not (Test-Path -LiteralPath $candidatePath)) {
    return $candidatePath
  }

  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
  $extension = [System.IO.Path]::GetExtension($fileName)

  for ($suffix = 1; $suffix -le 99; $suffix++) {
    $candidateName = '{0}{1:D2}{2}' -f $baseName, $suffix, $extension
    $candidatePath = Join-Path $DirectoryPath $candidateName
    if (-not (Test-Path -LiteralPath $candidatePath)) {
      return $candidatePath
    }
  }

  throw "Could not generate a unique filename for title '$Title' in '$DirectoryPath'."
}
