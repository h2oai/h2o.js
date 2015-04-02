h2ojs = require './../h2o.js'
test = require 'tape'
_ = require 'lodash'

h2o = h2ojs.connect()

test 'getSchemas', (t) ->
  h2o.getSchemas (error, schemas) ->
    if error
      t.end error
    else
      console.log 'The list of all H2O Schemas:'
      h2o.print _.map schemas, (schema) -> 
        _.pick schema, 'version', 'name', 'type'
      t.end()

test 'getSchema', (t) ->
  h2o.getSchema 'CloudV1', (error, schema) ->
    if error
      t.end error
    else
      console.log 'The schema for CloudV1:'
      h2o.print schema
      t.end()

test 'getEndpoints', (t) ->
  h2o.getEndpoints (error, endpoints) ->
    if error
      t.end error
    else
      console.log 'The list of all H2O API endpoints:'

      sample = endpoints
        .slice 0, 15
        .map (a) -> _.pick a, 'http_method', 'url_pattern', 'summary', 'path_params'
        
      h2o.print sample,
        widths:
          summary: 20

      t.end()

test 'getEndpoint', (t) ->
  h2o.getEndpoint 10, (error, endpoint) ->
    if error
      t.end error
    else
      console.log 'The endpoint at index #10:'
      h2o.print endpoint
      t.end()
