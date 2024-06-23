param(
    [switch]$NoUpdate = $false,
    [string]$destinationDrive,
    [string]$destinationPath,
    [string]$sourceDrive,
    [switch]$help
)

# TODO - explain switches and add help switch

Write-Host "Use at your own risk. The author cannot be held responsible if you break anything."

$disk2VHDUrl = "https://live.sysinternals.com/disk2vhd.exe" 
$disk2VHD64Url = "https://live.sysinternals.com/disk2vhd64.exe" 

if($help) {
    Write-Host -ForegroundColor Yellow "HELP" 
    Write-Host -ForegroundColor Cyan "`n-NoUpdate"
    Write-Host "Disable checking for disk2vhd updates"
    Write-Host -ForegroundColor Cyan "`n-destinationDrive <drive letter>"
    Write-Host "Where to save VHD file. This will default to '<drive letter>:\VHDs'.`nYou do not need to use the destinationPath switch with option."
    Write-Host -ForegroundColor Cyan "`n-destinationPath <path>"
    Write-Host "Override default ('<drive letter>:\VHDs') path"
    Write-Host -ForegroundColor Cyan "`n-sourceDrive <drive letter>"
    Write-Host "Override default (OS, usually C) source drive"
    exit
}

function update-disk2vhd {
    param(
        [string]$exeName, 
        [string]$liveUrl
    )
    try {
        if(Test-Path -Path ".\$($exeName).exe") {        
            $webClient = [System.Net.WebClient]::new()
            $liveHash = (Get-FileHash -InputStream ($webClient.OpenRead($liveUrl))).Hash
            Write-Host "Live version filehash: $($liveHash)"
            $localHash = (Get-FileHash -Path "$($exeName).exe").Hash
            Write-Host "Local version filehash: $($localHash)"

            if($liveHash -eq $localHash) { Write-Host -ForegroundColor Green "Local and live version filehases match. Skipping download." }
            else {
                Write-Host -ForegroundColor Yellow "Local and live version filehases don't match. Downloading live version."
                Write-Host -ForegroundColor Cyan "HINT: You can skip this check with -NoUpdate"
                Write-Host "Renaming local version to disk2vhd-old.exe"
                Rename-Item -Path ".\$($exeName)" -NewName ".\$($exeName)-old.exe"
                Write-Host "Downloading live version of disk2vhd"                 
                Invoke-WebRequest -Uri $liveUrl -OutFile ".\$($exeName).exe"
            }
        }
        else {
            Write-Host "Local version of disk2vhd not found. Downloading from live.sysinternals.com"
            Invoke-WebRequest -Uri $liveUrl -OutFile ".\$($exeName).exe"
        }        
    }
    catch { Write-Host "Error updating.`n$($_.Error)" }
}

if($NoUpdate) { Write-Host "Skipping update check" }
else {
    Write-Host -ForegroundColor Cyan "Testing connection to live.sysinternals.com"
    if(Test-Connection "live.sysinternals.com" -Count 2) {
        Write-Host -ForegroundColor Green "Success!"
        # update-disk2vhd -exeName "disk2vhd" -liveUrl $disk2VHDUrl # uncomment this if you need 32-bit
        update-disk2vhd -exeName "disk2vhd64" -liveUrl $disk2VHD64Url
    }
    else {
        Write-Host -ForegroundColor Yellow "Can't connect to live.sysinternals.com. Skipping update."
    }
}

$OSVolume = (Get-CimInstance -ClassName CIM_OperatingSystem).SystemDrive
$OSDrive = $OSVolume[0] # SystemDrive returns the drive letter with a : (ex "C:") so this selects the first character 

if($sourceDrive.Length -gt 0) { 
    # TODO - Check if source drive is removable disk2vhd will not image a removable drive
    # TODO - Add support for multiple source drives
    Write-Host "Source drive set to $($sourceDrive)"
}
else {
    Write-Host "Source drive not set. Using OS Drive ($($OSDrive))"
    Write-Host -ForegroundColor Cyan "HINT: You can set the drive with -SourceDrive <drive letter>"
    $sourceDrive = $OSDrive
}

