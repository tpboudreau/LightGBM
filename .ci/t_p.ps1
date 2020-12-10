
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

function Get-EnvironmentVariable([string] $Name, [System.EnvironmentVariableTarget] $Scope) {
    [Environment]::GetEnvironmentVariable($Name, $Scope)
}

function Get-EnvironmentVariableNames([System.EnvironmentVariableTarget] $Scope) {
    switch ($Scope) {
        'User' { Get-Item 'HKCU:\Environment' | Select-Object -ExpandProperty Property }
        'Machine' { Get-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' | Select-Object -ExpandProperty Property }
        'Process' { Get-ChildItem Env:\ | Select-Object -ExpandProperty Key }
        default { throw "Unsupported environment scope: $Scope" }
    }
}

function Update-SessionEnvironment {
  Write-Debug "Running 'Update-SessionEnvironment' - Updating the environment variables for the session."
  #ordering is important here, $user comes after so we can override $machine
  'Machine', 'User' |
    % {
      $scope = $_
      Get-EnvironmentVariableNames -Scope $scope |
        % {
          Set-Item "Env:$($_)" -Value (Get-EnvironmentVariable -Scope $scope -Name $_)
        }
    }
  #Path gets special treatment b/c it munges the two together
  $paths = 'Machine', 'User' |
    % {
      (Get-EnvironmentVariable -Name 'PATH' -Scope $_) -split ';'
    } |
    Select -Unique
  $Env:PATH = $paths -join ';'
}

Update-SessionEnvironment

Write-Output "Current OpenCL drivers:"
Get-ItemProperty -Path Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Khronos\OpenCL\Vendors

#curl https://ci.appveyor.com/api/projects/oblomov/clinfo/artifacts/clinfo.exe?job=platform%3a+x64 -o clinfo.exe
#.\clinfo.exe

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

