path = require 'path'
test = require 'tape'
_ = require 'lodash'
libh2o = require '../h2o.js'
transpiler = require '../americano.js'
transpilerTestCases = require './americano.test.js'

h2o = libh2o.connect() 

dump = (a) -> console.log JSON.stringify a, null, 2

test 'transpiler.map', (t) ->
  for [ message, expected, symbols, func ] in transpilerTestCases.map
    if expected is null
      t.throws (-> transpiler.map(symbols, func)), undefined, message
    else
      t.equal transpiler.map(symbols, func), expected, message

  t.end()

#
# airlines = new h2o.Frame h2o.importFrame path: path
# dt = airlines.columns.DepTime
# dt1 = airlines.map dt, (a) -> a + 1
# frame = h2o.filter frame, vecs, func
# vec = h2o.filter vec, vecs, func
# frame = h2o.filter vecs, vecs, func
# frame = h2o.slice frame, 0, 10
# vec = h2o.slice vec, 0, 10
# vecs = h2o.slice vecs, 0, 10
# frame = h2o.concat [ frame ]
# vec = h2o.concat [ vec ]
#
#
# h2o.map airlines, [ foo, bar ], (foo, bar) -> foo * bar
#
# h2o.bind [ foo, bar ]
# h2o.bind [ foo, bar ]
#
# h2o.createFrame 
# 

dump1 = (error, data) ->
  if error
    console.log '----------------- FAIL ----------------------'
    console.log error.message
    dump error
  dump data

pathTo = (dir, file) -> path.join __dirname, 'examples', 'data', dir, file
flights_csv = pathTo 'nyc2014', 'flights14.csv'
delays_csv = pathTo 'nyc2014', 'delays14.csv'
weather_csv = pathTo 'nyc2014', 'weather_delays14.csv'

ok = (t, f) ->
  (error, result) ->
    t.equal error, null
    f result if f

fail = (t, f) ->
  (error, result) ->
    t.notEqual error, null
    f error if f

typeOf = (obj) -> obj.__meta.schema_type

keyOf = (obj) -> obj.key.name

end = (t) -> h2o.removeAll -> t.end()

test.skip 'importFrame(), getFrames()', (t) ->
  flights = h2o.importFrame path: flights_csv
  flights ok t, (flights) ->
    t.equal (typeOf flights), 'Frame'
    frames = h2o.getFrames ok t, (frames) ->
      t.assert _.isArray frames
      t.equal frames.length, 1
      frame = _.head frames
      t.equal (typeOf frame), 'Frame'
      t.equal (keyOf frame), keyOf flights
      end t

test.skip 'importFrame(), getFrame(key)', (t) ->
  flights = h2o.importFrame path: flights_csv
  flights ok t, (flights) ->
    t.equal (typeOf flights), 'Frame'
    frame = h2o.getFrame keyOf flights
    frame ok t, (frame) ->
      t.equal (typeOf frame), 'Frame'
      t.equal (keyOf frame), keyOf flights
      end t

test 'getFrame(non-string)', (t) ->
  t.plan 2
  h2o.getFrame {}, fail t
  h2o.getFrame '', fail t
  end t


airlines_trains_csv = path.join __dirname, '..', 'examples', 'data', 'AirlinesTrain.csv.zip'

test 'getSummary(key, label)', (t) ->
  airlines = h2o.importFrame { path: airlines_trains_csv }, (error, frame) ->
    if error
      t.end error
    else
      h2o.getSummary frame.key.name, frame.columns[0].label, (error, frame) ->
        if error
          t.end error
        else
          h2o.print frame.columns[0]
          h2o.removeAll -> t.end()
test.skip 'importFrame, getFrames, getFrame, getColumnSummary, getJobs, getJobs, removeFrame', (t) ->
  flights = h2o.importFrame path: flights_csv
  frames = h2o.getFrames()
  flights1 = h2o.getFrame 'flights14.hex'
  flights2 = h2o.getFrame flights
  dest1 = h2o.getColumnSummary flights, 'dest'
  dest2 = h2o.getColumnSummary flights1, 'dest'
  dest3 = h2o.getColumnSummary flights3, 'dest'
  dest1 ok t, (col1) ->
    t.equal (typeOf col1), 'Vec'
    dest2 ok t, (col2) ->
      t.equal (typeOf col2), 'Vec'
      dest3 ok t, (col3) ->
        t.equal (typeOf col3), 'Vec'
        h2o.getJobs ok t, (jobs) ->
          job0 = _.head jobs
          t.equal (typeOf job0), 'Job'
          job = h2o.getJob job0Key = keyOf job0
          job ok t, (job) ->
            t.equal (typeOf job), 'Job'
            t.equal (keyOf job), job0Key

            removal = removeFrame flights
            removal ok t, ->
              end t

test.skip 'createColumn', (t) ->
  airlines = h2o.importFrame path: 'AirlinesTrain.csv.zip'

  departureTime = h2o.select airlines, 'DepTime'
  departureTime1 = h2o.map departureTime, (a) -> a + 1
  departureTime2 = h2o.map departureTime, (a) -> 100 + a * 2

  departureTimes = h2o.bind [ departureTime, departureTime1, departureTime2 ]

  savedFrame = h2o.createFrame
    name: "departed"
    columns:
      "departure time": departureTime
      "departure 1": departureTime1
      "departure 2": departureTime2

  subset = h2o.filter savedFrame, [ departureTime1, departureTime2 ], (dt1, dt2) -> dt1 > 1000 and dt2 > 3000

  subset2 = h2o.slice subset, 20, 100

  subset3 = h2o.slice subset, 300, 400

  subset4 = h2o.concat [ subset2, subset3 ]

  subset4 dump1

  t.end()

test.skip 'createFrame', (t) ->
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