if($destinationDrive.Length -gt 0) { Write-Host "Destination drive set. Skipping drive check." }
else {
    Write-Host "`nChecking disks..."
    Write-Host -ForegroundColor Cyan "HINT: You can set the drive with -DestinationDrive <drive letter>"
    # $USBDrives = Get-Volume | Where-Object {$_.DriveType -eq "Removable"} 
    $USBDrives = Get-Volume # Filtering by "Removable" excludes larger USB drives 
    $USBDriveCount = 0
    Write-Host "Listing drives"
    foreach($drive in $USBDrives) {
        if($drive.DriveLetter -eq $OSDrive) { continue } # skip OS drive
        if($drive.DriveLetter -lt 1) { continue } # skip drives without letter
        Write-Host "$($drive.DriveLetter): $($drive.FileSystemLabel) ($([math]::round($Drive.size / 1GB, 2))GB)"
        $USBDriveCount++
    }
    if($USBDriveCount -eq 0) {
        Write-Host -ForegroundColor Red "No drives found. Exiting"
        exit
    }
    if($USBDriveCount -eq 1) { $drivePromptMessage = "Enter a destination drive letter (you probably want $($USBDrives[1].DriveLetter))" }
    else { $drivePromptMessage = "Enter a destination drive letter" }
    $destinationDrive = Read-Host $drivePromptMessage
}

# check if destination drive is OS drive
if($destinationDrive -eq $OSDrive) { 
    Write-Host -ForegroundColor Red "Destination Drive is OS Drive. Exiting."
    exit 
}

# check if destination drive letter is valid
$testDestinationDrive = Get-Volume $destinationDrive
if($null -eq $testDestinationDrive) {
    Write-Host -ForegroundColor Red "Error testing destination drive. Exiting."
    exit 
}

$VHDPath = "$($destinationDrive):\VHDs"

if($destinationPath.Length -gt 0) { 
    $VHDPath = "$($destinationDrive):\$($destinationPath)"
    Write-Host "Destination path set. Using $($VHDPath)"
}

# $VHDFilename = "$($VHDPath)\$($env:COMPUTERNAME)-$(Get-Date -Format "yyyyMMdd-hhmmss").vhdx"
$VHDFilename = "$($VHDPath)\$($env:COMPUTERNAME)-$($sourceDrive).vhdx"
Write-Host "Checking if directory ($($VHDPath)) exists"
if(Test-Path $VHDPath) { Write-Host -ForegroundColor Green "$($VHDPath) exists." }
else {
    Write-Host -ForegroundColor Yellow "$($VHDPath) does not exist. Creating directory."
    New-Item -ItemType Directory -Path $VHDPath | Out-Null
}

Write-Host "Checking if $($VHDFilename) exists"
if(Test-Path $VHDFilename) {
    $oldVHDFilename = "$($VHDPath)\$($env:COMPUTERNAME)-$($sourceDrive)-$(Get-Date -Format "yyyyMMdd-HHmmss").vhdx"
    Write-Host -ForegroundColor Yellow "File exists. Renaming to $($oldVHDFilename)"
    Rename-Item $VHDFilename -NewName $oldVHDFilename 
}
else { Write-Host "File ($($VHDFilename)) does not already exist." }

Write-Host "`nSource Drive: $($sourceDrive)"
Write-Host "VHD: $($VHDFilename)"
Write-Host "Starting disk2vhd (/accepteula","$($sourceDrive): $($VHDFilename))"
Start-Process ".\disk2vhd64.exe" -ArgumentList "/accepteula","-c $($sourceDrive): $($VHDFilename)" -Wait
Write-Host -ForegroundColor Green "Complete" 
