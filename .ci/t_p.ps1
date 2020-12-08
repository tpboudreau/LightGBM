
function Check-Output {
  param( [bool]$success )
  if (!$success) {
    Write-Output "Setting EXIT"
    $host.SetShouldExit(-1)
    Exit -1
  }
}

Write-Output "Interrogating OpenCL runtime"
curl https://ci.appveyor.com/api/projects/oblomov/clinfo/artifacts/clinfo.exe?job=platform%3a+x64 -o clinfo.exe
.\clinfo.exe

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

Write-Output "Running tests"
#$tests = $env:BUILD_SOURCESDIRECTORY + "/tests"
$env:LIGHTGBM_TEST_DUAL_CPU_GPU = "1"
cd $env:BUILD_SOURCESDIRECTORY/tests/python_package_test
#python test_dual.py ; Check-Output $?
pytest test_dual.py ; Check-Output $?
#pytest $tests ; Check-Output $?
Write-Output "Completed tests"

conda deactivate

