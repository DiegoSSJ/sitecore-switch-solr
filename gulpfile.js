/*jslint node: true */
"use strict";

var gulp = require("gulp");
var nopt = require("nopt");
var path = require("path");
var requireDir = require("require-dir");
var runSequence = require("run-sequence");
var build = require("./build.js");
var fs = require('fs');
var config = build.config;

var tasks = path.join(__dirname, "gulp-tasks");
var tasks = requireDir(tasks);

var args = nopt({
  "env"     : [String, null]
});

build.setEnvironment(args.env);
  
gulp.task("setup-solr", function (callback) {
  runSequence(
    "install-solr",
    "sitecore-switch-to-solr"
    , callback);
});

gulp.task("default", function () {
	console.log("You need to specifiy a task.");
});

