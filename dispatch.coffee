_ = require 'lodash'

_userTypes = []

typeOf = (a) ->

  return 'Undefined' if _.isUndefined a
  return 'Null' if _.isNull a
  return 'Finite' if _.isFinite a
  return 'Number' if _.isNumber a
  return 'String' if _.isString a
  return 'Boolean' if _.isBoolean a
  return 'Array' if (_.isArray a) or (_.isArguments a)
  return 'Date' if _.isDate a
  return 'Error' if _.isError a
  return 'RegExp' if _.isRegExp a

  for type in _userTypes when type.check a
    return type.name
    
  return 'Function' if _.isFunction a 
  return 'Object' if _.isObject a

  return 'Unknown'

typesOf = (args) ->
  for arg in args
    typeOf arg

signatureOf = (args) ->
  (typesOf args).join ', '

sanitize = (expected) ->
  expected
    .replace /\s+/g, ''
    .split ','
    .join ', '

validate = (_jumps) ->
  jumps = {}
  for expected, jump of _jumps
    jumps[sanitize expected] = jump
  jumps

dispatch = (_jumps) ->
  jumps = validate _jumps 
  (args...) ->
    actual = signatureOf args
    for expected, jump of jumps when expected is actual
      return jump.apply null, args
    
    throw new Error "Illegal arguments. Expected one of [#{_.keys(jumps).join ' | '}]. Found (#{actual})."
    
dispatch.register = (name, check) ->
  _userTypes.push
    name: name
    check: check

module.exports = dispatch
