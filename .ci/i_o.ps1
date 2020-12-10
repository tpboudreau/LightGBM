
Write-Output "HW Platform information:"
Get-WmiObject -Class Win32_ComputerSystem
Get-WmiObject -Class Win32_Processor
Get-WmiObject -Class Win32_BIOS

Write-Output "Downloading OpenCL runtime"
curl -o AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe http://amd-dev.wpengine.netdna-cdn.com/app-sdk/installers/APPSDKInstaller/3.0.130.135-GA/full/AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe
#curl -o w_opencl_runtime_p_2021.1.1.191.exe https://registrationcenter-download.intel.com/akdlm/irc_nas/vcp/17389/w_opencl_runtime_p_2021.1.1.191.exe
#curl -o opencl_runtime_18.1_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/vcp/13794/opencl_runtime_18.1_x64_setup.msi
#$msiarglist = "/i opencl_runtime_18.1_x64_setup.msi /quiet /norestart /log msi.log"
#curl -o opencl_runtime_16.1.2_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/12512/opencl_runtime_16.1.2_x64_setup.msi
#$msiarglist = "/i opencl_runtime_16.1.2_x64_setup.msi /quiet /norestart /log msi.log"

Write-Output "Installing OpenCL runtime"
Invoke-Command -ScriptBlock {Start-Process ".\AMD-APP-SDKInstaller-v3.0.130.135-GA-windows-F-x64.exe" -ArgumentList '/S /V"/quiet /norestart /passive /log amd_opencl_sdk.log"' -Wait}
#Invoke-Command -ScriptBlock {Start-Process ".\w_opencl_runtime_p_2021.1.1.191.exe" -ArgumentList "-s -l opencl_runtime.log -a /n /quiet /norestart /passive" -Wait}
#$return = Start-Process msiexec -ArgumentList $msiarglist -Wait -passthru
#Get-Content msi.log
#If (@(0,3010) -contains $return.exitcode) {
#  Write-Output "OpenCL install successful"
#} else {
#  Write-Output "OpenCL install failed, aborting"
#  exit 1
#}

#RefreshEnv
#Write-Output "Current OpenCL drivers:"
#Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Khronos\OpenCL\Vendors

