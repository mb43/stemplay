#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Performs unattended Windows 10 to Windows 11 upgrade
.DESCRIPTION
    Checks if system is already Windows 11, validates prerequisites, removes registry blocks,
    copies ISO from network share to local disk, and performs silent upgrade with logging.
    Skips upgrade if system is already running Windows 11.
.PARAMETER LogPath
    Path to log file. Default: C:\Windows\Temp\Win11Upgrade.log
.PARAMETER LocalISOPath
    Local path where ISO will be copied. Default: C:\Temp\Win11.iso
.PARAMETER NetworkISOPath
    Network share path to Windows 11 ISO. Default: \\your-server\deployment\Windows11_23H2_x64.iso
.PARAMETER SkipPrereqCheck
    Skip system requirements validation (not recommended)
.PARAMETER KeepInstallFiles
    Keep local ISO file after upgrade starts
.EXAMPLE
    .\Win11Upgrade.ps1
.EXAMPLE
    .\Win11Upgrade.ps1 -NetworkISOPath "\\fileserver\IT\Win11.iso" -KeepInstallFiles
.NOTES
    Version: 2.0
    Requires Administrator privileges
    System will reboot multiple times during upgrade
#>

[CmdletBinding()]
param (
    [string]$LogPath = "C:\Windows\Temp\Win11Upgrade.log",
    [string]$LocalISOPath = "C:\Temp\Win11.iso",
    [string]$NetworkISOPath = "\\your-server\deployment\Windows11_23H2_x64.iso",
    [switch]$SkipPrereqCheck,
    [switch]$KeepInstallFiles
)

#region Functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    Add-Content -Path $LogPath -Value $logMessage
    Write-Host $logMessage
}

