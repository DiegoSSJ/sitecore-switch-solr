param(    
    [Parameter(Mandatory=$true)]
    [string]$solrExtractLocation,
	[Parameter(Mandatory=$true)]
    [string]$webRootPath)


if ($solrExtractLocation -eq $null -or $solrExtractLocation -eq "")
{
    Write-Host "Parameter $solrExtractLocation is mandatory, but it is null or empty"
    exit 1
}


if ($webRootPath -eq $null -or $webRootPath -eq "")
{
    Write-Host "Parameter webRootPath is mandatory, but it is null or empty"
    exit 1
}

# Ex.
#$solrExtractLocation="D:\"
#$webRootPath="C:\websites\LiU.local-solr\Website"


# Constant parameters
$solrServiceName="LiUSitecoreSolr"
# We don't let this be a parameter since the article this is based on explicitly explains there are problems with other (newer) Solr versions.
# Until or if those problems are addressed in these scripts, then we could accept this as parameter (with validation of correct version).
$solrVersionName="4.10.4"                                
                                                         

$solrExtractFolder="solr-$solrVersionName"

$serviceStopWaitTime=5

$filesLocation="..\files"
$microsoftUnityDllName="Microsoft.Practices.Unity.dll"
$microsoftUnityDllLocation="$filesLocation\\$microsoftUnityDllName"
$globalAsax="$filesLocation\Global.asax"
$sitecoreSolrDllsPackageName="$filesLocation\Sitecore.Solr.Support 1.0.0 rev. 160504.zip"


$websiteAppConfigIncludeFolder="$webRootPath\App_Config\Include"





# Disable lucene config files in Sitecore App_Config/Include
Write-Host "Disabling Lucene config files in the App_Config folder of the website"

if(!(Test-Path $websiteAppConfigIncludeFolder))
{
    Write-Host "Website App_Config\Include folder not found, error in parameters?" -ForegroundColor Red
    exit 1
}

# Reference - should be fixed to handle example files and keep .config?
$luceneFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Lucene*"
$luceneConfigFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Lucene*.config"

if($luceneFilesFound.Count -eq 0)
{
    Write-Host "No Lucene files found, wrong Sitecore installation?" -ForegroundColor Red
    exit 1
}

if($luceneConfigFilesFound.Count -eq 0)
{
    Write-Host "No enabled Lucene config files found, good. Continuing to next step"    
}
else
{
    ForEach ( $configFile in $luceneConfigFilesFound )
    {
        $configFileDisabledName = $configFile -replace "[.]config",".disabledbyscript"
        $configFileDisabledName = $configFileDisabledName -replace ".*\\",""
        Write-Host "Renaming $websiteAppConfigIncludeFolder\$configFile to $configFileDisabledName"
        Rename-Item $websiteAppConfigIncludeFolder\$configFile $configFileDisabledName
    }

    $luceneConfigFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Lucene*.config"
    if($luceneConfigFilesFound.Count -gt 0 )
    {
        Write-Host "Something went wrong disabling Lucene config files, there are still some left" -ForegroundColor Red
        exit 1
    }

    Write-Host "Disabling Lucene config files sucessful"
}


#@Echo OFF

#Set "Pattern=Lucene"

#For /R ".\" %%i in (*.config) Do (
#    Echo %%i | FIND "%Pattern%" 1>NUL && (
#        Echo Disabled: %%i
#        ren "%%i" "%%~ni.disabledbyscript"
#        REM Echo FileName : %%~nx#
#        REM Echo Directory: %%~p#
#    )
#)



# Enabe Solr config files in Sitecore App_Config/Include

Write-Host "Enabling Solr config files"

# Reference - should be fixed to handle example files and keep .config?
$solrFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Solr*"
$solrConfigDisabledFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Solr*.config.disabled"
$solrConfigExampleFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Solr*.config.example"
$solrConfigFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Solr*.config*"

if($solrFilesFound.Count -eq 0)
{
    Write-Host "No Solr files found, wrong Sitecore installation?" -ForegroundColor Red
    exit 1
}


