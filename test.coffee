path = require 'path'
test = require 'tape'
libh2o = require './h2o.js'
transpiler = require './americano.js'
transpilerTestCases = require './americano.test.js'

h2o = libh2o.connect() 

dump = (a) -> console.log JSON.stringify a, null, 2

test.only 'transpiler.map', (t) ->
  for [ expected, symbols, func ] in transpilerTestCases.map
    t.equal transpiler.map(symbols, func), expected

  t.end()

test 'createColumn', (t) ->
  ###
  users = h2o.frame 'users.hex'

  young = users.filter 'age', (age) -> age < 21
  # select one vec
  age = young.select 'age'

  # select multiple vecs #2
  [ name, age, gender ] = young.select [ 'name', 'age', 'gender' ]

  # map 1 vec
  agePlus1 = h2o.map age, (a) -> a + 1

  # map n vecs
  agePlusGender = h2o.map age, gender, (a, g) -> '' + a + ' ' + g

  # create frame
  young2 = h2o.frame [ name, gender, agePlus1 ]

  # reduce frame
  aggFrame = h2o.reduce name, agePlus1, count, agePlus1, average
  aggFrame = h2o.reduce [ name, gender ], agePlus1, count, agePlus1, average

  ###
  
  airlines = h2o.importFrame
    path: path.join __dirname, 'examples', 'data', 'AirlinesTrain.csv.zip'

  departureTime = h2o.select airlines, 'DepTime'
  departureTime1 = h2o.map departureTime, (a) -> a + 1

  departureTime1 (error, result) ->
    dump error
    dump result

  return t.end()

  departureTime2 = h2o.map departureTime, (a) -> 100 + a * 2
  departureTimes = h2o.bind departureTime, departureTime1, departureTime2

  savedFrame = h2o.createFrame
    name: "departed"
    columns:
      "departure time": departureTime
      "departure 1": departureTime1
      "departure 2": departureTime2

  savedFrame (error, data) ->
    if error
      console.log '----------------- FAIL ----------------------'
      dump error
    else
      dump data

  t.end()

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

