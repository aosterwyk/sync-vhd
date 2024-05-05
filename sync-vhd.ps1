param(
    [switch]$NoUpdate = $false,
    [string]$destinationDrive,
    [string]$sourceDrive
)

# TODO - explain switches and add help switch

Write-Host "This script could break a lot. The author cannot be held responsible if you break anything. Use at your own risk."

$disk2VHDUrl = "https://live.sysinternals.com/disk2vhd.exe" 
$disk2VHD64Url = "https://live.sysinternals.com/disk2vhd64.exe" 

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

            if($liveHash -eq $localHash) {
                Write-Host "Local and live version filehases match. Skipping download."
            }
            else {
                Write-Host -ForegroundColor Yellow "Local and live version filehases don't match. Downloading live version."
                Write-Host -ForegroundColor Cyan "HINT: You can skip this check with -NoUpdate"
                Write-Host "Renaming local version to disk2vhd-old.exe"
                Rename-Item -Path ".\$($exeName)" -NewName ".\$($exeName)-old.exe"
                Write-Host "Downloading live version"                 
                Invoke-WebRequest -Uri $liveUrl -OutFile ".\$($exeName).exe"
            }
        }
        else {
            Write-Host "Local version not found. Downloading from live.sysinternals.com"
            Invoke-WebRequest -Uri $liveUrl -OutFile ".\$($exeName).exe"
        }        
    }
    catch {
        Write-Host "Error updating.`n$($_.Error)"
    }
}

if($NoUpdate) { Write-Host "Skipping update check" }
else {
    Write-Host -ForegroundColor Cyan "Testing connection to live.sysinternals.com"
    if(Test-Connection "live.sysinternals.com" -Count 2) {
        Write-Host -ForegroundColor Green "Success!"
        # update-disk2vhd -exeName "disk2vhd" -liveUrl $disk2VHDUrl
        update-disk2vhd -exeName "disk2vhd64" -liveUrl $disk2VHD64Url
    }
    else {
        Write-Host -ForegroundColor Yellow "Can't connect to live.sysinternals.com. Skipping update."
    }
}

# TODO - Check if drive parm is set
if($destinationDrive.Length -gt 0) { Write-Host "Destination drive set. Skipping drive check." }
else {
    Write-Host "`nChecking disks..."
    Write-Host -ForegroundColor Cyan "HINT: You can set the drive with -DestinationDrive <drive letter>"
    $USBDrives = Get-Volume | Where-Object {$_.DriveType -eq "Removable"} 
    $USBDriveCount = 0
    Write-Host "Listing USB drives"
    foreach($drive in $USBDrives) {
        Write-Host "$($drive.DriveLetter): $($drive.FileSystemLabel) ($([math]::round($Drive.size / 1GB, 2))GB)"
        $USBDriveCount++
    }
    if($USBDriveCount -eq 1) { $drivePromptMessage = "Enter a destination drive letter (you probably want $($USBDrives[0].DriveLetter))" }
    else { $drivePromptMessage = "Enter a destination drive letter" }
    $destinationDrive = Read-Host $drivePromptMessage
}

$OSVolume = (Get-CimInstance -ClassName CIM_OperatingSystem).SystemDrive
if($destinationDrive -eq ($OSVolume[0])) { #SystemDrive returns the drive letter with a : (ex "C:") so this selects the first character 
    Write-Host -ForegroundColor Red "Destination Drive is OS Drive. Exiting."
    exit 
}

if((Get-Volume $destinationDrive).DriveType -eq "Fixed") {
    Write-Host -ForegroundColor Red "`n`nDrive $($destinationDrive) is a fixed drive. This could be a bad idea."
    $fixedDriveConfirm = Read-Host "Are you sure you want to do this? (Y/N)"
    if($fixedDriveConfirm -eq "N") { 
        Write-Host "Exiting."
        exit
    }
}

#TODO - get source drive, default to OS drive. if source drive is removable disk2vhd won't image it. add switch to loop all fixed drives. 
#TODO - check if VHDs exist on destination drive. add switch to use machine name without timestamp for filename and any name conflicts. 

$VHDPath = "$($destinationDrive):\VHDs"
$VHDFilename = "$($VHDPath)\$($env:COMPUTERNAME)-$(Get-Date -Format "yyyyMMdd-hhmmss").vhdx"
Write-Host "Checking if VHD path ($($VHDPath)) exists"
if(Test-Path $VHDPath) { Write-Host -ForegroundColor Green "$($VHDPath) exists." }
else {
    Write-Host -ForegroundColor Yellow "$($VHDPath) does not exist. Creating directory."
    New-Item -ItemType Directory -Path $VHDPath | Out-Null
}

Write-Host "Source Drive: $($sourceDrive)"
Write-Host "VHD: $($VHDFilename)"
Write-Host "Starting disk2vhd"
Write-Host "/accepteula","$($sourceDrive): $($VHDFilename)"
Start-Process ".\disk2vhd64.exe" -ArgumentList "/accepteula","-c $($sourceDrive): $($VHDFilename)" -Wait