function Test-IsElevated {
    $id = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object System.Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-IsWindows11 {
    try {
        $os = Get-CimInstance Win32_OperatingSystem
        $osName = $os.Caption
        $buildNumber = $os.BuildNumber
        
        Write-Log "Current OS: $osName (Build $buildNumber)"
        
        # Windows 11 starts at build 22000
        if ([int]$buildNumber -ge 22000) {
            Write-Log "System is already running Windows 11." -Level "INFO"
            return $true
        }
        
        Write-Log "System is running Windows 10 (Build $buildNumber)." -Level "INFO"
        return $false
    } catch {
        Write-Log "Failed to determine Windows version: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Test-DiskSpace {
    param([int]$RequiredGB = 25)
    $systemDrive = $env:SystemDrive
    $drive = Get-PSDrive -Name $systemDrive.TrimEnd(':')
    $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
    Write-Log "Available disk space on $systemDrive : $freeSpaceGB GB"
    return $freeSpaceGB -ge $RequiredGB
}

function Test-TPM {
    try {
        $tpm = Get-WmiObject -Namespace "root\cimv2\Security\MicrosoftTpm" -Class Win32_Tpm -ErrorAction Stop
        if ($tpm.IsEnabled().IsEnabled -and $tpm.IsActivated().IsActivated) {
            $specVersion = $tpm.SpecVersion
            Write-Log "TPM is enabled and activated. Spec Version: $specVersion"
            return $specVersion -match "2.0"
        }
    } catch {
        Write-Log "TPM check failed: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
    return $false
}

function Test-SecureBoot {
    try {
        $secureBoot = Confirm-SecureBootUEFI -ErrorAction Stop
        Write-Log "Secure Boot status: $secureBoot"
        return $secureBoot
    } catch {
        Write-Log "Secure Boot check failed (may not be UEFI system): $($_.Exception.Message)" -Level "WARN"
        return $false
    }
}

function Test-SystemRequirements {
    Write-Log "Checking system requirements..."
    
    # RAM check
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)
    Write-Log "Total RAM: $ram GB"
    if ($ram -lt 4) {
        Write-Log "Insufficient RAM. Minimum 4GB required." -Level "ERROR"
        return $false
    }
    
    # Disk space check
    if (-not (Test-DiskSpace -RequiredGB 25)) {
        Write-Log "Insufficient disk space. Minimum 25GB free required." -Level "ERROR"
        return $false
    }
    
    # TPM check
    if (-not (Test-TPM)) {
        Write-Log "TPM 2.0 not available or not enabled." -Level "ERROR"
        return $false
    }
    
    # Secure Boot check (warning only, not blocking)
    if (-not (Test-SecureBoot)) {
        Write-Log "Secure Boot is not enabled. This may cause issues." -Level "WARN"
    }
    
    Write-Log "All system requirements met." -Level "SUCCESS"
    return $true
}

function Remove-RegistryBlocks {
    Write-Log "Removing registry blocks..."
    
    try {
        # Remove Target Release Version locks
        $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        if (Test-Path $regPath) {
            Remove-ItemProperty -Path $regPath -Name "TargetReleaseVersion" -Force -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regPath -Name "TargetReleaseVersionInfo" -Force -ErrorAction SilentlyContinue
        }
        
        # Remove upgrade offer declined flag
        $uxPath = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings"
        if (Test-Path $uxPath) {
            Remove-ItemProperty -Path $uxPath -Name "SvOfferDeclined" -Force -ErrorAction SilentlyContinue
        }
        
        Write-Log "Registry blocks removed successfully." -Level "SUCCESS"
        return $true
    } catch {
        Write-Log "Failed to remove registry blocks: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Get-Windows11ISO {
    param([string]$Destination = $ISOPath)
    
    Write-Log "Downloading Windows 11 installation media..."
    
    try {
        # Use Windows Media Creation Tool approach or direct ISO download
        # For production, you should host the ISO on an internal server/share
        
        $mediaCreationToolUrl = "https://go.microsoft.com/fwlink/?linkid=2156295"
        $mctPath = "C:\Windows\Temp\MediaCreationTool.exe"
        
        Write-Log "Downloading Media Creation Tool..."
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $mediaCreationToolUrl -OutFile $mctPath -UseBasicParsing
        
        Write-Log "Media Creation Tool downloaded. Creating ISO..."
        # Note: For fully automated scenario, consider using pre-downloaded ISO from network share
        
        return $true
    } catch {
        Write-Log "Failed to download installation media: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Copy-ISOToLocal {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )
    
    Write-Log "Checking for local ISO copy..."
    
    try {
        # Ensure C:\Temp exists
        $destFolder = Split-Path -Path $DestinationPath -Parent
        if (-not (Test-Path $destFolder)) {
            Write-Log "Creating directory: $destFolder"
            New-Item -Path $destFolder -ItemType Directory -Force | Out-Null
        }
        
        # Check if ISO already exists locally
        if (Test-Path $DestinationPath) {
            $localSize = (Get-Item $DestinationPath).Length
            Write-Log "Local ISO found. Size: $([math]::Round($localSize / 1GB, 2)) GB"
            
            # Verify source exists and compare sizes
            if (Test-Path $SourcePath) {
                $sourceSize = (Get-Item $SourcePath).Length
                if ($localSize -eq $sourceSize) {
                    Write-Log "Local ISO matches network source. Skipping copy." -Level "SUCCESS"
                    return $true
                } else {
                    Write-Log "Local ISO size mismatch. Will re-copy from network." -Level "WARN"
                    Remove-Item -Path $DestinationPath -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Log "Network source not accessible. Using existing local ISO." -Level "WARN"
                return $true
            }
        }
        
        # Verify network source exists
        if (-not (Test-Path $SourcePath)) {
            Write-Log "Network ISO source not found: $SourcePath" -Level "ERROR"
            return $false
        }
        
        # Get source file size for progress tracking
        $sourceFile = Get-Item $SourcePath
        $sourceSizeGB = [math]::Round($sourceFile.Length / 1GB, 2)
        Write-Log "Copying ISO from network share to local disk..."
        Write-Log "Source: $SourcePath ($sourceSizeGB GB)"
        Write-Log "Destination: $DestinationPath"
        Write-Log "This may take several minutes depending on network speed..."
        
        # Copy with progress
        $startTime = Get-Date
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force -ErrorAction Stop
        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        
        # Verify copy
        if (Test-Path $DestinationPath) {
            $copiedSize = (Get-Item $DestinationPath).Length
            $copiedSizeGB = [math]::Round($copiedSize / 1GB, 2)
            
            if ($copiedSize -eq $sourceFile.Length) {
                Write-Log "ISO copied successfully. Size: $copiedSizeGB GB. Time: $([math]::Round($duration, 1)) seconds" -Level "SUCCESS"
                return $true
            } else {
                Write-Log "ISO copy size mismatch. Expected: $sourceSizeGB GB, Got: $copiedSizeGB GB" -Level "ERROR"
                return $false
            }
        } else {
            Write-Log "ISO copy failed. File not found at destination." -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to copy ISO: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Mount-ISOAndGetSetupPath {
    param([string]$ISOPath)
    
    try {
        Write-Log "Mounting ISO: $ISOPath"
        $mountResult = Mount-DiskImage -ImagePath $ISOPath -PassThru
        $driveLetter = ($mountResult | Get-Volume).DriveLetter
        $setupPath = "$($driveLetter):\setup.exe"
        
        if (Test-Path $setupPath) {
            Write-Log "ISO mounted successfully. Setup path: $setupPath" -Level "SUCCESS"
            return $setupPath
        } else {
            Write-Log "Setup.exe not found in mounted ISO." -Level "ERROR"
            return $null
        }
    } catch {
        Write-Log "Failed to mount ISO: $($_.Exception.Message)" -Level "ERROR"
        return $null
    }
}

function Start-Windows11Upgrade {
    param([string]$SetupPath)
    
    Write-Log "Starting Windows 11 upgrade..."
    
    try {
        # Setup parameters for unattended upgrade
        $arguments = @(
            "/auto", "upgrade",
            "/quiet",
            "/showoobe", "none",
            "/DynamicUpdate", "enable",
            "/Compat", "IgnoreWarning",
            "/migratedrivers", "all",
            "/telemetry", "disable"
        )
        
        Write-Log "Executing: $SetupPath $($arguments -join ' ')"
        
        $process = Start-Process -FilePath $SetupPath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-Log "Windows 11 upgrade initiated successfully." -Level "SUCCESS"
            return $true
        } else {
            Write-Log "Setup exited with code: $($process.ExitCode)" -Level "ERROR"
            return $false
        }
    } catch {
        Write-Log "Failed to start upgrade: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}
#endregion

#region Main Script
try {
    Write-Log "===== Windows 11 Upgrade Script Started =====" -Level "INFO"
    Write-Log "Computer Name: $env:COMPUTERNAME"
    Write-Log "Current OS: $((Get-CimInstance Win32_OperatingSystem).Caption)"
    
    # Check admin privileges
    if (-not (Test-IsElevated)) {
        Write-Log "Script must be run as Administrator." -Level "ERROR"
        exit 1
    }
    
    # Check if already Windows 11
    if (Test-IsWindows11) {
        Write-Log "System is already running Windows 11. No upgrade needed." -Level "SUCCESS"
        Write-Log "Exiting script."
        exit 0
    }
    
    # Check system requirements
    if (-not $SkipPrereqCheck) {
        if (-not (Test-SystemRequirements)) {
            Write-Log "System does not meet Windows 11 requirements." -Level "ERROR"
            exit 2
        }
    } else {
        Write-Log "Skipping prerequisite checks as requested." -Level "WARN"
    }
    
    # Remove registry blocks
    if (-not (Remove-RegistryBlocks)) {
        Write-Log "Failed to remove registry blocks." -Level "ERROR"
        exit 3
    }
    
    # Copy ISO from network share to local disk
    Write-Log "Preparing installation media..."
    if (-not (Copy-ISOToLocal -SourcePath $NetworkISOPath -DestinationPath $LocalISOPath)) {
        Write-Log "Failed to copy ISO to local disk." -Level "ERROR"
        exit 4
    }
    
    # Mount ISO and get setup path
    $setupPath = Mount-ISOAndGetSetupPath -ISOPath $LocalISOPath
    if (-not $setupPath) {
        Write-Log "Failed to mount ISO or locate setup.exe" -Level "ERROR"
        exit 5
    }
    
    # Start upgrade
    if (Start-Windows11Upgrade -SetupPath $setupPath) {
        Write-Log "Windows 11 upgrade process started successfully." -Level "SUCCESS"
        Write-Log "System will reboot multiple times during upgrade." -Level "INFO"
        exit 0
    } else {
        Write-Log "Failed to start Windows 11 upgrade." -Level "ERROR"
        exit 6
    }
    
} catch {
    Write-Log "Unexpected error: $($_.Exception.Message)" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 99
} finally {
    Write-Log "===== Windows 11 Upgrade Script Completed =====" -Level "INFO"
    
    # Cleanup mounted ISO if needed
    if ($LocalISOPath -and (Test-Path $LocalISOPath)) {
        try {
            Dismount-DiskImage -ImagePath $LocalISOPath -ErrorAction SilentlyContinue
        } catch {}
    }
    
    # Optionally cleanup local ISO after upgrade starts
    if (-not $KeepInstallFiles -and (Test-Path $LocalISOPath)) {
        Write-Log "Cleaning up local ISO file..."
        try {
            Remove-Item -Path $LocalISOPath -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Log "Could not remove local ISO: $($_.Exception.Message)" -Level "WARN"
        }
    }
}
#endregion
