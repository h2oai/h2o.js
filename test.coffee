test = require 'tape'
libh2o = require './h2o.js'

h2o = libh2o.connect() 

dump = (a) -> console.log JSON.stringify a, null, 2

test 'createFrame', (t) ->
  parameters =
    dest: 'frame-10000x100'
    rows: 10000
    cols: 100
    seed: 7595850248774472000
    randomize: true
    value: 0
    real_range: 100
    categorical_fraction: 0.1
    factors: 5
    integer_fraction: 0.5
    binary_fraction: 0.1
    integer_range: 1
    missing_fraction: 0.01
    response_factors: 2
    has_response: true

  t.plan 2
  frame = h2o.createFrame parameters
  frame (error, result) ->
    t.equal error, null
    t.notEqual result, null
    dump result

test.skip 'shutdown', (t) ->
  t.plan 1
  h2o.shutdown (error, result) ->
    if error
      t.fail dump error
    else
      t.deepEqual result, 
        __meta: 
          schema_name: 'ShutdownV2'
          schema_type: 'Shutdown'
          schema_version: 2

