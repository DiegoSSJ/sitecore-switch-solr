
param(   
    [Parameter(Mandatory=$true)]
    [string]$solrPath      # The path to the Solr installation. Needed to locate the solr.cmd file to run collection creation on Solr 5+
    )

if ((get-pscallstack |select -last 2 |select -expand arguments -first 1) -match "verbose"){$verbosepreference="continue"}
if ((get-pscallstack |select -last 2 |select -expa arguments -first 1) -match "debug"){ $debugpreference="continue"}
        
$prot = "http://"
$hostname="localhost"
$defaultZkPort="2181"
$defaultSolrPort="8983"
$collectionWebApiPath="/solr/admin/collections"
$actionVerb = "action"

$correctlyInitialized = $false

if ( $solrPath -eq $null -or  $solrPath -eq "" )
{
    Write-Error "Solr Path not given as argument to the module, initalization failed"
    return
}

if ( -Not (Test-Path $solrPath) )
{
    Write-Error "Solr directory not found at $solrPath"
    return
}


$solrVersion = "5"

Function Get-SolrVersion 
{
    Param ( 
        [Parameter(Mandatory=$True)]
        [string]$solrPath)      
    $version = new-object psobject
    Add-Member -InputObject $version -MemberType NoteProperty -Name major -Value ""
    Add-Member -InputObject $version -MemberType NoteProperty -Name minor -Value ""
    Add-Member -InputObject $version -MemberType NoteProperty -Name revision -Value ""
    if ( Test-Path "$solrPath\dist\solr-4*.war" )
    {
        $version.major = 4;
        $solrWarVersionPart = (Get-Item "$solrPath\dist\solr-4*.war").Name.Split("-")[1]
        $solrWarVersion = $solrWarVersionPart.Substring(0, $solrWarVersionPart.IndexOf(".war"))
        $version.minor = $solrWarVersion.Split(".")[1]
        $version.revision = $solrWarVersion.Split(".")[2]             
    }
    if ( Test-Path "$solrPath\dist\solr-core-*.jar" )
    {
        $solrJarVersionPart = (Get-Item "$solrPath\dist\solr-core-*.jar").Name.Split("-")[2]
        $solrJarVersion = $solrJarVersionPart.Substring(0, $solrJarVersionPart.IndexOf(".jar"))
        $version.major = $solrJarVersion.Split(".")[0]
        $version.minor = $solrJarVersion.Split(".")[1]
        $version.revision = $solrJarVersion.Split(".")[2]
    }  
    return $version;  
}

$solrVersion = Get-SolrVersion $solrPath

if ( $solrVersion.major -lt 4 -or $solrVersion.major -gt 6 )
{
    Write-Error "Wrong solr version found"
    return
}


$solrCmd=$solrPath+"\bin\solr.cmd"

if ( -Not ( Test-Path $solrCmd ) )
{
    Write-Error "Solr.cmd does not exist in path: " $solrCmd
    exit 1
}

$correctlyInitialized = $true


Function Create-Collection-Web-Api-Request 
{
    Param ( 
        [Parameter(Mandatory=$True)]
        [string]$action,
        [string]$params)
    return $prot + $hostname + ":" + $defaultSolrPort + $collectionWebApiPath + "?" + $actionVerb + "=" + $action + $params;
}

Function Check-Collection-Exists {
	Param(
		[Parameter(Mandatory=$True)]
		[string]$collectionName,

		[string]$zkHost = 'localhost:2181'	
	)

    Write-Verbose "Checking if collection $collectionName exists"
    if ( $solrVersion -gt 4 )
    {
        Write-Debug "Checking collection on Solr 5+"
        $allArgs = $allArgs = @('healthcheck', '-c',$collectionName, '-z', $zkHost)
        $res = & $solrCmd $allArgs
        if ( $res -eq $null -or $res -eq "" )
        {
            return $false
        }
        else 
        {
            return $true
        }
    }
    else
    {
        Write-Debug "Check runs on Solr 4"
        $wgetRequest = Create-Collection-Web-Api-Request("LIST")        
        Write-Debug "Wget request is: $wgetRequest"
        $res = wget $wgetRequest
        if ($res.StatusCode -ne 200)
        {
            Write-Error "Error checking collection $collectionName via WEB API. Page contents: ${res.Content}"
        }
        if ( $res.Content.Contains($collectionName))
        { return $true }
        return $false
    }
}

