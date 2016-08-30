/*jslint node: true */
"use strict";

var gulp = require("gulp");
var build = require("../build.js");
var config = build.config;
var powershell = require("../modules/powershell");
var path = require("path");
var fs = require("fs")

gulp.task("switch-to-solr", function (callback) {
  build.logEvent("builder", "Installing Solr 4.10.4");
  
  // Can be done with gulp-run? https://www.npmjs.com/package/gulp-run
  var taskDir = path.dirname(fs.realpathSync(__filename));
  var psFile = path.join(taskDir, "../powershell-scripts/install-solr.ps1");
  var result = powershell.runSync(psFile, " -solrExtractLocation " + config.solrExtractLocation, path.join(taskDir, "../powershell-scripts"), callback);
  if (result.status > 0)
  {
    build.LogEvent("builder", "Installing Solr failed, quitting")
    process.exit()
  }    
  build.logEvent("builder", "Switching Sitecore instance on  " + config.websiteRoot + " to use Solr");
  var psFile = path.join(taskDir, "../powershell-scripts/configure-sitecore-solr.ps1");
  var result = powershell.runSync(psFile, " -webRootPath " + config.websiteRoot + " -solrExtractLocation " + config.solrExtractLocation, path.join(taskDir, "../powershell-scripts"), callback);
  if (result.status > 0) {
    build.LogEvent("builder", "Configuring Solr failed, quitting")
    process.exit()
  }
});
