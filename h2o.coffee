request = require 'request'


lib = {}

#
# Proxy
#

http = (method, path, opts, go) ->
  req = switch method
    when 'GET'
      $.getJSON path
    when 'POST'
      $.post path, opts
    when 'DELETE'
      $.ajax url: path, type: method
    when 'UPLOAD'
      $.ajax
        url: path
        type: 'POST'
        data: opts
        cache: no
        contentType: no
        processData: no

  req.done (data, status, xhr) ->

    try
      go null, data
    catch error
      go new Flow.Error "Error processing #{method} #{path}", error

  req.fail (xhr, status, error) ->

    response = xhr.responseJSON
    
    cause = if response?.__meta?.schema_type is 'H2OError'
      serverError = new Flow.Error response.exception_msg
      serverError.stack = "#{response.dev_msg} (#{response.exception_type})" + "\n  " + response.stacktrace.join "\n  "
      serverError
    else if error?.message
      new Flow.Error error.message
    else if status is 0
      new Flow.Error 'Could not connect to H2O'
    else if isString error
      new Flow.Error error
    else
      new Flow.Error 'Unknown error'

    go new Flow.Error "Error calling #{method} #{path} with opts #{JSON.stringify opts}", cause

doUpload = (path, formData, go) -> http 'UPLOAD', path, formData, go
doDelete = (path, go) -> http 'DELETE', path, null, go

mapWithKey = (obj, f) ->
  result = []
  for key, value of obj
    result.push f value, key
  result

composePath = (path, opts) ->
  if opts
    params = mapWithKey opts, (v, k) -> "#{k}=#{v}"
    path + '?' + join params, '&'
  else
    path

requestWithOpts = (path, opts, go) ->
  doGet (composePath path, opts), go

encodeArrayForPost = (array) -> 
  if array
    if array.length is 0
      null 
    else 
      "[#{join (map array, (element) -> if isNumber element then element else "\"#{element}\""), ','}]"
  else
    null

encodeObject = (source) ->
  target = {}
  for k, v of source
    target[k] = encodeURIComponent v
  target

encodeObjectForPost = (source) ->
  target = {}
  for k, v of source
    target[k] = if isArray v then encodeArrayForPost v else v
  target

unwrap = (go, transform) ->
  (error, result) ->
    if error
      go error
    else
      go null, transform result



