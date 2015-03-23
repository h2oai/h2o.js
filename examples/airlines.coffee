fs = require 'fs'
path = require 'path'

dump = (a) -> console.log JSON.stringify a, null, 2

h2o = (require '../h2o.js').connect()

trainingFrame = h2o.importFrame
  path: path.join __dirname, 'data', 'AirlinesTrain.csv.zip'

testFrame = h2o.importFrame
  path: path.join __dirname, 'data', 'AirlinesTest.csv.zip'

trainingFrame (error, result) ->
  dump error
  dump result




