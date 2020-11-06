function Check-Output {
  param( [bool]$success )
  if (!$success) {
    $host.SetShouldExit(-1)
    Exit -1
  }
}

# unify environment variables for Azure devops and AppVeyor
if (Test-Path env:APPVEYOR) {
  $env:APPVEYOR = "true"
  $env:BUILD_SOURCESDIRECTORY = $env:APPVEYOR_BUILD_FOLDER
}

if ($env:TASK -eq "r-package") {
  & $env:BUILD_SOURCESDIRECTORY\.ci\test_r_package_windows.ps1 ; Check-Output $?
  Exit 0
}

# setup for Python
conda init powershell
conda activate
conda config --set always_yes yes --set changeps1 no
conda update -q -y conda
conda create -q -y -n $env:CONDA_ENV python=$env:PYTHON_VERSION joblib matplotlib numpy pandas psutil pytest python-graphviz scikit-learn scipy ; Check-Output $?
conda activate $env:CONDA_ENV

if ($env:TASK -eq "regular") {
  mkdir $env:BUILD_SOURCESDIRECTORY/build; cd $env:BUILD_SOURCESDIRECTORY/build
  cmake -A x64 .. ; cmake --build . --target ALL_BUILD --config Release ; Check-Output $?
  cd $env:BUILD_SOURCESDIRECTORY/python-package
  python setup.py install --precompile ; Check-Output $?
  cp $env:BUILD_SOURCESDIRECTORY/Release/lib_lightgbm.dll $env:BUILD_ARTIFACTSTAGINGDIRECTORY
  cp $env:BUILD_SOURCESDIRECTORY/Release/lightgbm.exe $env:BUILD_ARTIFACTSTAGINGDIRECTORY
}
elseif ($env:TASK -eq "sdist") {
  cd $env:BUILD_SOURCESDIRECTORY/python-package
  python setup.py sdist --formats gztar ; Check-Output $?
  cd dist; pip install @(Get-ChildItem *.gz) -v ; Check-Output $?

  $env:JAVA_HOME = $env:JAVA_HOME_8_X64  # there is pre-installed Zulu OpenJDK-8 somewhere
  Invoke-WebRequest -Uri "https://github.com/microsoft/LightGBM/releases/download/v2.0.12/swigwin-3.0.12.zip" -OutFile $env:BUILD_SOURCESDIRECTORY/swig/swigwin.zip -UserAgent "NativeHost"
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [System.IO.Compression.ZipFile]::ExtractToDirectory("$env:BUILD_SOURCESDIRECTORY/swig/swigwin.zip", "$env:BUILD_SOURCESDIRECTORY/swig")
  $env:PATH += ";$env:BUILD_SOURCESDIRECTORY/swig/swigwin-3.0.12"
  mkdir $env:BUILD_SOURCESDIRECTORY/build; cd $env:BUILD_SOURCESDIRECTORY/build
  cmake -A x64 -DUSE_SWIG=ON .. ; cmake --build . --target ALL_BUILD --config Release ; Check-Output $?
  cp $env:BUILD_SOURCESDIRECTORY/build/lightgbmlib.jar $env:BUILD_ARTIFACTSTAGINGDIRECTORY/lightgbmlib_win.jar
}
elseif ($env:TASK -eq "bdist") {
  # Install the Intel CPU runtime, so we can run tests against OpenCL
  Write-Output "Downloading OpenCL runtime"
  #curl -o opencl_runtime_18.1_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/vcp/13794/opencl_runtime_18.1_x64_setup.msi
  #$msiarglist = "/i opencl_runtime_18.1_x64_setup.msi /quiet /norestart /log msi.log"
  curl -o opencl_runtime_16.1.2_x64_setup.msi http://registrationcenter-download.intel.com/akdlm/irc_nas/12512/opencl_runtime_16.1.2_x64_setup.msi
  $msiarglist = "/i opencl_runtime_16.1.2_x64_setup.msi /quiet /norestart /log msi.log"
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

  Set-Variable -Name CONFIG_HEADER -Value "$env:BUILD_SOURCESDIRECTORY/include/LightGBM/config.h"
  (Get-Content (Get-Variable CONFIG_HEADER -valueOnly)).replace('std::string device_type = "cpu";', 'std::string device_type = "gpu";') | Set-Content (Get-Variable CONFIG_HEADER -valueOnly)
  If (!(Select-String -Path (Get-Variable CONFIG_HEADER -valueOnly) -Pattern 'std::string device_type = "gpu";' -Quiet)) {
    Write-Output "Rewriting config.h for GPU device type failed"
    Exit -1
  }

  cd $env:BUILD_SOURCESDIRECTORY/python-package
  python setup.py bdist_wheel --integrated-opencl --plat-name=win-amd64 --universal ; Check-Output $?
  cd dist; pip install --user @(Get-ChildItem *.whl) ; Check-Output $?
  cp @(Get-ChildItem *.whl) $env:BUILD_ARTIFACTSTAGINGDIRECTORY
} elseif (($env:APPVEYOR -eq "true") -and ($env:TASK -eq "python")) {
  cd $env:BUILD_SOURCESDIRECTORY\python-package
  if ($env:COMPILER -eq "MINGW") {
    python setup.py install --mingw ; Check-Output $?
  } else {
    python setup.py install ; Check-Output $?
  }
}

if (($env:TASK -eq "sdist") -or (($env:APPVEYOR -eq "true") -and ($env:TASK -eq "python"))) {
  # cannot test C API with "sdist" task
  $tests = $env:BUILD_SOURCESDIRECTORY + "/tests/python_package_test"
} elseif ($env:TASK -eq "bdist") {
  $tests = $env:BUILD_SOURCESDIRECTORY + "/tests/python_package_test"
  # Make sure we can do both CPU and GPU; see tests/python_package_test/test_dual.py
  $env:LIGHTGBM_TEST_DUAL_CPU_GPU = "1"
} else {
  $tests = $env:BUILD_SOURCESDIRECTORY + "/tests"
}
pytest $tests ; Check-Output $?

if (($env:TASK -eq "regular") -or (($env:APPVEYOR -eq "true") -and ($env:TASK -eq "python"))) {
  cd $env:BUILD_SOURCESDIRECTORY/examples/python-guide
  @("import matplotlib", "matplotlib.use('Agg')") + (Get-Content "plot_example.py") | Set-Content "plot_example.py"
  (Get-Content "plot_example.py").replace('graph.render(view=True)', 'graph.render(view=False)') | Set-Content "plot_example.py"  # prevent interactive window mode
  foreach ($file in @(Get-ChildItem *.py)) {
    @("import sys, warnings", "warnings.showwarning = lambda message, category, filename, lineno, file=None, line=None: sys.stdout.write(warnings.formatwarning(message, category, filename, lineno, line))") + (Get-Content $file) | Set-Content $file
    python $file ; Check-Output $?
  }  # run all examples
  cd $env:BUILD_SOURCESDIRECTORY/examples/python-guide/notebooks
  conda install -q -y -n $env:CONDA_ENV ipywidgets notebook
  jupyter nbconvert --ExecutePreprocessor.timeout=180 --to notebook --execute --inplace *.ipynb ; Check-Output $?  # run all notebooks
}
