[CmdletBinding()]
Param(
  # Mandatory is set to false. If Set to $True then a dialog box appears to get the missing information
  # We will do a variable check later
  # https://blogs.technet.microsoft.com/heyscriptingguy/2011/05/22/use-powershell-to-make-mandatory-parameters/
  [Parameter(Mandatory = $False)]
  [String]$script
)

If ($script -and (Test-Path $script -PathType Leaf)) {
  & $script
  exit $LASTEXITCODE
} else {
  exit 0
}
