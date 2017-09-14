
# Enable lucene config files in Sitecore App_Config/Include
Write-Host "Enabling Lucene config files in the App_Config folder of the website" -ForegroundColor Cyan
if(!(Test-Path $websiteAppConfigIncludeFolder))
{
    Write-Host "Website App_Config\Include folder not found, error in parameters?" -ForegroundColor Red
    exit 1
}

# Reference - should be fixed to handle example files and keep .config?
$luceneFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Lucene*"
$luceneConfigFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Lucene*.config"
$luceneDisabledConfigFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Lucene*.config.disabled*"

if($luceneFilesFound.Count -eq 0)
{
    Write-Host "No Lucene files found, wrong Sitecore installation?" -ForegroundColor Red
    exit 1
}

if($luceneDisabledConfigFilesFound.Count -eq 0)
{
    Write-Host "No disabled Lucene config files found, good. Continuing to next step"    
}
else
{
    ForEach ( $configFile in $luceneDisabledConfigFilesFound )
    {
        $configFileDisabledName = $configFile -replace "[.]config",".disabledbyscript"       
        $configFileDisabledNameOnly = $configFile -replace "[.]config",".disabledbyscript"       
        $configFileDisabledName = $configFileDisabledName -replace ".*\\",""
        Write-Host "Renaming $websiteAppConfigIncludeFolder\$configFile to $configFileDisabledName"
        Write-Host "checking if $websiteAppConfigIncludeFolder\$configFileDisabledNameOnly already exists"
        if ( Test-Path $websiteAppConfigIncludeFolder\$configFileDisabledNameOnly)
        {
            Write-Host "Renamed file already exist, deleting original instead"
            rm $websiteAppConfigIncludeFolder\$configFile
        }
        else
        {
            Rename-Item $websiteAppConfigIncludeFolder\$configFile $configFileDisabledName
        }
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


# Disable Solr config files in Sitecore App_Config/Include

Write-Host "Enabling Lucene config files"

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
        $configFileEnabledNameOnly = $configFile -replace "[.]config[.]disabled",".config"
        # Rename-Item expects just the new name as second parameter, so we have to remove the relative path
        $configFileEnabledName = $configFileEnabledName -replace ".*\\",""
        if ( -not ( Test-Path $websiteAppConfigIncludeFolder\$configFileEnabledNameOnly ))
        {
            Write-Host "Renaming $websiteAppConfigIncludeFolder\$configFile to $configFileEnabledName"
            Rename-Item $websiteAppConfigIncludeFolder\$configFile $configFileEnabledName
        }
        else 
        {
            Write-host "File is already enabled, deleting disabled instead ($websiteAppConfigIncludeFolder\$configFileEnabledNameOnly)"
            Remove-Item $websiteAppConfigIncludeFolder\$configFileEnabledNameOnly
        }
    }

    ForEach ( $configFile in $solrConfigExampleFilesFound )
    {
        if ( (-not $useRebuild) -and $configFile.Contains("SwitchOnRebuild"))
        { 
            Write-Host "Skipping SwitchOnRebuild due to useRebuild being false"
            continue 
        }
        elseif ( $useRebuild -and $configFile.Contains("SwitchOnRebuild"))
        {
            $reply = Read-Host "Enabling SwitchOnRebuild Make sure you created the needed cores/collections (MainAlias/RebuildAlias/rebuild). Do you want to enable it? (Y/N)"
            if ( $reply.ToUpper() -eq "N")
            {
                Write-Host "Skipping enabling SwitchOnRebuild"
                continue
            }

            # Not tested and EnforceAliasCreation setting doesn't seem to work, at least in Sitecore 8.2rev2
            #if ( $useAutomaticRebuildCollectionCreation )
            #{
            #       [xml]$XmlDocument = Get-Content -Path  $websiteAppConfigIncludeFolder\$configFile
            #       $XmlDocument.ForEach( { if ( $_.name -match "EnforceAliasCreation" ) { $_.value = "true" } } )
            #       $XmlDocument.Save($websiteAppConfigIncludeFolder+"\"+$configFile)
            #}
        }
        
        
        $configFileEnabledName = $configFile -replace "[.]example",""
        $configFileEnabledNameOnly = $configFile -replace "[.]example",""
        # Rename-Item expects just the new name as second parameter, so we have to remove the relative path
        $configFileEnabledName = $configFileEnabledName -replace ".*\\",""

        if ( -not ( Test-Path $websiteAppConfigIncludeFolder\$configFileEnabledNameOnly ))
        {
            Write-Host "Renaming $websiteAppConfigIncludeFolder\$configFile to $configFileEnabledName"
            Rename-Item $websiteAppConfigIncludeFolder\$configFile $configFileEnabledName
        }
        else 
        {
            Write-host "File is already enabled, deleting example ($websiteAppConfigIncludeFolder\$configFileEnabledNameOnly)"
            Remove-Item $websiteAppConfigIncludeFolder\$configFileEnabledNameOnly
        }

    }

    $solrDisabledConfigFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Solr*.config.disabled"
    $solrExampleConfigFilesFound = Get-ChildItem $websiteAppConfigIncludeFolder -name -rec -filter "*Solr*.config.example"
    if($solrDisabledConfigFilesFound.Count -gt 0  -and 
    (($useRebuild -and $solrExampleConfigFilesFound.Count -gt 0) -or (-not $useRebuild -and $solrExampleConfigFilesFound.Count -gt 1)))
    {
        Write-Host "Something went wrong enabling Solr config files, there are still some left disabled/exampled" -ForegroundColor Red
        exit 1
    }

    Write-Host "Enabling Solr config files sucessful"
}
