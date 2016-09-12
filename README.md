#Sitecore switch to Solr npm gulp package

Provides a gulp task that installs Solr 4.10.4 and switches a Solr 8.1 installation to use it. Creates the needed Sitecore cores in the Solr installation.


Based on the great installation instructions from the sitecore community documentation at
https://sitecore-community.github.io/docs/search/solr/fast-track-solr-for-lazy-developers/


##Usage

This npm package is intended to be included from a Sitecore Habitat project. It is included via package.json like this:

```
  "dependencies": {    
    "sitecore-switch-solr": "^1.0.0"
  }
```

Then it gets installed with ```npm install```

It then provides a task called ```setup-solr``` that can be run from your solution's gulp file. It runs two different subtasks, one to install solr and configure the Sitecore cores, and another
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
gulp switch-to-solr
```


##Gulp task parameters

The gulp tasks expects two parameters in the solution-config.json file. These parameters go in the "configs" variable, and are named "websiteRoot" and "solrExtractLocation". For example:
```
{
  "configs": [
    {
      "name": "Debug",
      "rootFolder": "c:\\websites\\Your.Website",
      "websiteRoot": "c:\\websites\\Your.Website\\Website",
      "hostName": "Your.Website",
      "solrExtractLocation":  "C:\\"
    }
  ]
}
```

The Website folder should include all the Sitecore Website files, more specifically, the bin and App_config folder are expected to be there. 
 