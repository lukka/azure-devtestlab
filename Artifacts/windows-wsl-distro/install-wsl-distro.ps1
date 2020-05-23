# Install a WSL installation using one of the aka.ms/<distro-name-version> link available here:
# https://github.com/MicrosoftDocs/WSL/blob/master/WSL/install-manual.md
[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [string] $Distro = "ubuntu-1804",
    [Parameter(Mandatory = $true)]
    [string] $Username,
    [Parameter(Mandatory = $true)]
    [string] $Password
)
$ErrorActionPreference = 'Stop'
trap {
    # NOTE: This trap will handle all errors. There should be no need to use a catch below in this
    #       script, unless you want to ignore a specific error.
    $message = $Error[0].Exception.Message
    if ($message) {
        Write-Host -Object "`nERROR: $message" -ForegroundColor Red
    }

    Write-Host "`nThe artifact failed to apply.`n"

    # IMPORTANT NOTE: Throwing a terminating error (using $ErrorActionPreference = "Stop") still
    # returns exit code zero from the PowerShell script when using -File. The workaround is to
    # NOT use -File when calling this script and leverage the try-catch-finally block and return
    # a non-zero exit code from the catch block.
    exit -1
}

function InstallDistro([string]$distroName) {
    Write-Host "Creating Distro Folder for $distroName"
    $sysDrive = $env:SystemRoot.Substring(0, 3)
    $distroPath = New-Item -ItemType Directory -Force -Path $sysDrive\Distros\
    Set-Location $distroPath

    [string]$appxName = "$distroName.appx"
    [string]$zipName = "$distroName.zip"

    # Disable Invoke-WebRequest progess bar to speed up the download
    # See https://stackoverflow.com/a/43477248
    $ProgressPreference = 'SilentlyContinue'

    Write-Host "Downloading '$distroName' Distro into $distroPath/$appxName"
    Invoke-WebRequest -Uri https://aka.ms/wsl-$distroName -OutFile $appxName -UseBasicParsing

    $distroZipFilePath = (Join-Path $distroPath $zipName)
    Write-Host "Renaming .appx to $distroZipFilePath"
    Remove-Item -Force -Recurse $distroZipFilePath -ErrorAction Ignore
    Rename-Item (Join-Path $distroPath $appxName) $distroZipFilePath -Force

    $fullDistroPath = (Join-Path $distroPath $distroName)
    Write-Host "Unzipping Distro $distroName"
    Remove-Item -Force -Recurse $fullDistroPath -ErrorAction Ignore
    Expand-Archive (Join-Path $distroPath $zipName) $fullDistroPath

    # Extract any inner .appx archives
    foreach ($innerAppx in Get-ChildItem -Filter *.appx $fullDistroPath) {
        $innerAppxFullName = $innerAppx.FullName
        $innerDir = $innerAppxFullName.Replace(".appx", "\")
        $innerZip = $innerAppxFullName.Replace(".appx", ".zip")

        Rename-Item $innerAppxFullName $innerZip
        Expand-Archive $innerZip $innerDir
        Remove-Item $innerZip
    }

    Write-Host "Installing $distroName"
    # Install and initialize distro
    $installerPath = @(Get-ChildItem -Path $fullDistroPath -Filter install.tar.gz -Recurse -ErrorAction SilentlyContinue -Force | Select-Object -ExpandProperty FullName)

    if ($installerPath.Count -ne 1) {
        # Found multiple installers inside downloaded .appx archive
        $errorMessage = $multipleInstallersError + $installerPath
        throw $errorMessage
    }

    $credentials = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, (ConvertTo-SecureString $Password -AsPlainText -Force)

    [string]$elevateInstallWslScriptPath = Join-Path $PSScriptRoot install-wsl-elevated.ps1
    Write-Host "Executing as $Username the command: $elevateInstallWslScriptPath -elevated $distroName $fullDistroPath $installerPath"
    $ps = Start-Process -PassThru -FilePath powershell -Credential $credentials -ArgumentList "-File $elevateInstallWslScriptPath -elevated $distroName $fullDistroPath $installerPath"

    $ps.WaitForExit()
}

function Main {
    try {
        Push-Location
        InstallDistro $Distro
    }
    finally {
        Pop-Location
    }
}

Main
