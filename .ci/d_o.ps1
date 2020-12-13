
Write-Output "Downloading OpenCL installer parts"
$cache = "$env:PIPELINE_WORKSPACE\opencl_windows-amd_cpu-v3_0_130_135"
$installer = "AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe"
echo $cache
echo $installer
$parts = @("1", "2", "3", "4", "5", "6", "7", "8", "9", "EXE")
foreach ($p in $parts) {
  Write-Output " - downloading part $($p)"
  Invoke-WebRequest -OutFile "$installer.$p" -Uri "https://gamma-rho.com/parts/$installer.$p"
}
Write-Output "Combining parts"
Start-Process "$installer.EXE" -Wait
Start-Sleep -Seconds 10
Move-Item -Path "$installer" -Destination "$cache\$installer"

