function Check-Output {
  param( [bool]$success )
  if (!$success) {
    Write-Output "Setting EXIT"
    $host.SetShouldExit(-1)
    Exit -1
  }
}

# setup for Python
Write-Output "Setting up conda environment"
conda init powershell
conda activate
conda config --set always_yes yes --set changeps1 no
conda update -q -y conda
conda create -q -y -n $env:CONDA_ENV python=$env:PYTHON_VERSION joblib matplotlib numpy pandas psutil pytest pytest-timeout python-graphviz scikit-learn scipy ; Check-Output $?
conda activate $env:CONDA_ENV

Write-Output "Building and installing wheel"
cd $env:BUILD_SOURCESDIRECTORY/python-package
python setup.py bdist_wheel --integrated-opencl --plat-name=win-amd64 --universal ; Check-Output $?
cd dist; pip install --user @(Get-ChildItem *.whl) ; Check-Output $?
cp @(Get-ChildItem *.whl) $env:BUILD_ARTIFACTSTAGINGDIRECTORY

$tests = $env:BUILD_SOURCESDIRECTORY + "/tests"
$env:LIGHTGBM_TEST_DUAL_CPU_GPU = "1"
Write-Output "Running tests"
pytest $tests ; Check-Output $?
Write-Output "Completed tests"

# Install the Intel CPU runtime, so we can run tests against OpenCL
Write-Output "Downloading OpenCL runtime"
curl -o opencl_runtime_18.1_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/vcp/13794/opencl_runtime_18.1_x64_setup.msi
$msiarglist = "/i opencl_runtime_18.1_x64_setup.msi /quiet /norestart /log msi.log"
###curl -o opencl_runtime_16.1.2_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/12512/opencl_runtime_16.1.2_x64_setup.msi
###$msiarglist = "/i opencl_runtime_16.1.2_x64_setup.msi /quiet /norestart /log msi.log"
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

# TEMPORARY for debugging
Write-Output "Interrogating OpenCL runtime"
curl https://ci.appveyor.com/api/projects/oblomov/clinfo/artifacts/clinfo.exe?job=platform%3a+x64 -o clinfo.exe
.\clinfo.exe
# /TEMPORARY

RefreshEnv
Write-Output "Re-nterrogating OpenCL runtime"
.\clinfo.exe

$tests = $env:BUILD_SOURCESDIRECTORY + "/tests/python_package_test/test_dual.py"
$env:LIGHTGBM_TEST_DUAL_CPU_GPU = "2"
Write-Output "Running dual test"
pytest $tests ; Check-Output $?
Write-Output "Completed dual test"
