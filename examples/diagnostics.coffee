h2ojs = require './../h2o.js'
test = require 'tape'

h2o = h2ojs.connect()

test 'getClusterStatus', (t) ->
  h2o.getClusterStatus (error, cluster) ->
    if error
      t.end error
    else
      console.log 'Cluster information:'
      h2o.print cluster
      t.end()

test 'getTimeline', (t) ->
  h2o.getTimeline (error, timeline) ->
    if error
      t.end error
    else
      console.log 'Timeline information:'
      h2o.print timeline
      t.end()

test 'getStackTrace', (t) ->
  h2o.getStackTrace (error, stackTrace) ->
    if error
      t.end error
    else
      console.log 'Current stack trace:'
      h2o.print stackTrace
      t.end()

test 'getLogFile', (t) ->
  h2o.getLogFile -1, 'info', (error, logFile) ->
    if error
      t.end error
    else
      console.log 'Log file:'
      h2o.print logFile
      t.end()

test 'runProfiler', (t) ->
  h2o.runProfiler 10, (error, result) ->
    if error
      t.end error
    else
      console.log 'Profiler output:'
      h2o.print result
      t.end()

test 'runNetworkTest', (t) ->
  h2o.runNetworkTest (error, result) ->
    if error
      t.end error
    else
      console.log 'Network test output:'
      h2o.print result
      t.end()

test 'about', (t) ->
  h2o.about (error, about) ->
    if error
      t.end error
    else
      console.log 'About H2O:'
      h2o.print about
      t.end()

