
function Check-Output {
  param( [bool]$success )
  if (!$success) {
    Write-Output "Setting EXIT"
    $host.SetShouldExit(-1)
    Exit -1
  } else {
    Write-Output "Setting SUCCESS"
  }
}

#. $env:BUILD_SOURCESDIRECTORY/.ci/u_s.ps1
#Update-SessionEnvironment

Write-Output "START"
#Add-Content -Path "$profile" -Value @'
#$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
#if (Test-Path($ChocolateyProfile)) {
#  Import-Module "$ChocolateyProfile"
#}
#'@

#{Add-Content -Path "$profile" -Value @'$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1" if (Test-Path($ChocolateyProfile)) { Import-Module "$ChocolateyProfile" }'@}

Write-Output "$profile"
Get-ChildItem "$profile"
Write-Output "X"
Add-Content -Path "$profile" -Value '$M = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1" ; if (Test-Path($M)) { Import-Module "$M" }'

RefreshEnv

Write-Output "END"
Exit -1

Write-Output "Current OpenCL drivers:"
Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Khronos\OpenCL\Vendors

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

#Write-Output "Running module"
#cd $env:BUILD_SOURCESDIRECTORY/tests/python_package_test
##python test_dual.py ; Check-Output $?
#python -m trace --trace td.py ; Check-Output $?
#Write-Output "Completed module"

Write-Output "Running tests"
$tests = $env:BUILD_SOURCESDIRECTORY + "/tests"
$env:LIGHTGBM_TEST_DUAL_CPU_GPU = "1"
pytest $tests ; Check-Output $?
Write-Output "Completed tests"

conda deactivate

