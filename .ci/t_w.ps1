function Check-Output {
  param( [bool]$success )
  Write-Output "Testing output"
  if (!$success) {
    Write-Output "Setting EXIT"
    $host.SetShouldExit(-1)
    Exit -1
  }
}

## unify environment variables for Azure devops and AppVeyor
#if (Test-Path env:APPVEYOR) {
#  $env:APPVEYOR = "true"
#  $env:BUILD_SOURCESDIRECTORY = $env:APPVEYOR_BUILD_FOLDER
#}

# setup for Python
conda init powershell
conda activate
conda config --set always_yes yes --set changeps1 no
conda update -q -y conda
conda create -q -y -n $env:CONDA_ENV python=$env:PYTHON_VERSION joblib matplotlib numpy pandas psutil pytest python-graphviz scikit-learn scipy ; Check-Output $?
conda activate $env:CONDA_ENV

# Install the Intel CPU runtime, so we can run tests against OpenCL
#Write-Output "Downloading OpenCL runtime"
###curl -o opencl_runtime_18.1_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/vcp/13794/opencl_runtime_18.1_x64_setup.msi
###$msiarglist = "/i opencl_runtime_18.1_x64_setup.msi /quiet /norestart /log msi.log"
#curl -o opencl_runtime_16.1.2_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/12512/opencl_runtime_16.1.2_x64_setup.msi
#$msiarglist = "/i opencl_runtime_16.1.2_x64_setup.msi /quiet /norestart /log msi.log"
#Write-Output "Installing OpenCL runtime"
#$return = Start-Process msiexec -ArgumentList $msiarglist -Wait -passthru
#Get-Content msi.log
#If (@(0,3010) -contains $return.exitcode) {
#  Write-Output "OpenCL install successful"
#} else {
#  Write-Output "OpenCL install failed, aborting"
#  exit 1
#}
#RefreshEnv
Write-Output "Current OpenCL drivers:"
Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Khronos\OpenCL\Vendors
#Start-Sleep -Seconds 10

# TEMPORARY for debugging
#Write-Output "Interrogating OpenCL runtime"
#curl https://ci.appveyor.com/api/projects/oblomov/clinfo/artifacts/clinfo.exe?job=platform%3a+x64 -o clinfo.exe
#.\clinfo.exe
# /TEMPORARY

Write-Output "Updating config.h"
Set-Variable -Name CONFIG_HEADER -Value "$env:BUILD_SOURCESDIRECTORY/include/LightGBM/config.h"
(Get-Content (Get-Variable CONFIG_HEADER -valueOnly)).replace('std::string device_type = "cpu";', 'std::string device_type = "gpu";') | Set-Content (Get-Variable CONFIG_HEADER -valueOnly)
If (!(Select-String -Path (Get-Variable CONFIG_HEADER -valueOnly) -Pattern 'std::string device_type = "gpu";' -Quiet)) {
  Write-Output "Rewriting config.h for GPU device type failed"
  Exit -1
}

#Write-Output "Building and installing wheel"
cd $env:BUILD_SOURCESDIRECTORY/python-package
python setup.py bdist_wheel --integrated-opencl --plat-name=win-amd64 --universal ; Check-Output $?
cd dist; pip install --user @(Get-ChildItem *.whl) ; Check-Output $?
cp @(Get-ChildItem *.whl) $env:BUILD_ARTIFACTSTAGINGDIRECTORY

#if (($env:TASK -eq "sdist") -or (($env:APPVEYOR -eq "true") -and ($env:TASK -eq "python"))) {
#  # cannot test C API with "sdist" task
#  $tests = $env:BUILD_SOURCESDIRECTORY + "/tests/python_package_test"
#} elseif ($env:TASK -eq "bdist") {

#$tests = $env:BUILD_SOURCESDIRECTORY + "/tests/python_package_test"
$tests = $env:BUILD_SOURCESDIRECTORY + "/tests"
# Make sure we can do both CPU and GPU; see tests/python_package_test/test_dual.py
$env:LIGHTGBM_TEST_DUAL_CPU_GPU = "1"

#} else {
#  $tests = $env:BUILD_SOURCESDIRECTORY + "/tests"
#}

Write-Output "Running tests"
pytest $tests ; Check-Output $?
Write-Output "Completed tests"
#Start-Sleep -Seconds 300

