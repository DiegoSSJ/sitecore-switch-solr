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

It then provides a task called ```setup-solr``` that can be run from your solution's gulp file. The task should be run as administrator user (to create the Solr service)

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
gulp swith-to-solr
```

##Gulp task parameters

The gulp tasks expects two parameters in the solution-config.json file. These parameters go in the "configs" variable, and are named "websiteRoot" and "solrExtractLocation". For example:
```
{
  "configs": [
    {
      "websiteRoot": "c:\\websites\\Your.Website\\Website",
      "solrExtractLocation":  "C:\\"
    }
  ]
}
```

The Website folder should include all the Sitecore Website files, more specifically, the bin and App_config folder are expected to be there. 
 