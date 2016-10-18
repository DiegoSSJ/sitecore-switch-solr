/*jslint node: true */
"use strict";

var gulp = require("gulp");
var build = require("../build.js");
var config = build.config;
var powershell = require("../modules/powershell");
var path = require("path");
var fs = require("fs")
var nopt = require("nopt");
var args = nopt({
  "env"     : [String, null]
});

build.setEnvironment(args.env);

gulp.task("install-solr", function (callback) {  
  // Can be done with gulp-run? https://www.npmjs.com/package/gulp-run
  var taskDir = path.dirname(fs.realpathSync(__filename));
  var psFile = path.join(taskDir, "../powershell-scripts/install-solr.ps1");
  var result = powershell.runSync(psFile, " -solrExtractLocation " + config.solrExtractLocation, path.join(taskDir, "../powershell-scripts"), callback);
  if (result > 0 )
  {
    build.logEvent("builder", "Installing Solr failed, quitting")
    process.exit(1)
  }
  build.logEvent("builder", "Installing Solr suceeded")
  callback();
});
