# Clear the console window
Clear-Host
# Create a string of 4 spaces
$Spaces = [string]::new(' ', 4)
# Define the script version
$ScriptVersion = "1.0"
# Get the directory from which the script is being executed
$scriptDirectory = $PSScriptRoot
# Define the location of the script file
$ScriptFile = Join-Path -Path $scriptDirectory -ChildPath $MyInvocation.MyCommand.Name
# Define the variable to store date and time information for creation and last modification
$Created = (Get-ItemProperty -Path $ScriptFile -Name CreationTime).CreationTime.ToString("dd/MM/yyyy")
# Get the parent directory of the script's directory
$parentPath = Split-Path -Parent $scriptDirectory
# Define the logging function Directory
$loggingFunctionsDirectory = Join-Path -Path $parentPath -ChildPath "Logging_Function"
# Construct the path to the Logging_Functions.ps1 script
$loggingFunctionsPath = Join-Path -Path $loggingFunctionsDirectory -ChildPath "Logging_Functions.ps1"
# Script Header main script
$HeaderMainScript = @"
Author : CHARCHOUF Sabri
Description : This script create Networks in HPE OneView using the HPE OneView PowerShell Library.
Created : $Created
Last Modified : $((Get-Item $PSCommandPath).LastWriteTime.ToString("dd/MM/yyyy"))
"@
# Display the header information in the console with a design
$consoleWidth = $Host.UI.RawUI.WindowSize.Width
$line = "─" * ($consoleWidth - 2)
Write-Host "+$line+" -ForegroundColor DarkGray
# Split the header into lines and display each part in different colors
$HeaderMainScript -split "`n" | ForEach-Object {
    $parts = $_ -split ": ", 2
    Write-Host "`t" -NoNewline
    Write-Host $parts[0] -NoNewline -ForegroundColor DarkGray
    Write-Host ": " -NoNewline
    Write-Host $parts[1] -ForegroundColor Cyan
}
Write-Host "+$line+" -ForegroundColor DarkGray
# Check if the Logging_Functions.ps1 script exists
if (Test-Path -Path $loggingFunctionsPath) {
    # Dot-source the Logging_Functions.ps1 script
    . $loggingFunctionsPath
    # Write a message to the console indicating that the logging functions have been loaded
    Write-Host "`t• " -NoNewline -ForegroundColor White
    Write-Host "Logging functions have been loaded." -ForegroundColor Green
}
else {
    # Write an error message to the console indicating that the logging functions script could not be found
    Write-Host "`t• " -NoNewline -ForegroundColor White
    Write-Host "The logging functions script could not be found at: $loggingFunctionsPath" -ForegroundColor Red
    # Stop the script execution
    exit
}
# Initialize task counter
$script:taskNumber = 1
# Define the function to import required modules if they are not already imported
function Import-ModulesIfNotExists {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$ModuleNames
    )
    # Start logging
    Start-Log -ScriptVersion $ScriptVersion -ScriptPath $PSCommandPath
    # Task 1: Checking required modules
    Write-Host "`n$Spaces$($taskNumber). Checking required modules:`n" -ForegroundColor Magenta
    # Log the task
    Write-Log -Message "Checking required modules." -Level "Info" -NoConsoleOutput
    # Increment $script:taskNumber after the function call
    $script:taskNumber++
    # Total number of modules to check
    $totalModules = $ModuleNames.Count
    # Initialize the current module counter
    $currentModuleNumber = 0
    foreach ($ModuleName in $ModuleNames) {
        $currentModuleNumber++
        # Simple text output for checking required modules
        Write-Host "`t• " -NoNewline -ForegroundColor White
        Write-Host "Checking module " -NoNewline -ForegroundColor DarkGray
        Write-Host "$currentModuleNumber" -NoNewline -ForegroundColor White
        Write-Host " of " -NoNewline -ForegroundColor DarkGray
        Write-Host "${totalModules}" -NoNewline -ForegroundColor Cyan
        Write-Host ": $ModuleName" -ForegroundColor White
        try {
            # Check if the module is installed
            if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
                Write-Host "`t• " -NoNewline -ForegroundColor White
                Write-Host "Module " -NoNewline -ForegroundColor White
                Write-Host "$ModuleName" -NoNewline -ForegroundColor Red
                Write-Host " is not installed." -ForegroundColor White
                Write-Log -Message "Module '$ModuleName' is not installed." -Level "Error" -NoConsoleOutput
                continue
            }
            # Check if the module is already imported
            if (Get-Module -Name $ModuleName) {
                Write-Host "`t• " -NoNewline -ForegroundColor White
                Write-Host "Module " -NoNewline -ForegroundColor DarkGray
                Write-Host "$ModuleName" -NoNewline -ForegroundColor Yellow
                Write-Host " is already imported." -ForegroundColor DarkGray
                Write-Log -Message "Module '$ModuleName' is already imported." -Level "Info" -NoConsoleOutput
                continue
            }
            # Try to import the module
            Import-Module $ModuleName -ErrorAction Stop
            Write-Host "`t• " -NoNewline -ForegroundColor White
            Write-Host "Module " -NoNewline -ForegroundColor DarkGray
            Write-Host "[$ModuleName]" -NoNewline -ForegroundColor Green
            Write-Host " imported successfully." -ForegroundColor DarkGray
            Write-Log -Message "Module '[$ModuleName]' imported successfully." -Level "OK" -NoConsoleOutput
        }
        catch {
            Write-Host "`t• " -NoNewline -ForegroundColor White
            Write-Host "Failed to import module " -NoNewline
            Write-Host "[$ModuleName]" -NoNewline -ForegroundColor Red
            Write-Host ": $_" -ForegroundColor Red
            Write-Log -Message "Failed to import module '[$ModuleName]': $_" -Level "Error" -NoConsoleOutput
        }
        # Add a delay to slow down the progress bar
        Start-Sleep -Seconds 1
    }
}
# Import the required modules
# Link to HPE OneView PowerShell Library: https://www.powershellgallery.com/packages/HPEOneView.800/8.0.3642.2784
Import-ModulesIfNotExists -ModuleNames 'HPEOneView.800', 'Microsoft.PowerShell.Security', 'Microsoft.PowerShell.Utility'
# Define the CSV file name
$csvFileName = "Appliances_To_Be_Configured.csv"
# Define the path to the CSV file
$csvFilePath = Join-Path -Path $scriptDirectory -ChildPath $csvFileName
# Task 2: Check if the CSV file exists
if (-not (Test-Path -Path $csvFilePath)) {
    # Write an error message to the console indicating that the CSV file could not be found
    Write-Host "`n$Spaces$($taskNumber). The CSV file '$csvFileName' could not be found at: $csvFilePath" -ForegroundColor Red
    # Log the error message
    Write-Log -Message "The CSV file '$csvFileName' could not be found at: $csvFilePath" -Level "Error"
    # Stop the script execution
    exit
}
# Increment $script:taskNumber
$script:taskNumber++
# Task 3: Read the CSV file
$AppliancesToBeConfigured = Import-Csv -Path $csvFilePath
# Check if the CSV file is not empty or null and contains the required columns (ApplianceFQDN, Name, Type, VLANType, VlanId, Purpose, TypicalBandwidth, MaximumBandwidth, SmartLink, PrivateNetwork)
if (-not $AppliancesToBeConfigured) {
    # Write an error message to the console indicating that the CSV file is empty or null
    Write-Host "`n$Spaces$($taskNumber). The CSV file '$csvFileName' is empty or null." -ForegroundColor Red
    # Log the error message
    Write-Log -Message "The CSV file '$csvFileName' is empty or null." -Level "Error"
    # Stop the script execution
    exit
}
else {
    # Write a message to the console indicating that the CSV file has been read successfully
    Write-Host "`n$Spaces$($taskNumber). The CSV file '$csvFileName' has been read successfully." -ForegroundColor Green
    # Log the success message
    Write-Log -Message "The CSV file '$csvFileName' has been read successfully." -Level "Info"
}
# Increment $script:taskNumber
$script:taskNumber++
# Task 4: Check if credential folder exists
Write-Host "`n$Spaces$($taskNumber). Checking for credential folder:`n" -ForegroundColor Magenta
# Log the task
Write-Log -Message "Checking for credential folder." -Level "Info" -NoConsoleOutput
# Check if the credential folder exists, if not say it at console and create it, if already exist say it at console
if (Test-Path -Path $credentialFolder) {
    # Write a message to the console
    Write-Host "`t• " -NoNewline -ForegroundColor White
    Write-Host "Credential folder already exists at:" -NoNewline -ForegroundColor DarkGray
    Write-Host " $credentialFolder" -ForegroundColor Yellow
    # Write a message to the log file
    Write-Log -Message "Credential folder already exists at $credentialFolder" -Level "Info" -NoConsoleOutput
}
else {
    # Write a message to the console
    Write-Host "`t• " -NoNewline -ForegroundColor White
    Write-Host "Credential folder does not exist." -NoNewline -ForegroundColor Red
    Write-Host " Creating now..." -ForegroundColor DarkGray
    Write-Log -Message "Credential folder does not exist, creating now..." -Level "Info" -NoConsoleOutput
    # Create the credential folder if it does not exist already
    New-Item -ItemType Directory -Path $credentialFolder | Out-Null
    # Write a message to the console
    Write-Host "`t• " -NoNewline -ForegroundColor White
    Write-Host "Credential folder created at:" -NoNewline -ForegroundColor DarkGray
    Write-Host " $credentialFolder" -ForegroundColor Green
    # Write a message to the log file
    Write-Log -Message "Credential folder created at $credentialFolder" -Level "OK" -NoConsoleOutput
}
# Define the path to the credential file
$credentialFile = Join-Path -Path $credentialFolder -ChildPath "credential.txt"
# Task 5: Check if the credential file exists, if not prompt the user to enter the credentials and save them to the file in the credential folder 
# and if already exist say it at console and read the credentials from the file and store them in variables for later use in the script
Write-Host "`n$Spaces$($taskNumber). Checking for credential file:`n" -ForegroundColor Magenta
# Log the task
Write-Log -Message "Checking for credential file." -Level "Info" -NoConsoleOutput
# Check if the credential file exists, if not say it at console and create it, if already exist say it at console
if (Test-Path -Path $credentialFile) {
    # Write a message to the console
    Write-Host "`t• " -NoNewline -ForegroundColor White
    Write-Host "Credential file already exists at:" -NoNewline -ForegroundColor DarkGray
    Write-Host " $credentialFile" -ForegroundColor Yellow
    # Write a message to the log file
    Write-Log -Message "Credential file already exists at $credentialFile" -Level "Info" -NoConsoleOutput
    # Read the credentials from the file and store them in variables
    $credential = Get-Content -Path $credentialFile
    $username = $credential[0]
    $password = $credential[1] | ConvertTo-SecureString -AsPlainText -Force
    $credentialObject = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
}
else {
    # Write a message to the console
    Write-Host "`t• " -NoNewline -ForegroundColor White
    Write-Host "Credential file does not exist." -NoNewline -ForegroundColor Red
    Write-Host " Creating now..." -ForegroundColor DarkGray
    Write-Log -Message "Credential file does not exist, creating now..." -Level "Info" -NoConsoleOutput
    # Prompt the user to enter the credentials
    $username = Read-Host -Prompt "Enter the username for the HPE OneView appliance"
    $password = Read-Host -Prompt "Enter the password for the HPE OneView appliance" -AsSecureString
    $credentialObject = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $password
    # Save the credentials to the file in the credential folder
    $credentialObject | Export-Clixml -Path $credentialFile
    # Write a message to the console
    Write-Host "`t• " -NoNewline -ForegroundColor White
    Write-Host "Credential file created at:" -NoNewline -ForegroundColor DarkGray
    Write-Host " $credentialFile" -ForegroundColor Green
    # Write a message to the log file
    Write-Log -Message "Credential file created at $credentialFile" -Level "OK" -NoConsoleOutput
}
# Increment $script:taskNumber
$script:taskNumber++
# Convert the appliance FQDNs to uppercase
$AppliancesToBeConfigured = $AppliancesToBeConfigured | ForEach-Object {
    $_.ApplianceFQDN = $_.ApplianceFQDN.ToUpper()
    $_
}
# Group the appliance-network combinations by appliance
$ApplianceGroups = $AppliancesToBeConfigured | Group-Object -Property ApplianceFQDN
# Display the number of appliances to be configured
Write-Host "`n$Spaces$($taskNumber). Number of appliances to be configured: $($ApplianceGroups.Count)`n" -ForegroundColor Magenta
# Log the number of appliances to be configured
Write-Log -Message "Number of appliances to be configured: $($ApplianceGroups.Count)" -Level "Info" -NoConsoleOutput
# Increment $script:taskNumber
$script:taskNumber++
# Connect to each appliance and configure the networks as specified in the CSV file
foreach ($group in $groupedAppliancesTobeConfigured) {
    # Load the credential from the credential file
    $credential = Import-Clixml -Path $credentialFile

    Connect-HPOVMgmt -Hostname $group.Name -Credential $credential

    foreach ($applianceNetwork in $group.Group) {
        # Check if the network already exists with the same name or VLAN ID
        $existingNetwork = Get-OVNetwork | Where-Object { $_.Name -eq $applianceNetwork.Name -or $_.VlanId -eq $applianceNetwork.VlanId }

        if ($null -eq $existingNetwork) {
            # If the network does not exist, create it
            New-OVNetwork -Name $applianceNetwork.Name -Type $applianceNetwork.Type -VLANType $applianceNetwork.VLANType -VlanId $applianceNetwork.VlanId -Purpose $applianceNetwork.Purpose -TypicalBandwidth $applianceNetwork.TypicalBandwidth -MaximumBandwidth $applianceNetwork.MaximumBandwidth -SmartLink $applianceNetwork.SmartLink -PrivateNetwork $applianceNetwork.PrivateNetwork -ApplianceConnection $group.Name
        }
        else {
            Write-Output "Network $($applianceNetwork.Name) with VLAN ID $($applianceNetwork.VlanId) already exists. Skipping creation."
            # Log the message
            Write-Log -Message "Network $($applianceNetwork.Name) with VLAN ID $($applianceNetwork.VlanId) already exists. Skipping creation." -Level "Info"
        }
    }
}
# Increment $script:taskNumber after the function call
$script:taskNumber++
# Task 7: Script execution completed successfully
# write a message to the console indicating a summary of the script execution
Write-Host "`n$Spaces$($taskNumber). Summary of script execution.`n" -ForegroundColor Magenta
# Just before calling Complete-Logging
$endTime = Get-Date
$totalRuntime = $endTime - $startTime
# Call Complete-Logging at the end of the script
Complete-Logging -LogPath $script:LogPath -ErrorCount $ErrorCount -WarningCount $WarningCount -TotalRuntime $totalRuntime