test = require 'tape'
libh2o = require './h2o.js'

test 'shutdown', (t) ->
  t.plan 1
  h2o = libh2o.connect()
  h2o.shutdown (error, result) ->
    if error
      t.fail JSON.stringify error
    else
      t.deepEqual result, 
        __meta: 
          schema_name: 'ShutdownV2'
          schema_type: 'Shutdown'
          schema_version: 2

