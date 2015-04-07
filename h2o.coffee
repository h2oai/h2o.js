fs = require 'fs'
fj = require 'forkjoin'
_ = require 'lodash'
_request = require 'request'
_uuid = require 'node-uuid'
transpiler = require './americano.js'
print = require './print.js'
dispatch = require './dispatch.js'

dispatch.register 'Future', (a) -> fj.isFuture a

lib = {}

dump = (a) -> console.log JSON.stringify a, null, 2

deepClone = (a) -> JSON.parse JSON.stringify a

enc = encodeURIComponent

uuid = -> _uuid.v4().replace /\-/g, ''

resolve = fj.resolve

join = (args..., fail, pass) ->
  fj.join args, (error, args) ->
    if error
      fail error
    else
      pass.apply null, args

unwrap = (go, transform) ->
  (error, result) ->
    if error
      go error
    else
      go null, transform result

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

keyOf = (a) ->
  if _.isString a
    a
  else if a.__meta? and a.key?
    a.key.name
  else
    undefined

patchFrame = (frame) ->
  # TODO remove hack
  # Tack on vec_key to each column.
  for column, i in frame.columns
    column.key = frame.vec_keys[i]
  frame

patchFrames = (frames) ->
  for frame in frames
    patchFrame frame
  frames

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

    console.log "#{opts.method} #{opts.url}"

    _request opts, (error, response, body) ->
      if not error and response.statusCode is 200
        go error, body
      else
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

###
type undefined
A Javascript [undefined](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/undefined)
###
###
type Object
A Javascript [Object](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object)
###
###
type Error
A Javascript [Error](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Error)
###
###
type Boolean
A Javascript [Boolean](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Boolean)
###
###
type String
A Javascript [String](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String)
###
###
type Number
A Javascript [Number](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number)
###
###
type Future
TODO: Description goes here.
###

lib.connect = (host='http://localhost:54321') ->

  request = connect host

  #
  # HTTP methods
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
  # Remote API
  #

  #createFrame = method (parameters, go) ->
  #  post '/2/CreateFrame.json', parameters, go

  splitFrame = method (parameters, go) ->
