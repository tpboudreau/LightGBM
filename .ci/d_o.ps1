
$cache = "$env:PIPELINE_WORKSPACE\opencl_windows-amd_cpu-v3_0_130_135"
$installer = "AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe"

#Write-Output "Downloading ..."
#$parts = @("1", "2", "3", "4", "5", "6", "7", "8", "9", "EXE")
#foreach ($p in $parts) {
#  Write-Output " - downloading part $($p)"
#  Invoke-WebRequest -OutFile "$installer.$p" -Uri "https://github.com/microsoft/LightGBM/releases/download/v2.0.12/$installer.$p"
#}
#Write-Output "Reassembling ..."
#Start-Process "$installer.EXE" -Wait
#Start-Sleep -Seconds 10

Write-Output "Downloading ..."
Invoke-WebRequest -OutFile "$installer" -Uri "https://github.com/microsoft/LightGBM/releases/download/v2.0.12/$installer"

Write-Output "Caching ... "
New-Item $cache -ItemType Directory | Out-Null
Move-Item -Path "$installer" -Destination "$cache\$installer" | Out-Null

if (Test-Path "$cache\$installer") {
  Write-Output "Successfully downloaded ..."
} else {
  Write-Output "Unable to download ..."
  Write-Output "Setting EXIT"
  $host.SetShouldExit(-1)
  Exit -1
}

