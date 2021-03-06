@ECHO OFF
SETLOCAL

CALL %~dp0\InitializeEnvironment.bat || EXIT /b 10

IF "%1"=="" (SET "Configuration=Debug") ELSE (SET "Configuration=%1")
IF "%2"=="" (SET "GVFSVersion=0.2.173.2") ELSE (SET "GVFSVersion=%2")

SET SolutionConfiguration=%Configuration%.Windows

SET nuget="%VFS_TOOLSDIR%\nuget.exe"
IF NOT EXIST %nuget% (
  mkdir %nuget%\..
  powershell -ExecutionPolicy Bypass -Command "Invoke-WebRequest 'https://dist.nuget.org/win-x86-commandline/latest/nuget.exe' -OutFile %nuget%"
)

:: Acquire vswhere to find dev15 installations reliably.
SET vswherever=2.5.2
%nuget% install vswhere -Version %vswherever% || exit /b 1
SET vswhere=%VFS_PACKAGESDIR%\vswhere.%vswherever%\tools\vswhere.exe

:: Use vswhere to find the latest VS installation (including prerelease installations) with the msbuild component.
:: See https://github.com/Microsoft/vswhere/wiki/Find-MSBuild
for /f "usebackq tokens=*" %%i in (`%vswhere% -all -prerelease -latest -version "[15.0,16.0)" -products * -requires Microsoft.Component.MSBuild Microsoft.VisualStudio.Workload.ManagedDesktop Microsoft.VisualStudio.Workload.NativeDesktop Microsoft.VisualStudio.Workload.NetCoreTools Microsoft.Component.NetFX.Core.Runtime Microsoft.VisualStudio.Component.Windows10SDK.10240 -property installationPath`) do (
  set VsInstallDir=%%i
)

IF NOT DEFINED VsInstallDir (
  echo ERROR: Could not locate a Visual Studio installation with required components.
  echo Refer to Readme.md for a list of the required Visual Studio components.
  exit /b 10
)

SET msbuild="%VsInstallDir%\MSBuild\15.0\Bin\amd64\msbuild.exe"
IF NOT EXIST %msbuild% (
  echo ERROR: Could not find msbuild
  exit /b 1
)

%msbuild% %VFS_SRCDIR%\GVFS.sln /p:GVFSVersion=%GVFSVersion% /p:Configuration=%SolutionConfiguration% /p:Platform=x64 || exit /b 1

dotnet publish %VFS_SRCDIR%\GVFS\FastFetch\FastFetch.csproj /p:Configuration=%Configuration% /p:Platform=x64 /p:SolutionDir=%VFS_SRCDIR%\ --runtime win-x64 --framework netcoreapp2.1 --self-contained --output %VFS_PUBLISHDIR%\FastFetch || exit /b 1
ENDLOCAL