fs = require 'fs'
fj = require 'forkjoin'
_ = require 'lodash'
_request = require 'request'
_uuid = require 'node-uuid'

lib = {}

dump = (a) -> console.log JSON.stringify a, null, 2

enc = encodeURIComponent

uuid = -> _uuid.v4()

method = (f) ->
  (args...) ->
    if args.length is f.length
      # arity ok, so eval
      f.apply null, args
    else
      # no efc, so defer
      fj.fork.apply null, [f].concat args

parameterize = (route, form) ->
  if form
    pairs = for key, value of form
      "#{key}=#{value}"
    route + '?' + pairs.join '&'
  else
    route

encodeArray = (array) -> 
  if array
    if array.length is 0
      null 
    else 
      "[#{array.map((element) -> if _.isNumber element then element else "\"#{element}\"").join ','}]"
  else
    null

encodeObject = (source) ->
  target = {}
  for key, value of source
    target[key] = if _.isArray value then encodeArray value else value
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
          else if _.isString error
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

  #
  # Low level APIs
  #

  get = (args..., go) ->
    [ route, form ] = args
    request 'GET', (parameterize route, form), undefined, undefined, go

  post = (route, form, go) ->
    request 'POST', route, 'form', form, go

  upload = (route, formData, go) ->
    request 'POST', route, 'formData', formData, go

  del = (route, go) ->
    request 'DELETE', route, undefined, undefined, go

  #
  # High level APIs
  #

  createFrame = method (parameters, go) ->
    post '/2/CreateFrame.json', parameters, go

  splitFrame = method (parameters, go) ->
#     form =
#       dataset: parameters.dataset
#       ratios: encodeArray parameters.ratios
#       dest_keys: encodeArray parameter.dest_keys
    post '/2/SplitFrame.json', (encodeObject parameters), go

  getFrames = method (go) ->
    get '/3/Frames.json', unwrap go, (result) -> result.frames

  getFrame = method (key, go) ->
    get "/3/Frames.json/#{enc key}", unwrap go, (result) -> _.head result.frames

  deleteFrame = method (key, go) ->
    del "/3/Frames.json/#{enc key}", go

  getRDDs = method (go) ->
    get '/3/RDDs.json', unwrap go, (result) -> result.rdds

  getColumnSummary = method (key, column, go) ->
    get "/3/Frames.json/#{enc key}/columns/#{enc column}/summary", unwrap go, (result) ->
      _.head result.frames

  getJobs = method (go) ->
    get '/2/Jobs.json', unwrap go, (result) ->
      result.jobs

  getJob = method (key, go) ->
    get "/2/Jobs.json/#{enc key}", unwrap go, (result) ->
      _.head result.jobs

  cancelJob = method (key, go) ->
    post "/2/Jobs.json/#{enc key}/cancel", {}, go

  importFile = method (parameters, go) ->
    form = path: enc parameters.path
    get '/2/ImportFiles.json', form, go

  importFiles = method (parameters, go) ->
    (fj.seq parameters.map (parameters) -> fj.fork importFile, parameters) go

  #TODO
  setupParse = method (parameters, go) ->
    form =
      source_keys: encodeArray parameters.source_keys
    post '/2/ParseSetup.json', form, go

  #TODO
  requestParseSetupPreview = method (sourceKeys, parseType, separator, useSingleQuotes, checkHeader, columnTypes, go) ->
    parameters = 
      source_keys: encodeArray sourceKeys
      parse_type: parseType
      separator: separator
      single_quotes: useSingleQuotes
      check_header: checkHeader
      column_types: encodeArray columnTypes
    post '/2/ParseSetup.json', parameters, go

  parseFiles = method (parameters, go) ->
