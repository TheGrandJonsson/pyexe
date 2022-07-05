### THIS NEEDS TO HAVE REMOTE EXECUTION POLICY SET BEFORE EXECUTION ###
$PYTHON = "C:\\Python37"
$OUTDIR = "--out="+$PYTHON
$INSTALLVERSION = '3.7'
$INSTALLMIN = '--min=2'
$OUTPUT= "py37.exe"
#Change user to point to your own environment
$ALTPYTHON= $env:USERPROFILE + "\AppData\Local\Programs\Python\Python310"
$PROJDIR = Get-Location
$ORIGPATH = $env:Path
$env:Path = $ALTPYTHON + ';' + $ALTPYTHON + '\\Scripts;' + $ORIGPATH
#SET PATH=$ALTPYTHON + ";"+$ALTPYTHON+"\\Scripts;"+$ORIGPATH
python -m pip install --upgrade requests
python "install_python.py" $INSTALLVERSION $INSTALLMIN $OUTDIR "--force"

Get-ChildItem $PYTHON -Include *.pyc -Recurse | Remove-Item
Get-ChildItem $PYTHON -Include *.pyo -Recurse | Remove-Item
## Use the specific python version for building
#Added a reference to the System32\downlevel to get dependencies for PyInstaller correctly
$env:Path = $PYTHON + ';' + $PYTHON + '\\Scripts;' + 'C:\\Windows\\System32\\downlevel\' + ';'+ $ORIGPATH
#Added ensurepip to install pip as the current 3.7 python installer didn't install it on my machine...
python -m ensurepip --upgrade
#python -m pip install --upgrade pip
python -m pip install --upgrade setuptools
python -m pip install --upgrade pywin32 psutil six setuptools
# Generate the list of modules we need to import
Get-ChildItem $PYTHON -Include *.pyc -Recurse | Remove-Item
Get-ChildItem $PYTHON -Include *.pyo -Recurse | Remove-Item

python "modules_pyexe.py" "pyexe.py"
# Install PyInstaller.  We patch various aspects of PyInstaller, so use a
# fixed version. Upgraded to latest version of PyInstaller to fix missing libraries for windows dependencies
python -m pip install pyinstaller==4.9
# Install a patching program
python -m pip install patch
# Remove the site module hook from PyInstaller; we need the site module as is
Remove-Item $PYTHON"\\Lib\\site-packages\\PyInstaller\\hooks\\pre_find_module_path\\hook-site.*"
Get-ChildItem $PYTHON"\\Lib\\site-packages\\PyInstaller\\hooks\\pre_find_module_path\\__pycache__" -Recurse | Remove-Item
# Copy a build hook to PyInstaller to include the cacerts.pem file for pip.
copy 'hooks\\hook*.*' $PYTHON'\\Lib\\site-packages\\PyInstaller\\hooks\\.'
# Replace the multiprocessing loader hook
copy 'hooks\\pyi_rth*.*' $PYTHON'\\Lib\\site-packages\\PyInstaller\\loader\\rthooks\\.'
# Replace the stage 3 importer
pushd $PYTHON'\\Lib\\site-packages\\PyInstaller\\loader' 
python -m patch $PROJDIR'\\hooks\\pyimod03_importers.py.diff'
popd
# Patch the PyInstaller building\utils.py to avoid storing project path
# names.
pushd $PYTHON'\\Lib\\site-packages\\PyInstaller\\building'
python -m patch $PROJDIR'\\hooks\\utils.py.diff'
popd
# Patch the PyInstall loader\pyiboot01_bootstrap.py to keep ctypes' patches a scope other than global
pushd $PYTHON'\\Lib\\site-packages\\PyInstaller\\loader'
python -m patch $PROJDIR'\\hooks\\pyiboot01_bootstrap.py.diff' 
popd

Get-ChildItem $PYTHON -Include *.pyc -Recurse | Remove-Item
Get-ChildItem $PYTHON -Include *.pyo -Recurse | Remove-Item
# Save the artifact immediately
python -m PyInstaller --onefile pyexe.py --upx-dir 'C:\\u\\upx394w' --exclude-module FixTk --exclude-module tcl --exclude-module tk --exclude-module _tkinter --exclude-module tkinter --exclude-module Tkinter --runtime-hook 'hooks\\rth_subprocess.py' --runtime-hook 'hooks\\rth_pip.py' --icon $PYTHON'\\pythonw.exe' --add-binary $PYTHON'\\Lib\\site-packages\\setuptools\\cli-32.exe;setuptools' --add-binary $PYTHON'\\Lib\\site-packages\\setuptools\\cli-64.exe;setuptools' --add-binary $PYTHON'\\Lib\\site-packages\\setuptools\\cli.exe;setuptools' --add-binary $PYTHON'\\Lib\\site-packages\\setuptools\\command\\launcher manifest.xml;setuptools'
cp 'dist\pyexe.exe' $OUTPUT
