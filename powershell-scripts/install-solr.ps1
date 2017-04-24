
<#
.SYNOPSIS
    Installs Solr on your machine. 
.DESCRIPTION
    Script to download, unpack and register Solr as a service in your machine. Checks if Java and/or Solr are already installed. 
.PARAMETER solrExtractLocation
    The Path where Solr will be installed 
.PARAMETER solrVersion
     Solr version to download from Apache solr archives. Format is ie "4.10.4", "5.1.0". Must match what is in the archive"
.PARAMETER serviceName
    The name the service running solr will have
.PARAMETER solrCloud
    Boolean indicating if the Solr service should be set up so that solr starts up as a solr cloud instance
.PARAMETER solrCloudHosts
    String of hosts for the solr cloud startup parameter z that indicates to solr which hosts conform the solr cloud ensemble. Include port! Ie hostname:2181,hostname2:2181
.PARAMETER solrCloudThisHost
    String with the hostname that this instance of solrcloud resides on. No need to include port.
.PARAMETER copySitecoreCores
    Boolean specified if Sitecore cores should be copied to the solr installation. 
.EXAMPLE
    C:\PS> install-solr.ps1 -solrExtractLocation C:\solr -solrVersion "5.2.0" -serviceName "Solr" -copySitecoreCores $false
.NOTES
    Author: Diego Saavedra San Juan
    Date:   Many
#>

# Based on https://sitecore-community.github.io/docs/search/solr/fast-track-solr-for-lazy-developers/
# Must be run as system admin

param(
    [Parameter(Mandatory=$true)]
    [string]$solrExtractLocation, #The path where solr will be installed
    [string]$solrVersion="4.10.4",  # Solr version to download from Apache solr archives. Format is ie "4.10.4", "5.1.0". Must match what is in the archive"
    [string]$serviceName="Solr",
    [bool]$asSolrCloud=$false,
    [string]$solrCloudHosts="",
    [string]$solrCloudThisHost="",
    [string]$solrCloudConfName="sitecoreconf",
    #[string]$zookeeperExtractLocation,
    #[string]$zookeeperVersion,
    #[string]$zookeeperServiceName,
    #[string]$zookeeperHostNr,
    #[string]$zookeeperHosts,

    [bool]$copySitecoreCores=$true)



if ($solrExtractLocation -eq $null -or $solrExtractLocation -eq "")
{
    Write-Host "Parameter $solrExtractLocation is mandatory, but it is null or empty" -ForegroundColor Red
    exit 1
}

if ( $asSolrCloud )
{
    if ( ($zookeeperExtractLocation -eq $null -or $zookeeperExtractLocation -eq "" -or (-not (Test-Path $zookeeperExtractLocation))) -or
    ($zookeeperHostNr -eq $null -or $zookeeperHostNr -eq "" ) -or
    ($zookeeperHosts -eq $null -or $zookeeperHosts -eq ""))
    {
        Write-Error "You specified Solr should be installed as a SolrCloud instance, but did not specified required parameters to install it. Check zookeeper parameters etc"
        exit 1
    }    
}

