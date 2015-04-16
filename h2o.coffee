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
    # dump opts

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
type None
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
type Date
A Javascript [Date](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Date)
###
###
type Function
A Javascript [Function](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Function)
###
###
type Future
TODO: Description goes here.
###
###
type Frame
A reference to a `FrameV3` object. A `Frame` can be thought of as a pointer to the result of computations such as `map()`, `reduce()`, `combine()`, `append()`, etc. You can dereference a `Frame` using the `get()` function, which will yield a `FrameV3`. A `FrameV3` can be substituted in place of a `Frame` in all functions that accept frames.
###
###
type Vector
A reference to a `ColV3` object. A `Vector` can be thought of as a pointer to the result of computations such as `map()`, `reduce()`, `combine()`, `append()`, etc. You can dereference a `Vector` using the `get()` function, which will yield a `ColV3`. A `ColV3` can be substituted in place of a `Frame` in all functions that accept frames.
###
###
type Factor
A reference to a `ColV3` object. A `Vector` can be thought of as a pointer to the result of computations such as `map()`, `reduce()`, `combine()`, `append()`, etc. You can dereference a `Vector` using the `get()` function, which will yield a `ColV3`. A `ColV3` can be substituted in place of a `Frame` in all functions that accept frames.
###
###
type Indices
TODO
###
###
type Span
TODO
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
  # References
  #

  createReference = (type, resolve) ->
    __is_reference__: yes
    type: type
    resolve: resolve

  isReference = (obj) ->
    if obj.__is_reference__ then yes else no

  isFrame = (obj) ->
    if (isReference obj) and obj.type is 'Frame'
      yes
    else if obj.__meta?.schema_type is 'Frame'
      yes
    else
      no

  isVector = (obj) ->
    if (isReference obj) and obj.type is 'Vector'
      yes
    else if obj.__meta?.schema_type is 'Vec'
      yes
    else
      no

  dereference = method (obj, go) ->
    if isReference obj
      obj.resolve go
    else
      go null, obj

  resolveType = (label, test) ->
    (obj, go) ->
      resolve obj, (error, obj) ->
        if error
          go error
        else
          if test obj
            dereference obj, go
          else
            go new Error "Argument is not a #{label}."

  resolveFrame = resolveType 'Frame', isFrame
  resolveVector = resolveType 'Vector', isVector

  #
  # Remote API
  #

  #createFrame = method (parameters, go) ->
  #  post '/3/CreateFrame', parameters, go

  splitFrame = method (parameters, go) ->
