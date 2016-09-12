# Based on https://sitecore-community.github.io/docs/search/solr/fast-track-solr-for-lazy-developers/
# Must be run as system admin

param(
    [Parameter(Mandatory=$true)]
    [string]$solrExtractLocation)

if ($solrExtractLocation -eq $null -or $solrExtractLocation -eq "")
{
    Write-Host "Parameter $solrExtractLocation is mandatory, but it is null or empty" -ForegroundColor Red
    exit 1
}

$solrVersionName="4.10.4"
#$solrExtractLocation="D:\"
$filesLocation="..\files"
$solrUrl="http://archive.apache.org/dist/lucene/solr/$solrVersionName/solr-$solrVersionName.zip"
$solrExtractFolder="solr-$solrVersionName"
$solrCleanCores="$filesLocation\Clean SOLR cores 4.10.zip"
$solrCoresPath="$solrExtractLocation\$solrExtractFolder\example\solr"
$solrBinaryLocation="bin\solr.cmd"
$solrServiceName="LiUSitecoreSolr"
$solrServiceDisplayName="LiU Sitecore Solr service instance"
$solrServiceDescription="This is the solr service for the LiU implementation of Sitecore. Used by developers on local machines"
$serviceStartupWaitTime=25
$solrCheckUrl="http://127.0.0.1:8983/solr"
$nssmPath=".\nssm.exe"


$tempdir = Get-Location
$tempdir = $tempdir.tostring()
$appToMatch = '*Java*'
#$msiFile = $tempdir+"\microsoft.interopformsredist.msi"
#$msiArgs = "-qb"