$solrVersionName=$solrVersion
#$solrExtractLocation="D:\"
$filesLocation="..\files"
$solrUrl="http://archive.apache.org/dist/lucene/solr/$solrVersionName/solr-$solrVersionName.zip"
$solrExtractFolder="solr-$solrVersionName"
$solrCleanCores4="$filesLocation\Clean SOLR 4 cores.zip"
$solrCores4Path="$solrExtractLocation\$solrExtractFolder\example\solr"
$solrCleanCores5="$filesLocation\Clean SOLR 5 cores.zip"
$solrCores5Path="$solrExtractLocation\$solrExtractFolder\server\solr"
$solrBinaryLocation="bin\solr.cmd"
$solrServiceName=$serviceName
$solrServiceDisplayName="LiU Sitecore Solr service instance"
$solrServiceDescription="This is the solr service for the LiU implementation of Sitecore. Used by developers on local machines"
$serviceStartupWaitTime=30
$serviceStopWaitTime=20
$solrCheckUrl="http://127.0.0.1:8983/solr"
$solrBinaryFolder="$solrExtractLocation\$solrExtractFolder\bin\"
$nssmName="nssm.exe"
$nssmLocalPath="$nssmName"
$nssmSolrPath="$solrBinaryFolder\$nssmName"
$sevenZipBinaryLocation='C:\Program Files\7-Zip\7z.exe'
$sevenZipArguments=' x ' 


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
Write-Host "Checking if Solr is already installed" -ForegroundColor Cyan
$isSolrServiceInstalled = Get-Service | Where-Object {$_.Name -like "*solr*"}
if ( -not ($isSolrServiceInstalled -eq $null)) 
{
    # Test if upgrading
    Write-Host "Solr is already installed as service named" $isSolrServiceInstalled.Name -ForegroundColor Cyan

    # Get Solr location from service via nssm, to be able to check version
    $allArgs = @('get', $isSolrServiceInstalled.Name, 'Application')
    $nssmLocalCmd = ".\" + $nssmName
    $solrPath = & $nssmLocalCmd $allArgs
    $solrPath= ($solrPath -replace [char] 0, "")[0] # Nssm returns some weird string with 0 coded chars (not spaces, even though they look like them)
    Write-Debug "Solr service is running application at $solrPath"

    if(Test-Path $solrPath)
    {
        $solrPath = $solrPath.Replace("\bin\solr.cmd", "")
        Write-Debug "Will initialize solr-powershell module with solr path $solrPath"
        Import-Module .\solr-powershell.psm1 -Force -ArgumentList @($solrPath) 
        $version = Get-SolrVersion $solrPath        $versionString = $version.major.ToString() + "." + $version.minor.ToString() + "." + $version.revision.ToString()
        if ( $versionString -ne $solrVersion)
        {
            Write-Host "Proceeding to change Solr version from $versionString to $solrVersion" -ForegroundColor Yellow
            Write-Host "Uninstalling version $solrVersion" -ForegroundColor Cyan
            .\uninstall-solr.ps1 -solrExtractLocation $solrPath -solrServiceName $isSolrServiceInstalled.Name
        }
        else
        {
            # Solr already installed in some way
            Write-Host "Solr is already available as a service ("$isSolrServiceInstalled.Name") installed at $solrPath and running version $versionString, you probably have already installed it correctly" -ForegroundColor Green

            # Check if running / Check if our Liu service exists?
            #$isLiUSolrServiceRunning = Get-Service -Name $solrServiceName
            #if ( $isLiUSolrServiceRunning.Status -eq "Running")
            exit 0
        }

        # Check for Solr Cloud / cores and setup accordinly


    }
    else
    {
        # Solr already installed in some way, but not correctly?
        Write-Host "Solr is already available as a service, but the location $solrPath pointed out by the service is missing. Will install it again" -ForegroundColor Yellow
    }
}



# Check java
Write-Host "Checking Java is installed" -ForegroundColor Cyan
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
if(!(Test-Path $nssmLocalPath))
{
    Write-Host "Nssm is not available, won't be able to create the Solr service. It should be at $nssmLocalPath" -ForegroundColor Red
    exit 1
}

# Check admin privilege, won't be able to create the service otherwise
Write-Host "Checking administrator privilege before creating solr service" -ForegroundColor Cyan
if ( -not (Test-Administrator)  )
{ 
    Write-Host "Not running as administrator - won't be able to create the solr service. Please run again as administrator" -ForegroundColor Red
    exit 1
}


Write-Host "Downloading Solr $solrVersionName" -ForegroundColor Cyan
$filename = "$env:temp\solr-$solrVersionName.zip" 
#New-Item $filename -itemType File 
if(!(Test-Path $filename))
{
    Import-Module BitsTransfer
    Start-BitsTransfer -Source $solrUrl -Destination $filename
    #wget $solrUrl -OutFile $filename
}
else 
{
    Write-Host "Solr has already been downloaded" -ForegroundColor Cyan
}

# Kind of hard to get an exit code from wget/Invoke-WebRequest so we just check if the file is there and over 0 size
if(!(Test-Path $filename))
{
    Write-Host "Couldn't download the Solr zip file correctly, check error messages and fix accordingly." -ForegroundColor Red
    exit 1
}


Write-Host "Unpacking Solr to $solrExtractLocation" -ForegroundColor Cyan
#New-Item -ItemType Directory -Force -Path C:\
if(!(Test-Path $solrExtractLocation\$solrExtractFolder\$solrBinaryLocation))
{
    # Check 7-zip, needed to unpack
    if ( -Not( Test-Path $sevenZipBinaryLocation ))
    {
        Write-Host "7-zip doesn't seem to be installed, it couldn't be found at $sevenZipBinaryLocation. You need it to extract the Solr zip file" -ForegroundColor Red
        exit 1
    }

    ## 7-Zip List command parameters
    $argumentlist="$sevenZipArguments $($filename) -o$solrExtractLocation"
    start-process $sevenZipBinaryLocation -argumentlist $argumentlist -wait -Debug #-RedirectStandardOutput $tempfile

    #Expand-Archive $filename -DestinationPath $solrExtractLocation
    Copy-Item -Path $nssmLocalPath -Destination $solrBinaryFolder
}
else 
{
    Write-Host "Solr had already been extracted to $solrExtractLocation" -ForegroundColor Green
}

