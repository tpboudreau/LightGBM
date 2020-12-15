
$cache = "$env:PIPELINE_WORKSPACE\opencl_windows-amd_cpu-v3_0_130_135"
$installer = "AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe"

if ($env:OPENCL_INSTALLER_FOUND -ne 'true') {

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
}

Write-Output "Installing OpenCL runtime"
Invoke-Command -ScriptBlock {Start-Process "$cache\$installer" -ArgumentList '/S /V"/quiet /norestart /passive /log opencl.log"' -Wait}

$property = Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Khronos\OpenCL\Vendors
if ($property -eq $null) {
  Write-Output "Unable to install OpenCL runtime"
  Write-Output "OpenCL installation log:"
  Get-Content "opencl.log"
  Write-Output "Setting EXIT"
  $host.SetShouldExit(-1)
  Exit -1
} else {
  Write-Output "Successfully installed OpenCL runtime"
  Write-Output "Current OpenCL drivers:"
  Write-Output $property
}