#    parameters =
#      destination_key: destinationKey
#      source_keys: encodeArray sourceKeys
#      parse_type: parseType
#      separator: separator
#      number_columns: columnCount
#      single_quotes: useSingleQuotes
#      column_names: encodeArray columnNames
#      column_types: encodeArray columnTypes
#      check_header: checkHeader
#      delete_on_done: deleteOnDone
#      chunk_size: chunkSize
    post '/2/Parse.json', (encodeObject parameters), go

  # import-and-parse
  importFrame = method (parameters, go) ->
    importForm = 
      path: parameters.path
    importFile importForm, (error, importResult) ->
      if error
        go error
      else
        setupParseForm =
          source_keys: importResult.keys

        setupParse setupParseForm, (error, spr) ->
          if error
            go error
          else
            parseParameters =
              destination_key: spr.destination_key
              source_keys: spr.source_keys.map (key) -> key.name
              parse_type: spr.parse_type
              separator: spr.separator
              number_columns: spr.number_columns
              single_quotes: spr.single_quotes
              column_names: spr.column_names
              column_types: spr.column_types
              check_header: spr.check_header
              chunk_size: spr.chunk_size
              delete_on_done: yes

            parseFiles parseParameters, (error, pr) ->
              if error
                go error
              else
                dump pr
      return

  patchUpModels = method (models) ->
    for model in models
      for parameter in model.parameters
        switch parameter.type
          when 'Key<Frame>', 'Key<Model>', 'VecSpecifier'
            if _.isString parameter.actual_value
              try
                parameter.actual_value = JSON.parse parameter.actual_value
              catch parseError
    models

  getModels = method (go) ->
    get '/3/Models.json', unwrap go, (result) ->
      patchUpModels result.models

  getModel = method (key, go) ->
    get "/3/Models.json/#{enc key}", unwrap go, (result) ->
      _.head patchUpModels result.models

  deleteModel = method (key, go) ->
    del "/3/Models.json/#{enc key}", go

  getModelBuilders = method (go) ->
    get "/3/ModelBuilders.json", go

  getModelBuilder = method (algo, go) ->
    get "/3/ModelBuilders.json/#{algo}", go

  requestModelInputValidation = method (algo, parameters, go) ->
    post "/3/ModelBuilders.json/#{algo}/parameters", (encodeObject parameters), go

  createModel = method (algo, parameters, go) ->
    _.trackEvent 'model', algo
    post "/3/ModelBuilders.json/#{algo}", (encodeObject parameters), go

  predict = method (destinationKey, modelKey, frameKey, go) ->
    parameters = if destinationKey
      destination_key: destinationKey
    else
      {}

    post "/3/Predictions.json/models/#{enc modelKey}/frames/#{enc frameKey}", parameters, unwrap go, (result) ->
      _.head result.model_metrics

  getPrediction = method (modelKey, frameKey, go) ->
    get "/3/ModelMetrics.json/models/#{enc modelKey}/frames/#{enc frameKey}", unwrap go, (result) ->
      _.head result.model_metrics

  getPredictions = method (modelKey, frameKey, _go) ->
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

  uploadFile = method (key, path, go) ->
    formData = file: fs.createReadStream path
    upload "/3/PostFile.json?destination_key=#{enc key}", formData, go

  #TODO
  requestCloud = method (go) ->
    get '/1/Cloud.json', go

  #TODO
  requestTimeline = method (go) ->
    get '/2/Timeline.json', go

  #TODO
  requestProfile = method (depth, go) ->
    get "/2/Profiler.json?depth=#{depth}", go

  #TODO
  requestStackTrace = method (go) ->
    get '/2/JStack.json', go

  #TODO
  requestLogFile = method (nodeIndex, fileType, go) ->
    get "/3/Logs.json/nodes/#{nodeIndex}/files/#{fileType}", go

  #TODO
  requestNetworkTest = method (go) ->
    get '/2/NetworkTest.json', go

  #TODO
  requestAbout = method (go) ->
    get '/3/About.json', go

  getSchemas = method (go) ->
    get '/1/Metadata/schemas.json', go

  getSchema = method (name, go) ->
    get "/1/Metadata/schemas.json/#{enc name}", go

  getEndpoints = method (go) ->
    get '/1/Metadata/endpoints.json', go

  getEndpoint = method (index, go) ->
    get "/1/Metadata/endpoints.json/#{index}", go

  deleteAll = method (go) ->
    del '/1/RemoveAll.json', go

  shutdown = method (go) ->
    post "/2/Shutdown.json", {}, go

  # Files
  importFile: importFile
  importFiles: importFiles
  uploadFile: uploadFile #TODO handle multiple files for consistency with parseFiles()
  parseFiles: parseFiles

  # Frames
  createFrame: createFrame
  importFrame: importFrame
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
