/*jslint node: true */
"use strict";

function Powershell() {
}

Powershell.prototype.runAsync = function (pathToScriptFile, parameters, callback) {
  console.log("Powershell - running: " + pathToScriptFile + " " + parameters);
  var spawn = require("child_process").spawn;
  var child = spawn("powershell.exe", [pathToScriptFile, parameters]);

  child.stdout.setEncoding('utf8')
  child.stderr.setEncoding('utf8')

  child.stdout.on("data", function (data) {
    console.log(data);
  });

  child.stderr.on("data", function (data) {
    console.log("Error: " + data);
  });

  child.on("exit", function () {
    console.log("Powershell - done running " + pathToScriptFile);
    if (callback)
      callback();
  });

  child.stdin.end();
}


/* https://nodejs.org/api/child_process.html */
Powershell.prototype.runSync = function (pathToScriptFile, parameters, cwd, callback) {
  console.log("Powershell - running: " + pathToScriptFile + " with parameters: " + parameters + " on directory: " + cwd);
  var spawn = require("child_process").spawnSync;
  var child = spawn("powershell.exe", [pathToScriptFile, parameters], { cwd: cwd, stdio: 'inherit' }); /* Ref: https://nodejs.org/api/console.html */
  return child.status;
}


exports = module.exports = new Powershell();