#     form =
#       dataset: parameters.dataset
#       ratios: encodeArray parameters.ratios
#       dest_keys: encodeArray parameter.dest_keys
    post '/2/SplitFrame.json', (encodeObject parameters), go

  getFrames = method (go) ->
    get '/3/Frames.json', unwrap go, (result) -> patchFrames result.frames

  getFrame = method (key, go) ->
    return go new Error 'Parameter [key]: expected string' unless _.isString key
    return go new Error 'Parameter [key]: expected non-empty string' if key is ''
    get "/3/Frames.json/#{enc key}", unwrap go, (result) -> _.head patchFrames result.frames

  removeFrame = method (key, go) ->
    del "/3/Frames.json/#{enc key}", go

  getRDDs = method (go) ->
    get '/3/RDDs.json', unwrap go, (result) -> result.rdds

  #TODO why require a frame to get at the vec?
  getSummary = method (frame_, columnLabel, go) ->
    #TODO validation
    join frame_, go, (frame) ->
      key = keyOf frame
      get "/3/Frames.json/#{enc key}/columns/#{enc columnLabel}/summary", unwrap go, (result) ->
        _.head patchFrames result.frames

  getJobs = method (go) ->
    get '/2/Jobs.json', unwrap go, (result) ->
      result.jobs

  getJob = method (key, go) ->
    get "/2/Jobs.json/#{enc key}", unwrap go, (result) ->
      _.head result.jobs

  waitForJob = method (key, go) ->
    poll = ->
      getJob key, (error, job) ->
        if error
          go error
        else
          # CREATED   Job was created
          # RUNNING   Job is running
          # CANCELLED Job was cancelled by user
          # FAILED    Job crashed, error message/exception is available
          # DONE      Job was successfully finished
          switch job.status
            when 'DONE'
              go null, job
            when 'CREATED', 'RUNNING'
              setTimeout poll, 1000
            else # 'CANCELLED', 'FAILED'
              go (new H2OError "Job #{key} failed: #{job.exception}"), job
    poll()

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

  parseFiles = method (parameters, go) ->
    post '/2/Parse.json', (encodeObject parameters), go

  # import-and-parse
  importFrame = method (parameters, go) ->
    importResult = importFile
      path: parameters.path

    setupResult = fj.lift importResult, (result) ->
      setupParse
        source_keys: result.keys

    parseResult = fj.lift setupResult, (result) ->
      # TODO override with user-parameters
      parseFiles
        destination_key: result.destination_key
        source_keys: result.source_keys.map (key) -> key.name
        parse_type: result.parse_type
        separator: result.separator
        number_columns: result.number_columns
        single_quotes: result.single_quotes
        column_names: result.column_names
        column_types: result.column_types
        check_header: result.check_header
        chunk_size: result.chunk_size
        delete_on_done: yes

    job = fj.lift parseResult, (result) ->
      waitForJob result.job.key.name

    frame = fj.lift job, (job) ->
      getFrame job.dest.name

    frame go

  #TODO obsolete
  patchModels = method (models) ->
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
      #XXX
      patchModels result.models

  getModel = method (key, go) ->
    get "/3/Models.json/#{enc key}", unwrap go, (result) ->
      #XXX
      _.head patchModels result.models

  removeModel = method (key, go) ->
    del "/3/Models.json/#{enc key}", go

  getModelBuilders = method (go) ->
    get "/3/ModelBuilders.json", go

  getModelBuilder = method (algo, go) ->
    get "/3/ModelBuilders.json/#{algo}", go

  requestModelInputValidation = method (algo, parameters, go) ->
    post "/3/ModelBuilders.json/#{algo}/parameters", (encodeObject parameters), go

  resolveParameters = method (parameters, go) ->
    unresolveds = []
    resolved = {}
    for key, obj of parameters
      if fj.isFuture obj
        unresolveds.push key: key, future: obj
      else
        resolved[key] = obj

    if unresolveds.length
      (fj.map unresolveds, ((a) -> a.future)) (error, values) ->
        if error
          go error
        else
          for value, i in values
            resolved[unresolveds[i].key] = value
          go null, resolved
    else
      go null, resolved

  buildModel = method (algo, parameters, go) ->
    post "/3/ModelBuilders.json/#{algo}", (encodeObject parameters), go

  createModel = method (algo, parameters, go) ->
    resolvedParameters = resolveParameters parameters
    build = fj.lift resolvedParameters, (parameters) ->
      trainingFrameKey = keyOf parameters.training_frame
      validationFrameKey = keyOf parameters.validation_frame
      delete parameters.training_frame
      delete parameters.validation_frame
      parameters.training_frame = trainingFrameKey if trainingFrameKey
      parameters.validation_frame = validationFrameKey if validationFrameKey
      buildModel algo, parameters

    job = fj.lift build, (build) ->
      waitForJob build.job.key.name

    model = fj.lift job, (job) ->
      getModel job.dest.name

    model go

  createPrediction = method (parameters, go) ->
    #TODO allow user-override on destination_key
    #parameters = if destinationKey
    #  destination_key: destinationKey
    #else
    #  {}
    resolveParameters parameters, (error, parameters) ->
      if error
        go error
      else
        modelKey = keyOf parameters.model
        frameKey = keyOf parameters.frame
        delete parameters.model
        delete parameters.frame

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

  #
  # Diagnostics
  #

  getClusterStatus = method (go) ->
    get '/1/Cloud.json', go

  getTimeline = method (go) ->
    get '/2/Timeline.json', go

  getStackTrace = method (go) ->
    get '/2/JStack.json', go

  getLogFile = method (nodeIndex, fileType, go) ->
    get "/3/Logs.json/nodes/#{nodeIndex}/files/#{fileType}", go

  runProfiler = method (depth, go) ->
    get "/2/Profiler.json?depth=#{depth}", go

  runNetworkTest = method (go) ->
    get '/2/NetworkTest.json', go

  about = method (go) ->
    get '/3/About.json', go

  #
  # Private
  #

  evaluate = method (ast, go) ->
    console.log ast
    post '/1/Rapids.json', { ast: ast }, (error, result) ->
      if error
        go error
      else
        #TODO HACK - this api returns a 200 OK on failures
        if result.error
          go new Error result.error
        else
          go null, result

  getSchemas = method (go) ->
    get '/1/Metadata/schemas.json', unwrap go, (result) -> result.schemas

  getSchema = method (name, go) ->
    get "/1/Metadata/schemas.json/#{enc name}", unwrap go, (result) -> _.head result.schemas

  getEndpoints = method (go) ->
    get '/1/Metadata/endpoints.json', unwrap go, (result) -> result.routes

  getEndpoint = method (index, go) ->
    get "/1/Metadata/endpoints.json/#{index}", unwrap go, (result) -> _.head result.routes

  remove = method (key, go) ->
    del '/1/Remove.json', go

  removeAll = method (go) ->
    del '/1/RemoveAll.json', go

  shutdown = method (go)->
    post "/2/Shutdown.json", {}, go

  #
  # Data Munging
  #

  whitespace = /\s+/

  astApply = (op, args) ->
    "(#{[op].concat(args).join ' '})"

  astCall = (op, args...) ->
    astApply op, args

  astString = (string) ->
    JSON.stringify string

  astNumber = (number) ->
    "##{number}"

  astWrite = (key) ->
    if whitespace.test key then astString key else "!#{key}"

  astRead = (key) ->
    if whitespace.test key then astString key else "%#{key}"

  astList = (list) ->
    "{#{ list.join ';' }}"

  astSpan = (begin, end) ->
    astCall ':', (astNumber begin), (astNumber end)

  astStrings = (strings) ->
    astList (astString string for string in strings)

  astNumbers = (numbers) ->
    astList (astNumber number for number in numbers)

  astPut = (key, op) ->
    astCall '=', (astWrite key), op

  astBind = (keys) ->
    astApply 'cbind', keys.map astRead

  astConcat = (keys) ->
    astApply 'rbind', keys.map astRead

  astColNames = (key, names) ->
    astCall 'colnames=', (astRead key), (astList [astSpan 0, names.length - 1]), (astStrings names)

  astBlock = (ops...) ->
    astApply ',', ops

  astNull = ->
    '"null"'

  astFilter = (key, op) ->
    astCall '[', (astRead key), op, astNull()

  astSlice = (key, begin, end) ->
    #TODO end - 1?
    astCall '[', (astRead key), (astList [ astSpan begin, end ]), astNull()

  selectVector = method (frame, label, go) ->
    resolve frame, (error, frame) ->
      if error
        go error
      else
        if _.isNumber label
          vector = frame.columns[label]
          if vector
            go null, vector
          else
            go new Error "Vector at index [#{label}] not found in Frame [#{frame.key.name}]"

        else
          vector = _.find frame.columns, (vector) -> vector.label is label
          if vector
            go null, vector
          else
            go new Error "Vector [#{label}] not found in Frame [#{frame.key.name}]"

  mapVectors = method (arg, func, go) ->
    vectors_ = if _.isArray arg then arg else [ arg ]
    resolve vectors_, (error, vectors) ->
      if error
        go error
      else
        vectorKeys = vectors.map keyOf
        try
          op = transpiler.map vectorKeys, func
          evaluate (astPut uuid(), op), (error, vector) ->
            if error
              go error
            else
              go null, vector
        catch error
          console.log func.toString()
          go error

  filterFrame = method (frame_, arg, func, go) ->
    vectors_ = if _.isArray arg then arg else [ arg ]
    resolve frame_, vectors_, (error, frame, vectors) ->
      if error
        go error
      else
        sourceKey = frame.key.name
        vectorKeys = vectors.map keyOf
        try
          op = transpiler.map vectorKeys, func
          evaluate (astPut uuid(), astFilter sourceKey, op), (error, frame) ->
            if error
              go error
            else
              go null, frame
        catch error
          go error

  sliceFrame = method (frame_, begin, end, go) ->
    # TODO validate begin/end
    # TODO use resolve()
    resolve frame_, (error, frame) ->
      if error
        go error
      else
        sourceKey = frame.key.name
        evaluate (astPut uuid(), astSlice sourceKey, begin, end - 1), (error, frame) ->
          if error
            go error
          else
            go null, frame

  _bindVectors = method (targetKey, vectors, go) ->
    # TODO use resolve()
    resolve vectors, (error, vectors) ->
      if error
        go error
      else
        vectorKeys = vectors.map keyOf
        evaluate (astPut targetKey, astBind vectorKeys), (error, frame) ->
          if error
            go error
          else
            go null, frame

  bindVectors = method (vectors, go) ->
    _bindVectors uuid(), vectors, go

  createFrame = method (parameters, go) ->
    { name, columns } = parameters

    columnNames = _.keys columns
    vectors_ = _.values columns

    _bindVectors name, vectors_, (error, frame) ->
      if error
        go error
      else
        evaluate (astColNames frame.key.name, columnNames), (error, frame) ->
          if error
            go error
          else
            go null, frame

  concatFrames = method (frames_, go) ->
    resolve frames_, (error, frames) ->
      if error
        go error
      else
        keys = frames.map (frame) -> frame.key.name
        evaluate (astConcat keys), (error, frame) ->
          if error
            go error
          else
            go null, frame


  _combine = method (elements, go) ->
    asts = for element in elements
      if _.isFinite element
        astNumber element
      else if _.isArray element
        [ begin, end ] = element
        astSpan begin, end
      else
        throw new Error "Cannot combine element [#{element}]"

    evaluate (astPut uuid(), astCall 'c', astList asts), go

  combine = dispatch
    'Array': _combine
    'Array, Function': _combine

  _replicate = method (frame_, length, go) ->
    join frame_, go, (frame) ->
      op = astCall(
        'rep_len'
        astRead keyOf frame
        astNumber length
      )
      evaluate (astPut uuid(), op), go

  replicate = dispatch
    'Future, Finite': _replicate
    'String, Finite': _replicate
    'Future, Finite, Function': _replicate
    'String, Finite, Function': _replicate

  ###
  function sequence
  Generate regular sequences.
  ---
  end -> Future<RapidsV1>
  start end -> Future<RapidsV1>
  start end step -> Future<RapidsV1>
  end go -> undefined
  start end go -> undefined
  start end step go -> undefined
  ---
  start : Future<Number>[]
    The starting value of the sequence.
  end  : Number
    The end value of the sequence.
  step: Number
    Increment of the sequence.
  go: Error RapidsV1 -> undefined
    Error-first callback.
  ---
  sequence(10)
  Create a vector with values from 1 to 10.
  ```
  h2o.sequence 10, (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ---
  sequence(11, 20)
  Create a vector with values from 11 to 20.
  ```
  h2o.sequence 11, 20, (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  _sequence$3 = method (start, end, step, go) ->
    op = astCall(
      'seq'
      astNumber start
      astNumber end
      astNumber step
    )
    evaluate (astPut uuid(), op), go

  _sequence$1 = method (end, go) ->
    op = astCall(
      'seq_len'
      astNumber end
    )
    evaluate (astPut uuid(), op), go

  sequence = dispatch
    'Finite': _sequence$1
    'Finite, Finite': (start, end) -> _sequence$3 start, end, 1
    'Finite, Finite, Finite': _sequence$3
    'Finite, Function': _sequence$1
    'Finite, Finite, Function': (start, end, go) -> _sequence$3 start, end, 1, go
    'Finite, Finite, Finite, Function': _sequence$3


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
  removeFrame: removeFrame

  # Summary
  getSummary: getSummary

  # Models
  createModel: createModel
  getModels: getModels
  getModel: getModel
  removeModel: removeModel

  # Predictions
  createPrediction: createPrediction
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
  remove: remove
  removeAll: removeAll
  shutdown: shutdown

  # Diagnostics
  getClusterStatus: getClusterStatus
  getTimeline: getTimeline
  getStackTrace: getStackTrace
  getLogFile: getLogFile
  runProfiler: runProfiler
  runNetworkTest: runNetworkTest
  about: about

  # Local
  bind: bindVectors # TODO createFrame?
  select: selectVector # TODO getColumn?
  map: mapVectors # TODO mapColumns?
  filter: filterFrame
  slice: sliceFrame
  concat: concatFrames
  resolve: resolve
  sequence: sequence
  replicate: replicate
  combine: combine

  # Types
  error: H2OError

  # Debugging
  dump: dump
  print: print
  lift: fj.lift

module.exports = lib