lib.connect = (baseUrl='http://localhost:54321') ->

  doGet = (url, go) ->
    opts = 
      url: "#{baseUrl}#{url}"
      json: yes
    request opts, (error, response, body) -> go error, body

  doPost = (url, form, go) ->
    opts =
      url: "#{baseUrl}#{url}"
      form: form
      json: yes
    request.post opts, (error, response, body) -> go error, body

  createFrame = (opts, go) ->
    doPost '/2/CreateFrame.json', opts, go

  splitFrame = (frameKey, splitRatios, splitKeys, go) ->
    opts =
      dataset: frameKey
      ratios: encodeArrayForPost splitRatios
      dest_keys: encodeArrayForPost splitKeys
    doPost '/2/SplitFrame.json', opts, go

  getFrames = (go) ->
    doGet '/3/Frames.json', (error, result) ->
      if error
        go error
      else
        go null, result.frames

  getFrame = (key, go) ->
    doGet "/3/Frames.json/#{encodeURIComponent key}", (error, result) ->
      if error
        go error
      else
        go null, head result.frames

  deleteFrame = (key, go) ->
    doDelete "/3/Frames.json/#{encodeURIComponent key}", go

  getRDDs = (go) ->
    doGet '/3/RDDs.json', (error, result) ->
      if error
        go error
      else
        go null, result.rdds

  getColumnSummary = (key, column, go) ->
    doGet "/3/Frames.json/#{encodeURIComponent key}/columns/#{encodeURIComponent column}/summary", (error, result) ->
      if error
        go error
      else
        go null, head result.frames

  getJobs = (go) ->
    doGet '/2/Jobs.json', (error, result) ->
      if error
        go new Flow.Error 'Error fetching jobs', error
      else
        go null, result.jobs 

  getJob = (key, go) ->
    doGet "/2/Jobs.json/#{encodeURIComponent key}", (error, result) ->
      if error
        go new Flow.Error "Error fetching job '#{key}'", error
      else
        go null, head result.jobs

  cancelJob = (key, go) ->
    doPost "/2/Jobs.json/#{encodeURIComponent key}/cancel", {}, (error, result) ->
      if error
        go new Flow.Error "Error canceling job '#{key}'", error
      else
        debug result
        go null

  #FIXME
  requestImportFiles = (paths, go) ->
    tasks = map paths, (path) ->
      (go) ->
        requestImportFile path, go
    (Flow.Async.iterate tasks) go

  importFile = (path, go) ->
    opts = path: encodeURIComponent path
    requestWithOpts '/2/ImportFiles.json', opts, go

  #TODO
  requestParseSetup = (sourceKeys, go) ->
    opts =
      source_keys: encodeArrayForPost sourceKeys
    doPost '/2/ParseSetup.json', opts, go

  #TODO
  requestParseSetupPreview = (sourceKeys, parseType, separator, useSingleQuotes, checkHeader, columnTypes, go) ->
    opts = 
      source_keys: encodeArrayForPost sourceKeys
      parse_type: parseType
      separator: separator
      single_quotes: useSingleQuotes
      check_header: checkHeader
      column_types: encodeArrayForPost columnTypes
    doPost '/2/ParseSetup.json', opts, go

  parse = (sourceKeys, destinationKey, parseType, separator, columnCount, useSingleQuotes, columnNames, columnTypes, deleteOnDone, checkHeader, chunkSize, go) ->
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
    doPost '/2/Parse.json', opts, go

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
    requestWithOpts '/3/Models.json', opts, (error, result) ->
      if error
        go error, result
      else
        go error, patchUpModels result.models

  getModel = (key, go) ->
    doGet "/3/Models.json/#{encodeURIComponent key}", (error, result) ->
      if error
        go error, result
      else
        go error, head patchUpModels result.models

  deleteModel = (key, go) ->
    doDelete "/3/Models.json/#{encodeURIComponent key}", go

  getModelBuilders = (go) ->
    doGet "/3/ModelBuilders.json", go

  getModelBuilder = (algo, go) ->
    doGet "/3/ModelBuilders.json/#{algo}", go

  requestModelInputValidation = (algo, parameters, go) ->
    doPost "/3/ModelBuilders.json/#{algo}/parameters", (encodeObjectForPost parameters), go

  buildModel = (algo, parameters, go) ->
    _.trackEvent 'model', algo
    doPost "/3/ModelBuilders.json/#{algo}", (encodeObjectForPost parameters), go

  predict = (destinationKey, modelKey, frameKey, go) ->
    opts = if destinationKey
      destination_key: destinationKey
    else
      {}

    doPost "/3/Predictions.json/models/#{encodeURIComponent modelKey}/frames/#{encodeURIComponent frameKey}", opts, (error, result) ->
      if error
        go error
      else
        go null, head result.model_metrics

  getPrediction = (modelKey, frameKey, go) ->
    doGet "/3/ModelMetrics.json/models/#{encodeURIComponent modelKey}/frames/#{encodeURIComponent frameKey}", (error, result) ->
      if error
        go error
      else
        go null, head result.model_metrics

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
      doGet "/3/ModelMetrics.json/models/#{encodeURIComponent modelKey}/frames/#{encodeURIComponent frameKey}", go
    else if modelKey
      doGet "/3/ModelMetrics.json/models/#{encodeURIComponent modelKey}", go
    else if frameKey
      doGet "/3/ModelMetrics.json/frames/#{encodeURIComponent frameKey}", go
    else
      doGet "/3/ModelMetrics.json", go

  uploadFile = (key, formData, go) ->
    doUpload "/3/PostFile.json?destination_key=#{encodeURIComponent key}", formData, go

  #TODO
  requestCloud = (go) ->
    doGet '/1/Cloud.json', go

  #TODO
  requestTimeline = (go) ->
    doGet '/2/Timeline.json', go

  #TODO
  requestProfile = (depth, go) ->
    doGet "/2/Profiler.json?depth=#{depth}", go

  #TODO
  requestStackTrace = (go) ->
    doGet '/2/JStack.json', go

  #TODO
  requestRemoveAll = (go) ->
    doDelete '/1/RemoveAll.json', go

  #TODO
  requestLogFile = (nodeIndex, fileType, go) ->
    doGet "/3/Logs.json/nodes/#{nodeIndex}/files/#{fileType}", go

  #TODO
  requestNetworkTest = (go) ->
    doGet '/2/NetworkTest.json', go

  #TODO
  requestAbout = (go) ->
    doGet '/3/About.json', go

  getSchemas = (go) ->
    doGet '/1/Metadata/schemas.json', go

  getSchema = (name, go) ->
    doGet "/1/Metadata/schemas.json/#{encodeURIComponent name}", go

  #TODO
  requestEndpoints = (go) ->
    doGet '/1/Metadata/endpoints.json', go

  #TODO
  requestEndpoint = (index, go) ->
    doGet "/1/Metadata/endpoints.json/#{index}", go



  shutdown = (go) ->
    doPost "/2/Shutdown.json", {}, go

  getSchemas: getSchemas
  getSchema: getSchema
  shutdown: shutdown

module.exports = lib
