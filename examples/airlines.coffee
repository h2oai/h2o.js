path = require 'path'
h2ojs = require './../h2o.js'
test = require 'tape'

h2o = h2ojs.connect()

###

Flight Delay Prediction (Binary Classification)
-----------------------------------------------
Use historical on-time performance data to predict whether the departure of a scheduled flight will be delayed.

- Split airlines dataset into train and validation sets.
- Build GBM and GLM models using the train and validation sets.
- Preict on a test set and print prediction performance metrics.

### 

test 'airlines example', (t) ->

  # Load airlines data
  airlines = h2o.importFrame
    path: path.join __dirname, 'data', 'AirlinesTrain.csv.zip'

  # Split airlines data into train and validation sets.
  # Create a new column with random uniform distribution, then use that column
  #  to split the original frame into two frames.
  random = h2o.map airlines, (a) -> random a, -1
  trainingFrame = h2o.filter airlines, random, (a) -> a <= 0.8
  validationFrame = h2o.filter airlines, random, (a) -> a > 0.8

  # Exclude possible target leakers.
  ignoredColumns = ['IsDepDelayed_REC', 'fYear', 'DepTime', 'ArrTime']

  # This will be our predictor column.
  responseColumn = 'IsDepDelayed'

  # Build a GBM model
  gbmModel = h2o.createModel 'gbm',
    training_frame: trainingFrame
    validation_frame: validationFrame
    ignored_columns: ignoredColumns
    response_column: responseColumn
    ntrees: 100
    max_depth: 3
    learn_rate: 0.01
    loss: 'bernoulli'

  # Build a GLM model
  glmModel = h2o.createModel 'glm',
    training_frame: trainingFrame
    validation_frame: validationFrame
    ignored_columns: ignoredColumns
    response_column: responseColumn

  # Create the test frame 
  testFrame = h2o.importFrame
    path: path.join __dirname, 'data', 'AirlinesTest.csv.zip'


  # Predict on the test frame

  gbmPrediction = h2o.createPrediction
    model: gbmModel
    frame: testFrame

  glmPrediction = h2o.createPrediction
    model: glmModel
    frame: testFrame

  # Dump prediction metrics
  h2o.resolve gbmPrediction, glmPrediction, (error, gbmPrediction, glmPrediction) ->
    if error
      t.end error
    else
      h2o.dump gbmPrediction
      h2o.dump glmPrediction
      
      h2o.removeAll -> t.end()

