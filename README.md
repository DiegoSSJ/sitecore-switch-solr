# Sitecore switch to Solr npm gulp package

Provides gulp tasks for installation and configuration of both Solr and Sitecore to work with each other. 
It supports several versions of Sitecore and Solr and can work with both Solr standalone and SolrCloud. 



Based on the great installation instructions from the sitecore community documentation at
https://sitecore-community.github.io/docs/search/solr/fast-track-solr-for-lazy-developers/


## Usage

This npm package is intended to be included from a Sitecore Habitat project. It is included via package.json like this:

```
  "dependencies": {    
    "sitecore-switch-solr": "^2.0.1"
  }
```

Then it gets installed with ```npm install```

It then provides a task called ```setup-solr``` that can be run from your solution's gulp file. It runs two different subtasks, one to install solr and configure the Sitecore cores/colletions, and another
to switch the Sitecore instance so that it uses Solr instead of Lucene, by enabling/disabling configuration files, copying the needed DLLs and modifying Global.asax. 
The Solr installation task has to be run as administrator user (to create the Solr service), so the ```setup-solr``` has also to be run as administrator. 

You can include it in your project setup like this:
```
var buildtasks = require('./node_modules/sitecore-switch-solr/gulpfile.js');
gulp.task("00-Setup-Development-Environment", function (callback) {
  runSequence(    
    "setup-solr")
	})
```

Or run it manually from gulp

```
gulp setup-solr
```

```
gulp install-solr
```

```
gulp sitecore-switch-to-solr
```


## Gulp task parameters

The gulp tasks expects a minium of three parameters in the solution-config.json file. Two of these parameters go in the "configs" section, and are named "websiteRoot" and "solrExtractLocation" and the third go in the "sitecore" section and is called "version". For example:
```
{
  "sitecore": {
    "version": "8.2.161221",
  },

  "configs": [
    {
      "name": "Debug",
      "rootFolder": "c:\\websites\\Your.Website",
      "websiteRoot": "c:\\websites\\Your.Website\\Website",
      "hostName": "Your.Website",
      "solrExtractLocation":  "C:\\",
    }
  ]
}
```

The solrExtractLocation path specified where solr will be extracted and the webSitecore is the path to the webroot for the Sitecore instance. The Sitecore version should match the format seen in the example, but right now only the major and minor are used, and only Sitecore 8.1 and 8.2 are supported.

The Website folder should include all the Sitecore Website files, more specifically, the bin and App_config folder are expected to be there. 

Aditionally the following configuration parameters should be used to specify your configuration needs:
```
configs -> config 
	-> solrVersion: Should be in the format that Solr is versioned, and should match a existing Solr Version. Ex: "5.1.0", "4.10.0", "6.5.0". Check Solrs download page for versions.
	-> asSolrcloud: Install Solr ready to be used as a Solr Cloud instance. Creates configuration and collections. You have to specify solrCloudHosts and solrCloudThisHost for this to work. The content doesn't matter, it should just be set to something.
	-> solrCloudHosts: List of Solr instances that will conform the SolrCloud ensemble. The list should be comma separated and include only hostname with port. See example below
	-> solrCloudThishost: The hostname for the host that is actually being configured. No need to specify port. 
```

Example of all configuration variables:
```
{
  "sitecore": {
    "version": "8.2.161221",
  },

  "configs": [
    {
      "name": "Debug",
      "rootFolder": "c:\\websites\\Your.Website",
      "websiteRoot": "c:\\websites\\Your.Website\\Website",
      "hostName": "Your.Website",
      "solrExtractLocation":  "C:\\",
      "solrVersion": "5.1.0",
      "asSolrCloud": "yes",
      "solrCloudHosts": "hostname1:2181,hostname2:2181"
      "solrCloudThisHost": "hostname1"
    }
  ]
}
```
 
 ** Please note it is up to the user to match Sitecore version and Solr version accordingly. We only provide suitable cores for Solr 4 and Solr 5, plus collection configuration for Solr5. See https://kb.sitecore.net/articles/227897 ** 
 
 