function Get-InstalledApps
{
    if ([IntPtr]::Size -eq 4) {
        $regpath = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    }
    else {
        $regpath = @(
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
            'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        )
    }
    Get-ItemProperty $regpath | .{process{if($_.DisplayName -and $_.UninstallString) { $_ } }} | Select DisplayName, Publisher, InstallDate, DisplayVersion, UninstallString |Sort DisplayName
}

function Test-Administrator  
{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}


# Dummy check if solr is already running 
Write-Host "Checking if Solr is already installed"
$isSolrServiceInstalled = Get-Service | Where-Object {$_.Name -like "*solr*"}
if ( -not ($isSolrServiceInstalled -eq $null)) 
{
    # Solr already installed in some way
    Write-Host "Solr is already available as a service, you probably have alread installed it" -ForegroundColor Green

    # Check if running / Check if our Liu service exists?
    #$isLiUSolrServiceRunning = Get-Service -Name $solrServiceName
    #if ( $isLiUSolrServiceRunning.Status -eq "Running")
    exit 0
}



# Check java
Write-Host "Checking Java is installed"
$result = Get-InstalledApps | where {$_.DisplayName -like $appToMatch}

if ($result -eq $null) {
    #(Start-Process -FilePath $msiFile -ArgumentList $msiArgs -Wait -Passthru).ExitCode
    Write-Host "Java not installed please install from http://www.java.com/sv/download/win10.jsp" -ForegroundColor Red
    exit 1
}

# Try to actually run java (it has to be in the path for the Solr service to be able to start)
try
{
    java 2> $null
}
catch
{
    Write-Host "Java is installed but it is not in the path, you have to add it ot the path so that Solr service will be able to start" -ForegroundColor Red
    exit 1
}

# Check nssm
if(!(Test-Path $nssmPath))
{
    Write-Host "Nssm is not available, won't be able to create the Solr service. It should be at $nssmPath" -ForegroundColor Red
    exit 1
}

# Check admin privilege, won't be able to create the service otherwise
Write-Host "Checking administrator privilege before creating solr service"
if ( -not (Test-Administrator)  )
{ 
    Write-Host "Not running as administrator - won't be able to create the solr service. Please run again as administrator" -ForegroundColor Red
    exit 1
}


Write-Host "Downloading Solr $solrVersionName"
$filename = "$env:temp\solr-$solrVersionName.zip" 
#New-Item $filename -itemType File 
if(!(Test-Path $filename))
{
    wget $solrUrl -OutFile $filename
}
else 
{
    Write-Host "Solr has already been downloaded"
}

# Kind of hard to get an exit code from wget/Invoke-WebRequest so we just check if the file is there and over 0 size
if(!(Test-Path $filename))
{
    Write-Host "Couldn't download the Solr zip file correctly, check error messages and fix accordingly." -ForegroundColor Red
    exit 1
}


Write-Host "Unpacking Solr"
#New-Item -ItemType Directory -Force -Path C:\
if(!(Test-Path $solrExtractLocation\$solrExtractFolder\$solrBinaryLocation))
{
    Expand-Archive $filename -DestinationPath $solrExtractLocation
}
else 
{
    Write-Host "Solr had already been extracted to $solrExtractLocation"
}

if(!(Test-Path $solrExtractLocation\$solrExtractFolder\$solrBinaryLocation))
{
    Write-Host "Couldn't extract solr, check error messages and fix accordingly" -ForegroundColor Red
    exit 1
}


Write-Host "Setting up Solr as a service"

# Doesn't work to use user credentials, must be run as admin. -> PermissionDenied
#New-Service -BinaryPathName "$solrExtracLocation\$solrExtractFolder\$solrBinaryLocation start"  -Credential $env:USERDOMAIN\$env:USERNAME -Name $solrServiceName -DisplayName $solrServiceDisplayName -StartupType Automatic -Description $solrServiceDescription
#New-Service -BinaryPathName "$solrExtractLocation\$solrExtractFolder\$solrBinaryLocation start" -Name $solrServiceName -DisplayName $solrServiceDisplayName -StartupType Automatic -Description $solrServiceDescription -ErrorVariable scErr
# Use nssm to create the service as we are trying to run an exe that is not compiled to be a service. See http://serverfault.com/questions/54676/how-to-create-a-service-running-a-bat-file-on-windows-2008-server
# http://nssm.cc/commands
#$nssmInstallScript = {"$nssmPath install $solrServiceName start -f"}
#$nssmChangeAppDirectory = {"$nssmPath set AppDirectory $solrExtractLocation\$solrExtractFolder\bin"}
#Invoke-Command -ScriptBlock $nssmInstallScript
#Invoke-Command -ScriptBlock $nssmChangeAppDirectory 
$res = Start-Process $nssmPath -ArgumentList "install $solrServiceName $solrExtractLocation\$solrExtractFolder\$solrBinaryLocation start -f" -Wait -NoNewWindow -PassThru
$res2 = Start-Process $nssmPath -ArgumentList "set $solrServiceName AppDirectory $solrExtractLocation\$solrExtractFolder\bin" -Wait -NoNewWindow -PassThru


Start-Sleep 2
Start-Service -Name $solrServiceName

Write-Host "Checking if Solr service was created correctly"
$isSolrRunning = Get-Service | Where-Object {$_.Name -like "*solr*"}
if ( $isSolrRunning -eq $null ) 
{ 
    Write-Host "Something went wrong setting up the service, it is not listed in the service list" -ForegroundColor Red
    exit 1
}


Write-Host "Waiting $serviceStartupWaitTime second to check if Solr started correctly"
Start-Sleep $serviceStartupWaitTime
# Check that the service is effectively running 
wget $solrCheckUrl -OutVariable solrCheckResult > $null
if($solrCheckResult.StatusCode -eq $null -or ! $solrCheckUrl -eq 200 )
{
    Write-Host "Something is wrong with the solr service, please check service creation" -ForegroundColor Red
    exit 1
}

# Copy cores

if(!(Test-Path $solrCleanCores))
{ 
    Write-Host "Solr clean cores package not found, make sure the package is correctly configured" -ForegroundColor Red
    exit 1
}

Write-Host "Unpacking clean solr Sitecore cores"
if(!(Test-Path "$solrCoresPath\sitecore_core_index"))
{
    Expand-Archive $solrCleanCores -DestinationPath $solrCoresPath
    if(!(Test-Path "$solrCoresPath\sitecore_core_index"))
    {
        Write-Host "Couldn't extract solr cores, check error messages and fix accordingly" -ForegroundColor Red
        exit 1
    }

    Write-Host "Correctly unpacked Sitecore solr cores"

    # Restart Solr to re-read cores
    Write-Host "Restarting Solr service to re read cores"
    Stop-Service -Name $solrServiceName
    Start-Sleep $serviceStopWaitTime
    Start-Service -Name $solrServiceName
    Write-Host "Done restarting"

}
else 
{
    Write-Host "Solr cores already installed in $solrCoresPath"
}


Write-Host "Solr installed correctly" -ForegroundColor Green
exit 0