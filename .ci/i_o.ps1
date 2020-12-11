
Write-Output "Agent platform information:"
Get-WmiObject -Class Win32_ComputerSystem
Get-WmiObject -Class Win32_Processor
Get-WmiObject -Class Win32_BIOS
(Get-Host).Version

Write-Output "Downloading OpenCL runtime"
#curl -o AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe http://amd-dev.wpengine.netdna-cdn.com/app-sdk/installers/APPSDKInstaller/3.0.130.135-GA/full/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe

$installer = "AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe"
#curl https://gamma-rho.com/$installer --ipv4 --tlsv1.2 --output $installer
Invoke-WebRequest -SslProtocol Tls12 -OutFile $installer -Uri https://gamma-rho.com/$installer
#Invoke-WebRequest -OutFile $installer -Uri https://gamma-rho.com/$installer

Write-Output "Installing OpenCL runtime"
Invoke-Command -ScriptBlock {Start-Process .\$installer -ArgumentList '/S /V"/quiet /norestart /passive /log amd_opencl_sdk.log"' -Wait}

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
}

