
Write-Output "Agent platform information:"
Get-WmiObject -Class Win32_ComputerSystem
Get-WmiObject -Class Win32_Processor
Get-WmiObject -Class Win32_BIOS

#Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full'

#Write-Output "Downloading OpenCL runtime"
#curl -o AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe http://amd-dev.wpengine.netdna-cdn.com/app-sdk/installers/APPSDKInstaller/3.0.130.135-GA/full/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe
#Invoke-WebRequest -OutFile AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe -Uri https://gamma-rho.com/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe

#Write-Output "Downloading OpenCL runtime"
#Invoke-WebRequest -OutFile AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.1 -Uri https://gamma-rho.com/split/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.1
#Invoke-WebRequest -OutFile AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.2 -Uri https://gamma-rho.com/split/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.2
#Invoke-WebRequest -OutFile AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.3 -Uri https://gamma-rho.com/split/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.3
#Invoke-WebRequest -OutFile AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.4 -Uri https://gamma-rho.com/split/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.4
#Invoke-WebRequest -OutFile AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.EXE -Uri https://gamma-rho.com/split/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.EXE
#.\AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.EXE

Write-Output "Downloading OpenCL runtime"
$parts = @("1", "2", "3", "4", "EXE")
foreach ($p in $parts) {
  Write-Output " - downloading part $($p)"
  Invoke-WebRequest -OutFile AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.$p -Uri https://gamma-rho.com/split/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.$p
}
pwd
dir
Write-Output " - combining parts"
.\AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe.EXE
Write-Output "DONE"
pwd
dir

Write-Output "Installing OpenCL runtime"
Invoke-Command -ScriptBlock {Start-Process '.\AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe' -ArgumentList '/S /V"/quiet /norestart /passive /log amd_opencl_sdk.log"' -Wait}

$property = Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Khronos\OpenCL\Vendors
if ($property -eq $null) {
  Write-Output "Unable to install OpenCL runtime"
  Write-Output "Setting EXIT"
  $host.SetShouldExit(-1)
  Exit -1
} else {
  Write-Output "Successfully installed OpenCL runtime"
  Write-Output "Current OpenCL drivers:"
  Write-Output $property
  Exit -1
}

