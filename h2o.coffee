fs = require 'fs'
fj = require 'forkjoin'
_request = require 'request'

lib = {}

enc = encodeURIComponent

isString = (a) ->
  ('string' is typeof a) or (a instanceof String)

isArray = (a) ->
  a instanceof Array

isFunction = (a) ->
  'function' is typeof a

head = (a) ->
  if a?.length
    a[0]
  else
    undefined

mapWithKey = (obj, f) ->
  result = []
  for key, value of obj
    result.push f value, key
  result

parameterizeRoute = (route, form) ->
  if form
    params = mapWithKey form, (value, key) -> "#{key}=#{value}"
    route + '?' + join params, '&'
  else
    route

encodeArrayForPost = (array) -> 
  if array
    if array.length is 0
      null 
    else 
      "[#{join array.map((element) -> if isNumber element then element else "\"#{element}\""), ','}]"
  else
    null

encodeObject = (source) ->
  target = {}
  for key, value of source
    target[key] = enc value
  target

encodeObjectForPost = (source) ->
  target = {}
  for key, value of source
    target[key] = if isArray value then encodeArrayForPost value else value
  target

unwrap = (go, transform) ->
  (error, result) ->
    if error
      go error
    else
      go null, transform result

class H2OError extends Error
  constructor: (@message, cause) ->
    @cause = cause if cause
  remoteMessage: null
  remoteType: null
  remoteStack: null
  cause: null


connect = (host) ->
  (method, route, formAttribute, formData, go) ->
    opts = 
      method: method
      url: "#{host}#{route}"
      json: yes
    opts[formAttribute] = formData if formAttribute

    _request opts,
      (error, response, body) ->
        if error
          cause = if body?.__meta?.schema_type is 'H2OError'
            h2oError = new H2OError body.exception_msg
            h2oError.remoteMessage = body.dev_msg
            h2oError.remoteType = body.exception_type
            h2oError.remoteStack = body.stacktrace.join '\n'
            h2oError
          else if error?.message
            new H2OError error.message
          else if isString error
            new H2OError error
          else
            new H2OError "Unknown error: #{JSON.stringify error}"

          parameters = if form = opts.form
            " with form #{JSON.stringify form}"
          else if formData = opts.formData
            " with form data"
          else
            ''
          go new H2OError "Error calling #{opts.method} #{opts.url}#{parameters}.", cause
        else
          go error, body