if($solrConfigDisabledFilesFound.Count -eq 0 -and $solrConfigExampleFilesFound.Count -eq 0)
{
    Write-Host "No Solr disabled or example config files found, good, continuing"
}
else
{
    ForEach ( $configFile in $solrConfigDisabledFilesFound )
    {
        $configFileEnabledName = $configFile -replace "[.]config[.]disabled",".config"
        # Renama-Item expects just the new name as second parameter, so we have to remove the relative path
        $configFileEnabledName = $configFileEnabledName -replace ".*\\",""
        Write-Host "Renaming $websiteAppConfigIncludeFolder\$configFile to $configFileEnabledName"
        Rename-Item $websiteAppConfigIncludeFolder\$configFile $configFileEnabledName
    }

    ForEach ( $configFile in $solrConfigExampleFilesFound )
    {
        $configFileEnabledName = $configFile -replace "[.]example",""
        # Rename-Item expects just the new name as second parameter, so we have to remove the relative path
        $configFileEnabledName = $configFileEnabledName -replace ".*\\",""
        Write-Host "Renaming $websiteAppConfigIncludeFolder\$configFile to $configFileEnabledName"
        Rename-Item $websiteAppConfigIncludeFolder\$configFile $configFileEnabledName
    }

    $solrDisabledConfigFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Solr*.config.disabled"
    $solrExampleConfigFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Solr*.config.example"
    if($solrDisabledConfigFilesFound.Count -gt 0  -and $solrExampleConfigFilesFound.Count -gt 0)
    {
        Write-Host "Something went wrong enabling Solr config files, there are still some left disabled/exampled" -ForegroundColor Red
        exit 1
    }

    Write-Host "Enabling Solr config files sucessful"
}


# Reference - fix same as with lucene (it does manage example some way)

#@Echo OFF

#Set "Pattern=Solr"

#For /R ".\" %%i in (*.disabled) Do (
#    Echo %%i | FIND "%Pattern%" 1>NUL && (
#        Echo Enabled: %%i
#        ren "%%i" "%%~ni.config"
#    )
#)

#For /R ".\" %%i in (*.example) Do (
#    Echo %%i | FIND "%Pattern%" 1>NUL && (
#        Echo Enabled: %%i
#        ren "%%i" "%%~ni.config"
#    )
#)



# Copy Sitecore Solr dlls
if(!(Test-Path $sitecoreSolrDllsPackageName))
{
    Write-Host "Sitecore Solr dlls package not found, make sure the package is correctly configured" -ForegroundColor Red
    exit 1
}

Write-Host "Unpacking Sitecore Solr dlls"
if(!(Test-Path $webRootPath\bin\Sitecore.ContentSearch.SolrProvider.dll))
{
    Expand-Archive $sitecoreSolrDllsPackageName -DestinationPath $webRootPath
    if(!(Test-Path "$webRootPath\bin\Sitecore.ContentSearch.SolrProvider.dll"))
    {
        Write-Host "Couldn't find Sitecore Solr dlls after unzipping, check error messages and fix accordingly" -ForegroundColor Red
        exit 1
    }

    Write-Host "Correctly unpacked Sitecore Solr dlls"    
}
else 
{
    Write-Host "Sitecore Solr dlls already installed"
}

# Copy Unity dll
if(!(Test-Path $webRootPath\bin\$microsoftUnityDllName))
{
    Write-Host "Copying Microsoft Unity dll to $webRootPath\bin..." -NoNewline
    Copy-Item $microsoftUnityDll $webRootPath\bin
    Write-Host "Done"
}
else
{
    Write-Host "Microsoft Unity dll already in $webRootPath\bin, good. Continuing"
}

# Copy Global.asax
Write-Host "Copying Global.asax to $webRootPath... " -NoNewline
Copy-Item $globalAsax $webRootPath
Write-Host "Done"

# TODO: Trigger index rebuild automatically -> Could be done with Sitecore Powershell extensions (remote) if they are installed. See 
# http://blog.najmanowicz.com/2014/10/10/sitecore-powershell-extensions-remoting/ and 
# https://sitecorepowershell.gitbooks.io/sitecore-powershell-extensions/content/remoting.html
# and to run the update index command:  https://sitecorepowershell.gitbooks.io/sitecore-powershell-extensions/content/appendix/commands/Initialize-SearchIndex.html

Write-Host "Sitecore switch to Solr complete" -ForegroundColor Green
Write-Host "Remember to rebuild the indexes to actually switch Sitecore indexes to Solr!" -ForegroundColor Yellowexit 0