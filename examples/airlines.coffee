fs = require 'fs'
path = require 'path'

dump = (a) -> console.log JSON.stringify a, null, 2

h2o = (require '../h2o.js').connect()

dataFrame = h2o.importFrame
  path: path.join __dirname, 'data', 'AirlinesTrain.csv.zip'

#TODO training/validation split
trainingFrame = dataFrame

ignoredColumns = ['IsDepDelayed_REC', 'fYear', 'DepTime', 'ArrTime']

responseColumn = 'IsDepDelayed'

gbmModel = h2o.createModel 'gbm',
  training_frame: trainingFrame
  # TODO
  # validation_frame: validationFrame
  ignored_columns: ignoredColumns
  response_column: responseColumn
  ntrees: 100
  max_depth: 3
  learn_rate: 0.01
  loss: 'bernoulli'

glmModel = h2o.createModel 'glm',
  training_frame: trainingFrame
  # TODO
  # validation_frame: validationFrame
  ignored_columns: ignoredColumns
  response_column: responseColumn

testFrame = h2o.importFrame
  path: path.join __dirname, 'data', 'AirlinesTest.csv.zip'

gbmPrediction = h2o.predict
  model: gbmModel
  frame: testFrame

glmPrediction = h2o.predict
  model: glmModel
  frame: testFrame

gbmPrediction (error, result) ->
  dump error
  dump result

glmPrediction (error, result) ->
  dump error
  dump result