if(!(Test-Path $solrExtractLocation\$solrExtractFolder\$solrBinaryLocation))
{
    Write-Host "Couldn't extract solr, check error messages and fix accordingly" -ForegroundColor Red
    exit 1
}

if ($asSolrCloud -and ( Test-Path "$solrExtractLocation\$solrExtractFolder\example\solr\collection1"))
{
    Write-Host "Moving dummy collection collection1 to example folder, so SolrCloud mode works" -ForegroundColor Cyan
    Move-Item $solrExtractLocation\$solrExtractFolder\example\solr\collection1 $solrExtractLocation\$solrExtractFolder\example
    Write-Host "Moved dummmy collection collection1 sucessfully" -ForegroundColor Green
}

#if ($asSolrCloud)
#{
#    Write-Host "Checking zookeeper for solrCloud mode installation of Solr" -ForegroundColor Cyan
#    $args = @('-zookeeperExtractLocation',$zookeeperExtractLocation,'zookeeperHosts',$zookeeperHosts,'zookeeperHostNr',$zookeeperHostNr)
#    if ( $zookeeperVersion -ne $null -and $zookeeperVersion -ne "")
#    {
#        $args += "-zookeeperVersion",$zookeeperVersion
#    }
#    if ( $zookeeperServiceName -ne $null -and $zookeeperServiceName-ne "")
#    {
#        $args += "-zookeeperServiceName",$zookeeperServiceName
#    }

    #.\sitecore-machine-setup-tools\install-zookeeper.ps1 -zookeeperExtractLocation $zookeeperExtractLocation -zookeeperHosts $zookeeperHosts -zookeeperHostNr $zookeeperHostNr 
#    $res = .\sitecore-machine-setup-tools\install-zookeeper.ps1 $args 
#    Write-Host "Checking if zookeeper is already installed" -ForegroundColor Cyan
#    $iszookeeperServiceInstalled = Get-Service | Where-Object {$_.Name -like "*zookeeper*"}
#    if ( -not ($iszookeeperServiceInstalled -eq $null) -or $isSolrServiceInstalled.Status -ne "Running")
#    {
#        Write-Host "Zookeper not installed as a service or not running, check want went wrong and try again" -ForegroundColor Red
#        exit 1
#    }
#}


Write-Host "Setting up Solr as a service" -ForegroundColor Cyan

# Doesn't work to use user credentials, must be run as admin. -> PermissionDenied
#New-Service -BinaryPathName "$solrExtracLocation\$solrExtractFolder\$solrBinaryLocation start"  -Credential $env:USERDOMAIN\$env:USERNAME -Name $solrServiceName -DisplayName $solrServiceDisplayName -StartupType Automatic -Description $solrServiceDescription
#New-Service -BinaryPathName "$solrExtractLocation\$solrExtractFolder\$solrBinaryLocation start" -Name $solrServiceName -DisplayName $solrServiceDisplayName -StartupType Automatic -Description $solrServiceDescription -ErrorVariable scErr
# Use nssm to create the service as we are trying to run an exe that is not compiled to be a service. See http://serverfault.com/questions/54676/how-to-create-a-service-running-a-bat-file-on-windows-2008-server
# http://nssm.cc/commands
#$nssmInstallScript = {"$nssmPath install $solrServiceName start -f"}
#$nssmChangeAppDirectory = {"$nssmPath set AppDirectory $solrExtractLocation\$solrExtractFolder\bin"}
#Invoke-Command -ScriptBlock $nssmInstallScript
#Invoke-Command -ScriptBlock $nssmChangeAppDirectory 

$startupParams = "start -f"
if ( $asSolrCloud )
{    
    $reply = Read-Host -Prompt "Setting up Solr service for use with Solr Cloud. Be sure you have installed zookeeper properly, as in, installed and running on ALL instances that will conform the SolrCloud ensemble. Otherwise Solr will no be able to start up. Continue? (Y/N)"
    if ( -not ($reply.ToUpper() -eq "Y"))
    {
        Write-Host "Exiting Solr installation process" -ForegroundColor Cyan
        exit 1
    }

    if ( $solrCloudHosts -eq $null -or $solrCloudHosts -eq "" )
    {
        Write-Host "You need to provide hosts for the solr cloud startup parameters" -ForegroundColor Red
        exit 1
    }
    $startupParams = "'" + $startupParams + " -c -h " + $solrCloudThisHost + ' -z ""' + $solrCloudHosts + '""' + "'"
    Write-Host "Solr startup params created, set to: $startupParams" -ForegroundColor Yellow
}

