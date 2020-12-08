
Write-Output "HW Platform information:"
Get-WmiObject -Class Win32_ComputerSystem
Get-WmiObject -Class Win32_Processor
Get-WmiObject -Class Win32_BIOS

# Install the Intel CPU runtime, so we can run tests against OpenCL
Write-Output "Downloading OpenCL runtime"
curl -o opencl_runtime_18.1_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/vcp/13794/opencl_runtime_18.1_x64_setup.msi
$msiarglist = "/i opencl_runtime_18.1_x64_setup.msi /quiet /norestart /log msi.log"
#curl -o opencl_runtime_16.1.2_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/12512/opencl_runtime_16.1.2_x64_setup.msi
#$msiarglist = "/i opencl_runtime_16.1.2_x64_setup.msi /quiet /norestart /log msi.log"
Write-Output "Installing OpenCL runtime"
$return = Start-Process msiexec -ArgumentList $msiarglist -Wait -passthru
Get-Content msi.log
If (@(0,3010) -contains $return.exitcode) {
  Write-Output "OpenCL install successful"
} else {
  Write-Output "OpenCL install failed, aborting"
  exit 1
}

RefreshEnv
Write-Output "Current OpenCL drivers:"
Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Khronos\OpenCL\Vendors