lib.connect = (host='http://localhost:54321') ->

  request = connect host

  get = (args..., go) ->
    [ route, form ] = args
    request 'GET', (parameterizeRoute route, form), go

  post = (route, form, go) ->
    request 'POST', route, 'form', form, go

  upload = (route, formData, go) ->
    request 'POST', route, 'formData', formData, go

  del = (route, go) ->
    request 'DELETE', route, go

  createFrame = (opts, go) ->
    post '/2/CreateFrame.json', opts, go

  splitFrame = (frameKey, splitRatios, splitKeys, go) ->
    opts =
      dataset: frameKey
      ratios: encodeArrayForPost splitRatios
      dest_keys: encodeArrayForPost splitKeys
    post '/2/SplitFrame.json', opts, go

  getFrames = (go) ->
    get '/3/Frames.json', (error, result) ->
      if error
        go error
      else
        go null, result.frames

  getFrame = (key, go) ->
    get "/3/Frames.json/#{enc key}", unwrap go, (result) ->
      head result.frames

  deleteFrame = (key, go) ->
    del "/3/Frames.json/#{enc key}", go

  getRDDs = (go) ->
    get '/3/RDDs.json', unwrap go, (result) -> result.rdds

  getColumnSummary = (key, column, go) ->
    get "/3/Frames.json/#{enc key}/columns/#{enc column}/summary", unwrap go, (result) ->
      head result.frames

  getJobs = (go) ->
    get '/2/Jobs.json', unwrap go, (result) ->
      result.jobs

  getJob = (key, go) ->
    get "/2/Jobs.json/#{enc key}", unwrap go, (result) ->
      head result.jobs

  cancelJob = (key, go) ->
    post "/2/Jobs.json/#{enc key}/cancel", {}, go

  importFile = (opt, go) ->
    form = path: enc opt.path
    get '/2/ImportFiles.json', form, go

  importFiles = (opts, go) ->
    f = fj.seq opts.map (opt) -> fj.fork importFile, opt
    f go

  #TODO
  requestParseSetup = (sourceKeys, go) ->
    opts =
      source_keys: encodeArrayForPost sourceKeys
    post '/2/ParseSetup.json', opts, go

  #TODO
  requestParseSetupPreview = (sourceKeys, parseType, separator, useSingleQuotes, checkHeader, columnTypes, go) ->
    opts = 
      source_keys: encodeArrayForPost sourceKeys
      parse_type: parseType
      separator: separator
      single_quotes: useSingleQuotes
      check_header: checkHeader
      column_types: encodeArrayForPost columnTypes
    post '/2/ParseSetup.json', opts, go

  parseFiles = (sourceKeys, destinationKey, parseType, separator, columnCount, useSingleQuotes, columnNames, columnTypes, deleteOnDone, checkHeader, chunkSize, go) ->
    opts =
      destination_key: destinationKey
      source_keys: encodeArrayForPost sourceKeys
      parse_type: parseType
      separator: separator
      number_columns: columnCount
      single_quotes: useSingleQuotes
      column_names: encodeArrayForPost columnNames
      column_types: encodeArrayForPost columnTypes
      check_header: checkHeader
      delete_on_done: deleteOnDone
      chunk_size: chunkSize
    post '/2/Parse.json', opts, go

  patchUpModels = (models) ->
    for model in models
      for parameter in model.parameters
        switch parameter.type
          when 'Key<Frame>', 'Key<Model>', 'VecSpecifier'
            if isString parameter.actual_value
              try
                parameter.actual_value = JSON.parse parameter.actual_value
              catch parseError
    models

  getModels = (go, opts) ->
    get '/3/Models.json', opts, unwrap go, (result) ->
      patchUpModels result.models

  getModel = (key, go) ->
    get "/3/Models.json/#{enc key}", unwrap go, (result) ->
      head patchUpModels result.models

  deleteModel = (key, go) ->
    del "/3/Models.json/#{enc key}", go

  getModelBuilders = (go) ->
    get "/3/ModelBuilders.json", go

  getModelBuilder = (algo, go) ->
    get "/3/ModelBuilders.json/#{algo}", go

  requestModelInputValidation = (algo, parameters, go) ->
    post "/3/ModelBuilders.json/#{algo}/parameters", (encodeObjectForPost parameters), go

  createModel = (algo, parameters, go) ->
    _.trackEvent 'model', algo
    post "/3/ModelBuilders.json/#{algo}", (encodeObjectForPost parameters), go

  predict = (destinationKey, modelKey, frameKey, go) ->
    opts = if destinationKey
      destination_key: destinationKey
    else
      {}

    post "/3/Predictions.json/models/#{enc modelKey}/frames/#{enc frameKey}", opts, unwrap go, (result) ->
      head result.model_metrics

  getPrediction = (modelKey, frameKey, go) ->
    get "/3/ModelMetrics.json/models/#{enc modelKey}/frames/#{enc frameKey}", unwrap go, (result) ->
      head result.model_metrics

  getPredictions = (modelKey, frameKey, _go) ->
    go = (error, result) ->
      if error
        _go error
      else
        #
        # TODO workaround for a filtering bug in the API
        # 
        predictions = for prediction in result.model_metrics
          if modelKey and prediction.model.name isnt modelKey
            null
          else if frameKey and prediction.frame.name isnt frameKey
            null
          else
            prediction
        _go null, (prediction for prediction in predictions when prediction)

    if modelKey and frameKey
      get "/3/ModelMetrics.json/models/#{enc modelKey}/frames/#{enc frameKey}", go
    else if modelKey
      get "/3/ModelMetrics.json/models/#{enc modelKey}", go
    else if frameKey
      get "/3/ModelMetrics.json/frames/#{enc frameKey}", go
    else
      get "/3/ModelMetrics.json", go

  uploadFile = (key, path, go) ->
    formData = file: fs.createReadStream path
    upload "/3/PostFile.json?destination_key=#{enc key}", formData, go

  #TODO
  requestCloud = (go) ->
    get '/1/Cloud.json', go

  #TODO
  requestTimeline = (go) ->
    get '/2/Timeline.json', go

  #TODO
  requestProfile = (depth, go) ->
    get "/2/Profiler.json?depth=#{depth}", go

  #TODO
  requestStackTrace = (go) ->
    get '/2/JStack.json', go

  #TODO
  requestLogFile = (nodeIndex, fileType, go) ->
    get "/3/Logs.json/nodes/#{nodeIndex}/files/#{fileType}", go

  #TODO
  requestNetworkTest = (go) ->
    get '/2/NetworkTest.json', go

  #TODO
  requestAbout = (go) ->
    get '/3/About.json', go

  getSchemas = (go) ->
    get '/1/Metadata/schemas.json', go

  getSchema = (name, go) ->
    get "/1/Metadata/schemas.json/#{enc name}", go

  getEndpoints = (go) ->
    get '/1/Metadata/endpoints.json', go

  getEndpoint = (index, go) ->
    get "/1/Metadata/endpoints.json/#{index}", go

  deleteAll = (go) ->
    del '/1/RemoveAll.json', go

  shutdown = (go) ->
    post "/2/Shutdown.json", {}, go

  # Files
  importFile: importFile
  importFiles: importFiles
  uploadFile: uploadFile #TODO handle multiple files for consistency with parseFiles()
  parseFiles: parseFiles

  # Frames
  createFrame: createFrame
  splitFrame: splitFrame
  getFrames: getFrames
  getFrame: getFrame
  deleteFrame: deleteFrame

  # Summary
  getColumnSummary: getColumnSummary

  # Models
  createModel: createModel
  getModels: getModels
  getModel: getModel
  deleteModel: deleteModel

  # Predictions
  predict: predict
  getPredictions: getPredictions
  getPrediction: getPrediction

  # Jobs
  getJobs: getJobs
  getJob: getJob
  cancelJob: cancelJob

  # Meta
  getSchemas: getSchemas
  getSchema: getSchema
  getEndpoints: getEndpoints
  getEndpoint: getEndpoint

  # Clean up
  deleteAll: deleteAll
  shutdown: shutdown

module.exports = lib
