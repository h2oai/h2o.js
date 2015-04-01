path = require 'path'
h2ojs = require './../h2o.js'
test = require 'tape'

h2o = h2ojs.connect()

test 'airlines example', (t) ->
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

  gbmPrediction = h2o.createPrediction
    model: gbmModel
    frame: testFrame

  glmPrediction = h2o.createPrediction
    model: glmModel
    frame: testFrame

  gbmPrediction (error, result) ->
    if error
      t.end error
    else
      h2o.dump result
      glmPrediction (error, result) ->
        if error
          t.end error
        else
          h2o.dump result
          t.end()
