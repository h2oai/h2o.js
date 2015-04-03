#
# This script assumes you have sync'd `h2oai/h2o-dev` in a directory 
# parallel to that of `h2oai/h2o.js`. 
#
# If not, run these commands, assuming you're in `/path/to/h2o.js`:
#
#     $ cd ..
#     $ git clone https://github.com/h2oai/h2o-dev.git
#     $ cd h2o-dev
#     $ ./gradlew syncBigdataLaptop
#

path = require 'path'
h2ojs = require './../h2o.js'
test = require 'tape'

h2o = h2ojs.connect()

locate = (filename) ->
  path.join __dirname, '..', '..', 'h2o-dev', 'bigdata', 'laptop', 'flights-nyc', filename

flights14_zip = locate 'delays14.csv.zip'
delays14_zip = locate 'flights14.csv.zip'
weather14_zip = locate 'weather_delays14.csv.zip'

test 'sequence(10)', (t) ->
  vec = h2o.sequence 10
  vec (error, result) ->
    if error
      t.end error
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll -> t.end()

test 'sequence(11, 20)', (t) ->
  vec = h2o.sequence 11, 20
  vec (error, result) ->
    if error
      t.end error
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll -> t.end()

test 'sequence(11, 12, 0.1)', (t) ->
  vec = h2o.sequence 11, 12, 0.1
  vec (error, result) ->
    if error
      t.end error
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll -> t.end()

test 'replicate(vector, 15)', (t) ->
  vec = h2o.sequence 5
  replication = h2o.replicate vec, 15
  replication (error, result) ->
    if error
      t.end error
    else
      h2o.print result
      h2o.print.columns result.col_names, result.head
      h2o.removeAll -> t.end()


test 'Load frames in parallel', (t) ->
  flights = h2o.importFrame path: flights14_zip
  delays = h2o.importFrame path: delays14_zip
  weather = h2o.importFrame path: weather14_zip

  h2o.resolve flights, delays, weather, (error, flights, delays, weather) ->
    if error
      t.end error
    else
      h2o.print flights
      h2o.print delays
      h2o.print weather

      h2o.removeAll -> t.end()