Function Create-Collection {
	Param(
		[Parameter(Mandatory=$True)]
		[string]$collectionName,
        [string]$confdir="data_driven_schema_configs",
        [Parameter(Mandatory=$True)]
        [string]$configName,
        [string]$shards = "1",
        [string]$replicationFactor = "3"
	)

    Write-Verbose "Creating collection $collectionName"

    if ( $collectionName -eq $null -or $collectionName -eq "" )
    {
        Write-Error "Collection Name may not be empty"
        return $false;
    }

    if ( $configName -eq $null -or $configName -eq "" )
    {
        Write-Error "Configuration Name may not be empty"
        return $false;
    }


    Write-Debug "Creating collection $collectionName with configuration $configName for $shards shards and replication factor of $replicationFactor"
    if ( $solrVersion -gt 4 )
    {
        # Create collections via command line
        Write-Debug "Creating collection for a Solr instance newer or equal to version 5"
        $solrExpression = $solrCmd + " create_collection " + " -c " + $collectionName
        if ( (-not $confdir -eq $null) -and (-not $confdir -eq ""))
            { $solrExpression = $solrExpression + " -d " + $confdir }
        if ( (-not $configName -eq $null) -and (-not $configName -eq ""))
            { $solrExpression = $solrExpression + " -n " + $configName  }
        $solrExpression =  $solrExpression + " -n " + $configName + " -shards " +  $shards + " -replicationFactor "  + $replicationFactor
        Invoke-Expression $solrExpression
    }
    else 
    {
        # Create collections via web api
        Write-Debug "Creating collection for a Solr instance running Solr version 4"
        
        
        $wgetParams = "&name=$collectionName"
        $wgetParams += "&numShards=$shards"
        $wgetParams += "&replicationFactor=$replicationFactor"
        $wgetParams += "&collection.configName=$configName"
        $wgetRequest = Create-Collection-Web-Api-Request "CREATE" $wgetParams
        #$res = wget "http://localhost:8983/solr/admin/collections?action=CREATE&name=$collectionName&numShards=$shards&replicationFactor=$replicationFactor&collection.configName=$configName"
        $res = wget $wgetRequest
        if ($res.StatusCode -ne 200)
        {
            Write-Error "Error creating collection $collectionName via WEB API. Page contents: ${res.Content}"
        }
    }
    return $true
}

Function Delete-Collection {
	Param(
		[Parameter(Mandatory=$True)]
		[string]$collectionName,
        [string]$deleteConfig="",
        [string]$port=""
	)

    Write-Verbose "Deleting collection $collectionName"
    
    if ( $solrVersion -gt 4 )
    {
        Write-Debug "Deleting collection for a Solr instance running Solr version 5+"
        $solrExpression = $solrCmd + " delete " + " -c " + $collectionName
        if ( -Not ( $deleteConfig -eq "") )
        {
            $solrExpression += " -deleteConfig " + $deleteConfig
        }

        if ( -Not ( $port -eq "") )
        {
            $solrExpression += " -p " + $port
        }

        Invoke-Expression $solrExpression
    }
    else 
    {
        # Delete collections via web api                 
        Write-Debug "Deleting collection for a Solr instance running Solr version 4"
        $wgetParams += "&name=$collectionName"
        $wgetRequest = Create-Collection-Web-Api-Request "DELETE" $wgetParams
        $res = wget $wgetRequest
        if ($res.StatusCode -ne 200)
        {
            Write-Error "Error deleting collection $collectionName via WEB API. Page contents: $(res.Content)"
        }
    }
}

Function Create-Collection-Configuration {
    Param(
	    [Parameter(Mandatory=$True)]
    	[string]$configurationName,
        [Parameter(Mandatory=$True)]
        [string]$configurationPath="",
        [string]$port=""
    	)

    Write-Verbose "Creating collection configuration $configurationName from configuration stored at $configurationPath"

    if ( !(Test-Path $configurationPath))
    {
        Write-Error "Path to configuration ($configurationPath) does not exist, quitting"
        return
    }

    if ( $solrVersion -gt 4 )
    {
        Write-Debug "Creating configuration on a solr 5+ instance"
        # Create file-based dummy collection with new configuration
        Write-Debug "Creating configuration by creating a dummy collection"
        $solrExpression = $solrCmd + " create_collection " + " -c dummy -d " + $configurationPath + " -n " + $configurationName         
        Invoke-Expression $solrExpression

        # Delete dummy collection
        Write-DEbug "Erasing dummy collection"
        $solrExpression = $solrCmd + " delete -c dummy -deleteConfig=false"
        Invoke-Expression $solrExpression

        Write-Debug "Finished"
    }
    else
    {
        Write-Debug "Creating configuration on a solr 4 instance"
        # Stop solr if running
        $isSolrServiceInstalled = Get-Service | Where-Object {$_.Name -like "*solr*"}

        $isSolrServiceInstalled.Stop()

        Start-Sleep -Seconds 5

        # Start solr standalone with import conf
        #java -DnumShards=1 -Dbootstrap_confdir=./solr/collection1/conf -Dcollection.configName=sitecoreconf -DzkHost=node1.host:2181,node2.host:2181,node3.host:2181 -jar start.jar
        $res = Start-Process "java" -WorkingDirectory $solrPath\example -ArgumentList "-numShards=1 -Dbootstrap_confdir=$configurationPath -Dcollection.configName=$configurationName -jar start.jar" -Wait -PassThru -NoNewWindow

        # Start Solr again
        $isSolrServiceInstalled.Start()
    }    
}


Export-ModuleMember -Function Create-Collection
Export-ModuleMember -Function Delete-Collection
Export-ModuleMember -Function Check-Collection-Exists
Export-ModuleMember -Function Get-SolrVersion

