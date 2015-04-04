_ = require 'lodash'
fs = require 'fs-extra'
path = require 'path'
coffee = require 'coffee-script'
digest = require './digest.js'
marked = require 'marked'
mkdirp = require 'mkdirp'
highlight = require 'highlight.js'
yaml = require 'js-yaml'
template = require 'diecut'

words = (str) -> str.split /\s+/g

locate = (names...) -> path.join.apply null, [ __dirname ].concat names

read = (src) ->
  console.log "Reading #{src}"
  fs.readFileSync src, encoding: 'utf8'

write = (src, data) ->
  console.log "Writing #{src}"
  fs.outputFileSync src, data

rm = (src) -> 
  console.log "Removing #{src}"
  fs.removeSync src

cp = (src, dest) -> 
  console.log "Copying #{src} #{dest}"
  fs.copySync src, dest

cpn = (src, dest) ->
  cp src, dest unless fs.existsSync dest

mkdir = (src) ->
  console.log "Creating directory #{src}"
  mkdirp.sync src

dump = (obj) -> console.log JSON.stringify obj, null, 2

collectTypesInUse = (func) ->
  _.flattenDeep [
    _.pluck func.syntax, 'output'
    _.pluck func.parameters, 'type'
  ]

validate = (typeIds, funcs) ->
  for func in funcs
    for type in collectTypesInUse func when not typeIds[type]
      throw new Error "Type [#{type}] not found in [#{func.name}] function definition"
  return

printType = (chain) ->
  len = chain.length
  type = chain[ len - 1 ]
  i = len - 2
  while i >= 0
    token = chain[i--]
    type = if token is 'Array' then "[#{type}]" else "#{token}&lt;#{type}&gt;"
  type

printFunction = (func) ->
  [ div, table, tbody, tr, td, th ] = template 'div', 'table', 'tbody', 'tr', 'td', 'th'

  parametersTable = table tbody func.parameters.map (parameter) ->
    tr [
      td parameter.name
      td printType parameter.type
      td marked parameter.description
    ]

  usageTable = table tbody func.syntax.map (usage) ->
    tr [
      td "#{func.name}(#{ usage.inputs.join ', ' })"
      td printType usage.output
    ]

  trs = [
    tr [
      th 'Name'
      td func.name
    ]
    tr [
      th 'Description'
      td marked func.description
    ]
    tr [
      th 'Usage'
      td usageTable
    ]
    tr [
      th 'Arguments'
      td parametersTable
    ]
  ]

  table tbody trs

generateDocs = (config) ->
  outputDir = locate 'build/docs'
  mkdir outputDir

  definitions = digest config.sources, (sourceFile) -> locate sourceFile

  typeDict = _.indexBy definitions.types, (type) -> type.name
  validate typeDict, definitions.functions

  # dump definitions

  funcDict = _.indexBy definitions.functions, (func) -> func.category

  funcHtmls = for func in definitions.functions
    printFunction func

  write (path.join outputDir, 'index.html'), funcHtmls.join ''

  console.log 'Done!'

generateDocs yaml.safeLoad read locate 'help.yml'
