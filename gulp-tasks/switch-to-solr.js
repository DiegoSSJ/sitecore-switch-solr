/*jslint node: true */
"use strict";

var gulp = require("gulp");
var build = require("../build.js");
var config = build.config;
var powershell = require("../modules/powershell");
var path = require("path");
var fs = require("fs")

gulp.task("switch-to-solr", function (callback) {
  build.logEvent("builder", "Installing Solr version " + config.solrVersion);
  var psFile = path.join(path.dirname(fs.realpathSync(__filename)), "../powershell-scripts/install-solr.ps1");
  powershell.runAsync(psFile, " -sitecoreVersion '" + build.sitecoreVersion + "'" + " -webRootPath " + config.websiteRoot + " -packageLocation " + build.packageSourceLocation + " -packageName " + build.packageName, callback);
  build.logEvent("builder", "Switching Sitecore instance on  " + config.websiteRoot " to use Solr");
  var psFile = path.join(path.dirname(fs.realpathSync(__filename)), "../powershell-scripts/configure-sitecore-solr.ps1");
  powershell.runAsync(psFile, " -sitecoreVersion '" + build.sitecoreVersion + "'" + " -webRootPath " + config.websiteRoot + " -packageLocation " + build.packageSourceLocation + " -packageName " + build.packageName, callback);
});