$res = Start-Process $nssmSolrPath -ArgumentList "install $solrServiceName $solrExtractLocation\$solrExtractFolder\$solrBinaryLocation" -Wait -NoNewWindow -PassThru
$res2 = Start-Process $nssmSolrPath -ArgumentList "set $solrServiceName AppDirectory $solrExtractLocation\$solrExtractFolder\bin" -Wait -NoNewWindow -PassThru
#$res2 = Start-Process $nssmSolrPath -ArgumentList "set $solrServiceName AppParameters $startupParams" -Wait -NoNewWindow -PassThru
$all = $nssmSolrPath + " " + " set " + $solrServiceName + " AppParameters " + $startupParams
Invoke-Expression $all

Start-Sleep 2
Start-Service -Name $solrServiceName

Write-Host "Checking if Solr service was created correctly" -ForegroundColor Cyan
$isSolrRunning = Get-Service | Where-Object {$_.Name -like "*solr*"}
if ( $isSolrRunning -eq $null ) 
{ 
    Write-Host "Something went wrong setting up the service, it is not listed in the service list" -ForegroundColor Red
    exit 1
}


Write-Host "Waiting $serviceStartupWaitTime seconds to check if Solr started correctly" -ForegroundColor Cyan
Start-Sleep $serviceStartupWaitTime
# Check that the service is effectively running 
wget $solrCheckUrl -OutVariable solrCheckResult > $null
if($solrCheckResult.StatusCode -eq $null -or ! $solrCheckUrl -eq 200 )
{
    Write-Host "Something is wrong with the solr service, please check service creation" -ForegroundColor Red
    exit 1
}
Write-Host "Solr is running correctly" -ForegroundColor Green

# Copy cores
if($copySitecoreCores)
{
    Write-Host "Copying Sitecore cores to Solr installation" -ForegroundColor Cyan
    $continue = $true
    if ( $asSolrCloud )
    {
        $reply = Read-Host -Prompt "You specifed to copy Sitecore cores AND set Solr as a SolrCloud ensemble, which is contradictory. Do you really want to copy the Sitecore cores? (Y/N)"
        if ( -not ($reply.ToUpper() -eq "Y"))
        {
            $continue = $false
        }            
    }

    if ($continue )
    {

	    if(-not (Test-Path $solrCleanCores))
	    { 
    		Write-Host "Solr clean cores package not found, make sure the package is correctly configured" -ForegroundColor Red
		    exit 1
	    }

    	Write-Host "Unpacking clean solr Sitecore cores" -ForegroundColor Cyan
    	if(!(Test-Path "$solrCoresPath\sitecore_core_index"))
    	{            
            $solrPath = "$solrExtractLocation\$solrExtractFolder"
            Write-Debug "Will initialize solr-powershell module with solr path $solrPath"
            Import-Module .\solr-powershell.psm1 -Force -ArgumentList @($solrPath) 
            $version = Get-SolrVersion $solrPath           

            if ( $version.major -eq 4)
		    {
                Expand-Archive $solrCleanCores4 -DestinationPath $solrCores4Path
            }
            else
            {
                Expand-Archive $solrCleanCores5-DestinationPath $solrCores5Path
            }

    		if(!(Test-Path "$solrCoresPath\sitecore_core_index"))
    		{
    			Write-Host "Couldn't extract solr cores, check error messages and fix accordingly" -ForegroundColor Red
    			exit 1
    		}

		    Write-Host "Correctly unpacked Sitecore solr cores" -ForegroundColor Green


    		# Restart Solr to re-read cores
    		Write-Host "Restarting Solr service to re read cores" -ForegroundColor Cyan
    		Stop-Service -Name $solrServiceName
    		Start-Sleep $serviceStopWaitTime
    		Start-Service -Name $solrServiceName
    		Write-Host "Done restarting" -ForegroundColor Green

    	}
    	else 
    	{
		    Write-Host "Solr cores already installed in $solrCoresPath" -ForegroundColor Green
	    }

        
    }
}

if ( $createSitecoreCollections )
{
    Write-Host "Creating Sitecore Collections" -ForegroundColor Cyan
    $continue = $true
    if ( -not $asSolrCloud )
    {
        $reply = Read-Host -Prompt "You specifed you want to create Sitecore collections but did not install Solr as SolrCloud, are you sure you want me to try anyway? (Y/N)"
        if ( -not ($reply.ToUpper() -eq "Y"))
        {
            $continue = $false
        }    
    }

    if ($continue)
    {   
        # automatically get replication factor from host list     
        $replicationFactor = 1
        if ( $solrCloudHosts.Contains(","))
        {
            $replicationFactor = $solrCloudHosts.Split(",").Count
        }        

        .\sitecore-solr-cores-creation.ps1 -command create -solrPath $solrExtractLocation\$solrExtractFolder -configName $solrCloudConfName -shards 1 -replicationFactor $replicationFactor 
    }

}


Write-Host "Solr installed correctly" -ForegroundColor Green
exit 0