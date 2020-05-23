param(
  [switch]$elevated,
  [string]$distroName,
  [string]$distroPath,
  [string]$installPath
  )

function Check-Admin {
  $currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
  $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if ((Check-Admin) -eq $false)  {
  if ($elevated)
  {
    Write-Error "could not elevate, quitting"
  } else {
    Write-Host "starting ($myinvocation.MyCommand.Definition) elevated..."
    Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
  }
exit
}

Write-Host "starting: wsl --import $distroName $distroPath $installPath"
&"wsl" --import $distroName $distroPath $installPath