#     form =
#       dataset: parameters.dataset
#       ratios: encodeArray parameters.ratios
#       dest_keys: encodeArray parameter.dest_keys
    post '/3/SplitFrame', (encodeObject parameters), go

  ###
  function getFrames
  Retrieve a list of all the frames in your cluster.
  ---
  -> Future<FrameV3[]>
  go -> None
  ---
  go: Error FrameV3[] -> None
    Error-first callback.
  ---
  getFrames()
  Retrieve a list of all the frames in your cluster.
  ```
  h2o.getFrames (error, frames) ->
    if error
      fail
    else
      h2o.print frames
      pass
  ###
  getFrames = method (go) ->
    get '/3/Frames', unwrap go, (result) -> patchFrames result.frames

  getFrame = method (key, go) ->
    return go new Error 'Parameter [key]: expected string' unless _.isString key
    return go new Error 'Parameter [key]: expected non-empty string' if key is ''
    get "/3/Frames/#{enc key}", unwrap go, (result) -> _.head patchFrames result.frames

  removeFrame = method (key, go) ->
    del "/3/Frames/#{enc key}", go

  getRDDs = method (go) ->
    get '/3/RDDs', unwrap go, (result) -> result.rdds

  #TODO why require a frame to get at the vec?
  getSummary = method (frame_, columnLabel, go) ->
    #TODO validation
    join frame_, go, (frame) ->
      key = keyOf frame
      get "/3/Frames/#{enc key}/columns/#{enc columnLabel}/summary", unwrap go, (result) ->
        _.head patchFrames result.frames

  ###
  function getJobs
  Retrieve a list of all the jobs in your cluster.
  ---
  -> Future<JobV3[]>
  go -> None
  ---
  go: Error JobV3[] -> None
    Error-first callback.
  ---
  getJobs()
  Retrieve a list of all the jobs in your cluster.
  ```
  h2o.getJobs (error, jobs) ->
    if error
      fail
    else
      h2o.print jobs
      pass
  ###
  getJobs = method (go) ->
    get '/3/Jobs', unwrap go, (result) ->
      result.jobs

  getJob = method (key, go) ->
    get "/3/Jobs/#{enc key}", unwrap go, (result) ->
      _.head result.jobs

  waitFor = method (key, go) ->
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
    post "/3/Jobs/#{enc key}/cancel", {}, go

  importFile = method (parameters, go) ->
    form = path: enc parameters.path
    get '/3/ImportFiles', form, go

  importFiles = method (parameters, go) ->
    (fj.seq parameters.map (parameters) -> fj.fork importFile, parameters) go

  #TODO
  setupParse = method (parameters, go) ->
    form =
      source_keys: encodeArray parameters.source_keys
    post '/3/ParseSetup', form, go

  parseFiles = method (parameters, go) ->
    post '/3/Parse', (encodeObject parameters), go

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
      waitFor result.job.key.name

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

  ###
  function getModels
  Retrieve a list of all the models in your cluster.
  ---
  -> Future<ModelSchema[]>
  go -> None
  ---
  go: Error ModelSchema[] -> None
    Error-first callback.
  ---
  getModels()
  Retrieve a list of all the models in your cluster.
  ```
  h2o.getModels (error, models) ->
    if error
      fail
    else
      h2o.print models
      pass
  ###
  getModels = method (go) ->
    get '/3/Models', unwrap go, (result) ->
      #XXX
      patchModels result.models

  getModel = method (key, go) ->
    get "/3/Models/#{enc key}", unwrap go, (result) ->
      #XXX
      _.head patchModels result.models

  removeModel = method (key, go) ->
    del "/3/Models/#{enc key}", go

  getModelBuilders = method (go) ->
    get "/3/ModelBuilders", go

  getModelBuilder = method (algo, go) ->
    get "/3/ModelBuilders/#{algo}", go

  requestModelInputValidation = method (algo, parameters, go) ->
    post "/3/ModelBuilders/#{algo}/parameters", (encodeObject parameters), go

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
    post "/3/ModelBuilders/#{algo}", (encodeObject parameters), go

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
      waitFor build.job.key.name

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

        post "/3/Predictions/models/#{enc modelKey}/frames/#{enc frameKey}", parameters, unwrap go, (result) ->
          _.head result.model_metrics

  getPrediction = method (modelKey, frameKey, go) ->
    get "/3/ModelMetrics/models/#{enc modelKey}/frames/#{enc frameKey}", unwrap go, (result) ->
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
      get "/3/ModelMetrics/models/#{enc modelKey}/frames/#{enc frameKey}", go
    else if modelKey
      get "/3/ModelMetrics/models/#{enc modelKey}", go
    else if frameKey
      get "/3/ModelMetrics/frames/#{enc frameKey}", go
    else
      get "/3/ModelMetrics", go

  uploadFile = method (key, path, go) ->
    formData = file: fs.createReadStream path
    upload "/3/PostFile?destination_key=#{enc key}", formData, go

  #
  # Diagnostics
  #

  getClusterStatus = method (go) ->
    get '/3/Cloud', go

  getTimeline = method (go) ->
    get '/3/Timeline', go

  getStackTrace = method (go) ->
    get '/3/JStack', go

  getLogFile = method (nodeIndex, fileType, go) ->
    get "/3/Logs/nodes/#{nodeIndex}/files/#{fileType}", go

  runProfiler = method (depth, go) ->
    get "/3/Profiler?depth=#{depth}", go

  runNetworkTest = method (go) ->
    get '/3/NetworkTest', go

  about = method (go) ->
    get '/3/About', go

  #
  # Private
  #

  evaluate__obsolete = (form, go) ->
    console.log form.ast
    console.log form.funs if form.funs
    post '/3/Rapids', form, (error, result) ->
      if error
        go error
      else
        #TODO HACK - this api returns a 200 OK on failures
        if result.error
          go new Error result.error
        else
          go null, result

  evaluate = (form, go) ->
    post '/3/Rapids', form, (error, result) ->
      if error
        go error
      else
        #TODO HACK - this api returns a 200 OK on failures
        if result.error
          go new Error result.error
        else
          go null, result

  importFunc = method (func, go) ->
    console.log func
    evaluate { fun: func }, go

  evaluateExpression = method (expr, go) ->
    console.log expr
    evaluate { ast: expr }, go

  importFuncs = method (funcs, go) ->
    imports = funcs.map (func) -> importFunc func
    fj.join imports, (error, results) ->
      if error
        go error
      else
        go null, results

  #TODO obsolete
  applyExpr = method (funs, ast, go) ->
    evaluate { funs: (encodeArray funs), ast: ast }, go

  #TODO obsolete
  callExpr = method (ast, go) ->
    evaluate { ast: ast }, go

  getSchemas = method (go) ->
    get '/3/Metadata/schemas', unwrap go, (result) -> result.schemas

  getSchema = method (name, go) ->
    get "/3/Metadata/schemas/#{enc name}", unwrap go, (result) -> _.head result.schemas

  getEndpoints = method (go) ->
    get '/3/Metadata/endpoints', unwrap go, (result) -> result.routes

  getEndpoint = method (index, go) ->
    get "/3/Metadata/endpoints/#{index}", unwrap go, (result) -> _.head result.routes

  remove = method (key, go) ->
    del "/3/DKV/#{enc key}", go

  removeAll = method (go) ->
    del '/3/DKV', go

  shutdown = method (go)->
    post "/3/Shutdown", {}, go

  #
  # Expression-building
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
    "!#{astString key}"

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
    astApply 'combine', keys.map astRead

  astConcat = (keys) ->
    astApply 'concat', keys.map astRead

  astColNames = (key, names) ->
    astCall 'colnames=', (astRead key), (astList [astSpan 0, names.length - 1]), (astStrings names)

  astBlock = (ops...) ->
    astApply ',', ops

  astNull = ->
    '"null"'

  _astSlice = (key, rowOp, colOp) ->
    astCall '[', (astRead key), (rowOp ? astNull()), (colOp ? astNull())

  astFilter = (key, op) ->
    # astCall '[', (astRead key), op, astNull()
    _astSlice key, op, null

  astPluck = (key, index) ->
    #TODO index - 1?
    # ([ %frame "null" #index)
    #astCall '[', (astRead key), astNull(), (astNumber index)
    _astSlice key, null, astNumber index

  astSlice = (key, begin, end) ->
    #TODO end - 1?
    # ([ %frame {(: #begin #end)} "null")
    # astCall '[', (astRead key), (astList [ astSpan begin, end ]), astNull()
    _astSlice key, (astList [ astSpan begin, end ]), null

  astDef = (key, params, op) ->
    astCall(
      'def'
      key
      astList params
      op
    )

  __functionCache = {}
  astFunc = (func) ->
    if cached = __functionCache[ source = func.toString() ]
      name: cached.name
    else
      name = 'anon' + uuid()
      params = ['z']
      #TODO make transpiler accept strings
      def = astDef name, params, transpiler.transpile params, func
      __functionCache[ source ] =
        name: name
        ast: def


  #
  # Data munging
  #

  ###
  function select
  Get a reference to a vector in a frame by label or index.
  ---
  frame label -> Future<Vector>
  frame index -> Future<Vector>
  frame label go -> None
  frame index go -> None
  ---
  frame: Frame
    The source frame.
  label: String
    The vector's label (equivalent to the column name).
  index: Number
    The zero-based index of the vector.
  go: Error Vector -> None
    Error-first callback.
  ---
  select(frame, label)
  Select a vector using its label.
  ```
  airlines = h2o.importFrame
    path: '~/airlines/AirlinesTrain.csv.zip'
  depTime = h2o.select airlines, 'DepTime'
  depTime (error, result) ->
    if error
      fail
    else
      h2o.dump result
      h2o.removeAll ->
        pass
  ---
  select(frame, index)
  Select a vector using its index in the frame.
  ```
  airlines = h2o.importFrame
    path: '~/airlines/AirlinesTrain.csv.zip'
  depTime = h2o.select airlines, 4
  depTime (error, result) ->
    if error
      fail
    else
      h2o.removeAll ->
        pass
  ###
  selectVector = method (frame, label, go) ->
    resolveFrame frame, (error, frame) ->
      if error
        go error
      else
        if _.isFinite label
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
  
  ###
  function map
  Apply a function to each row in a frame or a set of vectors to produce a new frame or vector. The eventual result of this operation depends on what is being mapped over, and the return type of the function `func`.

  - In the `(vector, func)` form, `func` is applied to each element of the source vector, producing a new vector of the same length as the source vector. `func` should be a function of the form `(scalar) -> (scalar)`.
  - In the `(vectors, func)` form, `func` is applied to each set of elements in the source vectors, producing a new vector of the same length as the source vectors. `func` should be a function of the form `(scalars...) -> scalar`, where the number of parameters `scalars...` is the same as the number of source vectors.
  - In the `(frame, func)` form, `func` is applied to every element of every vector in the source frame, producing a new frame of the same dimensions as the source frame. `func` should be a function of the form `(scalar) -> scalar`.
  ---
  vector func -> Future<Vector>
  vectors func -> Future<Vector>
  frame func -> Future<Frame>
  vector func go -> None
  vectors func go -> None
  frame func go -> None
  ---
  frame: Frame
    The frame to map over. 
  vector: Vector
    The vector to map over.
  vectors: [Vector]
    The array of vectors to map over.
  func: Function
    The function to call.
  go: Error Frame|Vector -> None
    Error-first callback.
  ---
  map(vector, map)
  `(vector, ((scalar) -> scalar))`
  ```
  xs = h2o.sequence 5
  squares = h2o.map xs, (a) -> a * a
  squares (error, vector) ->
    if error
      fail
    else
      h2o.dump vector
      pass
  ---
  map(vectors, map)
  `(vectors, ((scalars...) -> scalar))`
  ```
  xs = h2o.sequence 10, 15 
  ys = h2o.sequence 20, 25
  zs = h2o.sequence 30, 35
  sumOfSquares = h2o.map [ xs, ys, zs ], (x, y, z) ->
    x * x + y * y + z * z
  sumOfSquares (error, vector) ->
    if error
      fail
    else
      h2o.dump vector
      pass
  ---
  map(frame, map)
  `(frame, ((scalar) -> scalar))` 
  ```
  xs = h2o.sequence 10, 15 
  ys = h2o.sequence 20, 25
  zs = h2o.sequence 30, 35
  frame = h2o.combine [ xs, ys, zs ]
  squares = h2o.map frame, (a) -> a * a
  squares (error, frame) ->
    if error
      fail
    else
      h2o.dump frame
      pass
  ---
  map(frame, reduce)
  `(frame, ((vector) -> scalar))` 
  ```
  xs = h2o.sequence 10, 15 
  ys = h2o.sequence 20, 25
  zs = h2o.sequence 30, 35
  frame = h2o.combine [ xs, ys, zs ]
  squares = h2o.map frame, (a) -> sum a
  squares (error, frame) ->
    if error
      fail
    else
      h2o.dump frame
      pass
  ###
  mapVectors = method (arg, func, go) ->
    vectors_ = if _.isArray arg then arg else [ arg ]
    fj.join vectors_, (error, vectors) ->
      if error
        go error
      else
        vectorKeys = vectors.map keyOf
        try
          op = transpiler.transpile vectorKeys, func
          callExpr (astPut uuid(), op), (error, vector) ->
            if error
              go error
            else
              go null, vector
        catch error
          console.log func.toString()
          go error

  ###
  function apply
  Apply a Javascript function to one or more frames.
  ---
  frame func -> Future<RapidsV3>
  frames func -> Future<RapidsV3>
  frame func go -> None
  frames func go -> None
  ---
  frame: Frame
    The frame to apply the function to.
  frames: [Frame]
    The frames to apply the funcion to.
  func: Function
    The function to apply.
  go: Error RapidsV3 -> None
    Error-first callback.
  ---
  apply()
  Create a vector with values from 1 to 10.
  ```
  h2o.apply [], (-> sequence 10), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###
  apply = method (arg, func, go) ->
    frames_ = if _.isArray arg then arg else [ arg ]
    fj.join frames_, (error, frames) ->
      if error
        go error
      else
        frameKeys = frames.map keyOf
        try
          [ op, procs ] = transpiler.transpile frameKeys, func
        catch error
          console.log func.toString()
          return go error

        importFuncs procs, (error) ->
          if error
            go error
          else
            evaluateExpression (astPut uuid(), op), go
  ###
  function createVector
  Create a vector from a string or numeric vector.
  ---
  numbers -> Future<Vector>
  strings -> Future<Vector>
  numbers go -> None
  strings go -> None
  ---
  numbers: [Number]
    Array of numbers (nulls allowed, will be converted to NaNs on import)
  strings: [String]
    Array of strings (nulls allowed)
  go: Error Vector -> None
    Error-first callback.
  ---
  createVector(numbers)
  Create a numeric vector from an array of numbers.
  ```
  values = [ 0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55 ]
  h2o.createVector values, (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ---
  createVector(numbersWithMissing)
  Create a numeric vector from an array of numbers, with missing values.
  ```
  values = [ 0, 1, 1, 2, 3, 5, 8, null, 21, 34, 55 ]
  h2o.createVector values, (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ---
  createVector(strings)
  Create a string vector from an array of strings.
  ```
  values = [ 'foo', 'bar', 'qux', 'quux' ]
  h2o.createVector values, (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ---
  createVector(stringsWithMissing)
  Create a string vector from an array of strings, with missing values.
  ```
  values = [ 'foo', 'bar', null, 'quux' ]
  h2o.createVector values, (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###
  createVector = method (array, go) ->
    try
      op = transpiler.toVector array
    catch error
      return go error

    evaluateExpression (astPut uuid(), op), go

  ###
  function tapply
  Apply a function to a frame, column-wise.
  ---
  frame func -> Future<Frame>
  vector func -> Future<Vector>
  frame func go -> None
  vector func go -> None
  ---
  frame: Frame
    The source frame.
  vector: Vector
    The source vector.
  func: Function
    The function to apply to the given frame or vector.
  go: Error Frame|Vector -> None
    Error-first callback.
  ---
  tapply()
  Square all numbers in all vectors in a frame.
  ```
  vector = h2o.sequence 5
  frame = h2o.combine [ vector, vector, vector, vector, vector ]
  h2o.tapply frame, ((a) -> (a * a)), (error, result) ->
    if error
      fail
    else
      h2o.dump result
      pass
  ###
  applyToFrame = method (arg, func, go) ->
    _applyToFrame 1, arg, func, go

  ###
  function sapply
  Apply a function to a frame, column-wise.
  ---
  frame func -> Future<Frame>
  vector func -> Future<Vector>
  frame func go -> None
  vector func go -> None
  ---
  frame: Frame
    The source frame.
  vector: Vector
    The source vector.
  func: Function
    The function to apply to the given frame or vector.
  go: Error Frame|Vector -> None
    Error-first callback.
  ---
  sapply()
  Square all numbers in all vectors in a frame.
  ```
  vector = h2o.sequence 5
  frame = h2o.combine [ vector, vector, vector, vector, vector ]
  h2o.sapply frame, ((a) -> (a * a)), (error, result) ->
    if error
      fail
    else
      h2o.dump result
      pass
  ###
  sapplyToFrame = method (arg, func, go) ->
    _applyToFrame 2, arg, func, go

  _applyToFrame = (margin, arg, func, go) ->
    join arg, go, (frame) ->
      def = astFunc func
      op = astPut(
        uuid()
        astCall(
          'apply'
          astRead keyOf frame
          astNumber 1
          astRead def.name
        )
      )
      if def.ast
        applyExpr [ def.ast ], op, go
      else
        callExpr op, go

  ###
  function filter
  Create a new frame from a portion of an existing frame.
  ---
  frame indices -> Frame
  ---
  frame: Frame
    The source frame.
  indices: Indices
    The indices of the rows to be included.
  ---
  filter(frame, at(10, 20, 30))
  Slice discontiguous rows
  ```
  frame = h2o.apply [], -> combine sequence(100), sequence(101, 200)
  rows = h2o.apply frame, (frame) -> filter frame, at 10, 20, 30
  rows (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ---
  filter(frame, at(to(10, 20)))
  Slice contiguous rows
  ```
  frame = h2o.apply [], -> combine sequence(100), sequence(101, 200)
  rows = h2o.apply frame, (frame) -> filter frame, at to 0, 10
  rows (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      pass
      return
      h2o.removeAll ->
        pass
  ---
  filter(frame, at(5, to(10, 20), 25))
  Slice contiguous and discontiguous rows
  ```
  frame = h2o.apply [], -> combine sequence(100), sequence(101, 200)
  rows = h2o.apply frame, (frame) -> filter frame, at 5, to(10, 20), 25
  rows (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function combine
  Combine multiple frames or vectors together to form a new frame.
  ---
  framesOrVectors... -> Frame
  ---
  framesOrVectors: [Vector|Frame]
    The frames and/or vectors to combine together.
  ---
  combine()
  Create and combine three vectors into a new frame.
  ```
  h2o.apply [], (-> combine sequence(1, 10), sequence(11, 20), sequence(21, 30)), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ---
  combine() nested
  Create and combine three vectors into a new frame.
  ```
  h2o.apply [], (-> combine(combine(sequence(1, 10), sequence(11, 20)), sequence(21, 30))), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function createFrame
  Combine and name multiple vectors together to form a new named frame.
  ---
  schema -> Future<Frame>
  schema go -> None
  ---
  schema: Object
    An object of the form `{ name: 'Frame Name', columns: { "Column 1 Name": vector_1 , "Column 2 Name": vector_2, ... "Column N Name": vector_N } }`
  go: Error Frame -> None
    Error-first callback.
  ---
  createFrame()
  Create a named frame using four arrays.
  ```
  odd = h2o.vector [ 1, 3, 5, 7, 9 ]
  even = h2o.vector [ 2, 4, 5, 8, 10 ]
  prime = h2o.vector [ 2, 3, 5, 7, 11 ]
  fibonacci = h2o.vector [ 0, 1, 1, 2, 3 ]

  schema =
    name: 'Numbers'
    columns:
      'Odd': odd
      'Even': even
      'Prime': prime
      'Fibonacci': fibonacci

  h2o.createFrame schema, (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###
  createFrame = method (parameters, go) ->
    { name, columns } = parameters

    columnNames = _.keys columns
    vectors_ = _.values columns

    _bindVectors name, vectors_, (error, frame) ->
      if error
        go error
      else
        callExpr (astColNames frame.key.name, columnNames), (error, frame) ->
          if error
            go error
          else
            go null, frame



  ###
  function append
  Append rows from multiple frames to form a new frame.
  ---
  frames... -> Frame
  ---
  frames: [Frame]
    The frames to append.
  ---
  append(f1, f2)
  Create and append three frames.
  ```
  odd = h2o.apply [], -> vector 1, 3, 5, 7, 9
  even = h2o.apply [], -> vector 2, 4, 5, 8, 10
  prime = h2o.apply [], -> vector 2, 3, 5, 7, 11
  appended = h2o.apply [ odd, even, prime ], (odd, even, prime) ->
    append combine(odd, even), combine(prime, even), combine(odd, prime)

  appended (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ---
  append(f1, f1, f1)
  Append a frame to itself.
  ```
  odd = h2o.apply [], -> vector 1, 3, 5, 7, 9
  even = h2o.apply [], -> vector 2, 4, 5, 8, 10
  frame = h2o.apply [ odd, even ], (odd, even) -> combine odd, even
  repeated = h2o.apply frame, (frame) -> append frame, frame, frame
  repeated (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  # h2o.groupBy airlines, [ year, month ], [
  #   h2o.mean delay
  #   h2o.sum foo
  # ]
  # "ignore" -- count NAs, but don't include them in sums, mins, or maxss
  # "rm"       --  do not count NAs, do not include them in sums mins maxs
  # "all"       -- count NAs, include them in mins, maxs, means

  #
  # Needs 4 args
  # "min" #2 "ignore" "min_col3"
  # aggregate type, column index, na method, aggregate column name

  groupBy = method (go) ->
    go new Error 'Not implemented'


  ###
  function to
  Create a sequence of integers.
  ---
  begin end -> Span
  ---
  begin: Number
    Start index
  end: Number
    End index
  ---
  to()
  Create a vector with the values 10 to 20.
  ```
  h2o.apply [], (-> vector to 10, 20), (error, result) ->
    if error
      fail
    else
      h2o.print result
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function vector
  Create a new vector of numbers and/or spans.
  ---
  elements... -> Vector
  ---
  elements: [Number|Span]
    The values and/or spans that need to be combined.
  ---
  vector()
  Create a vector with the values `[4, 2, 42, 13, 14, 15, 16, 17]`.
  ```
  h2o.apply [], (-> vector 4, 2, 42, to 13, 17), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function replicate
  Replicate the values in a given vector, repeating as many times as is necessary to create a new vector of the given target length.
  ---
  vector length -> Vector
  ---
  vector: Vector
    The source vector whose values to replicate.
  length: Number
    The desired length of the target vector.
  ---
  replicate(sequence(5), 15)
  Repeat the sequence `[1, 2, 3, 4, 5]` thrice.
  ```
  h2o.apply [], (-> replicate sequence(5), 15), (error, result) ->
    if error
      fail
    else
      h2o.print result
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function sequence
  Generate regular sequences.
  ---
  end -> Vector
  start end -> Vector
  start end step -> Vector
  ---
  start: Number
    The starting value of the sequence.
  end: Number
    The end value of the sequence.
  step: Number
    Increment of the sequence.
  ---
  sequence(10)
  Create a vector with values from 1 to 10.
  ```
  h2o.apply [], (-> sequence 10), (error, result) ->
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
  h2o.apply [], (-> sequence 11, 20), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ---
  sequence(11, 12, 0.1)
  Create a vector with values from 11 to 12, step by 0.1.
  ```
  h2o.apply [], (-> sequence 11, 12, 0.1), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function toFactor
  Encode a vector as a factor. The terms 'category', 'categorical column', 'enumerated type' are also used for factors.
  ---
  vector -> Factor
  ---
  vector: Vector
    The vector to be encoded.
  ---
  toFactor()
  Create a factor from a vector.
  ```
  h2o.apply [], (-> toFactor replicate sequence(2011, 2015), 100), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function toDate
  Create a date vector from a factor or a string vector.
  ---
  factor pattern -> Vector<Date>
  vector pattern -> Vector<Date>
  ---
  factor: Factor
    The source vector.
  vector: Vector<String>
    The source vector.
  pattern: String
    The pattern to use for parsing dates. The pattern syntax is [documented here](http://www.joda.org/joda-time/apidocs/org/joda/time/format/DateTimeFormat.html).
  ---
  toDate()
  Create a date vector from a factor.
  ```
  h2o.apply [], (-> toDate toString(replicate(vector(20101210, 20121210), 100)), "yyyymmdd"), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function toString
  Create a string vector from a factor.
  ---
  factor -> Vector<String>
  ---
  factor: Factor
    The source factor.
  ---
  toString()
  Create a string vector from a factor.
  ```
  h2o.apply [], (-> toString toFactor sequence(100)), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function toNumber
  Create a numeric vector from a factor or a non-numeric vector.
  ---
  vector -> Vector<Number>
  factor -> Vector<Number>
  ---
  vector: Vector
    The source vector.
  factor: Factor
    The source factor.
  ---
  toNumber()
  Create a numeric vector from a factor.
  ```
  h2o.apply [], (-> toNumber toFactor sequence 100) , (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      h2o.removeAll ->
        pass
  ###

  ###
  function multiply
  Matrix-multiply two numeric frames. The number of columns on the left frame must equal the number of rows in the right frame.
  ---
  frame1 frame2 -> Frame
  ---
  frame1: Frame
    A numeric frame.
  frame2: Frame
    A numeric frame.
  ---
  multiply()
  Matrix-multiply two frames.
  ```
  seq = h2o.apply [], -> sequence 5
  frame = h2o.apply seq, (a) -> combine a, a, a, a, a
  h2o.apply frame, ((a) -> multiply a, a), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      pass
  ###

  ###
  function transpose
  Transpose a numeric frame.
  ---
  frame -> Frame
  ---
  frame: Frame
    A numeric frame.
  ---
  transpose()
  Transpose a frame.
  ```
  seq = h2o.apply [], -> sequence 5
  frame = h2o.apply seq, (a) -> combine a, a, a, a, a
  h2o.apply frame, ((a) -> transpose a), (error, result) ->
    if error
      fail
    else
      h2o.print.columns result.col_names, result.head
      pass
  ###

  # Files
  importFile: importFile
  importFiles: importFiles
  uploadFile: uploadFile #TODO handle multiple files for consistency with parseFiles()
  parseFiles: parseFiles

  # Frames
  createFrame: createFrame
  createVector: createVector
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
  waitFor: waitFor
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
  select: selectVector
  map: mapVectors
  apply: apply
  sapply: sapplyToFrame
  resolve: resolve
  # groupBy: groupBy

  # Types
  error: H2OError

  # Debugging
  dump: dump
  print: print
  lift: fj.lift

module.exports = lib
