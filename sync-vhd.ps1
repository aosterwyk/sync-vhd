Param(
    [switch]$NoUpdate = $false,
    [string]$destinationDrive,
    [string]$sourceDrive
)

# TODO - explain switches and add help switch

Write-Host "This script could break a lot. The author cannot be held responsible if you break anything. Use at your own risk."

$disk2VHDUrl = "https://live.sysinternals.com/disk2vhd.exe" 

if($NoUpdate) { Write-Host "Skipping update check" }
else {
    Write-Host -ForegroundColor Cyan "Testing connection to live.sysinternals.com"
    if(Test-Connection "live.sysinternals.com" -Count 2) {
        Write-Host -ForegroundColor Green "Success!"
        if(Test-Path -Path ".\disk2vhd.exe") {
            # TODO - put this all in a try in case the download fails
            $webClient = [System.Net.WebClient]::new()
            $disk2VHDInternetHash = (Get-FileHash -InputStream ($webClient.OpenRead($disk2VHDUrl))).Hash
            Write-Host "Live version filehash: $($disk2VHDInternetHash)"
            $disk2VHDLocalHash = (Get-FileHash -Path ".\disk2vhd.exe").Hash
            Write-Host "Local version filehash: $($disk2VHDLocalHash)"

            else {
                if($disk2VHDInternetHash -eq $disk2VHDLocalHash) {
                    Write-Host "Local and live version filehases match. Skipping download."
                }
                else {
                    Write-Host -ForegroundColor Yellow "Local and live version filehases don't match. Downloading live version."
                    Write-Host -ForegroundColor Cyan "HINT: You can skip this check with -NoUpdate"
                    Write-Host "Renaming local version to disk2vhd-old.exe"
                    Rename-Item -Path ".\disk2vhd.exe" -NewName ".\disk2vhd-old.exe"
                    Write-Host "Downloading live version"                 
                    Invoke-WebRequest -Uri $disk2VHDUrl -OutFile ".\disk2vhd.exe"
                }
            }         
        }
        else {
            Write-Host "Local version not found. Downloading from live.sysinternals.com"
            Invoke-WebRequest -Uri $disk2VHDUrl -OutFile ".\disk2vhd.exe"
        }
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
$VHDFilename = "$($VHDPath)\$($env:COMPUTERNAME)-$(Get-Date -Format "yyyyMMdd-hhmmss").vhd"
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
Start-Process ".\disk2vhd.exe" -ArgumentList "/accepteula","$($sourceDrive): $($VHDFilename)" -Wait
