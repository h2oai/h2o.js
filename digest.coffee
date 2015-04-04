_ = require 'lodash'
fs = require 'fs-extra'
path = require 'path'
yaml = require 'js-yaml'
esprima = require 'esprima'
EOL = "\n"

words = (str) -> str.split /\s+/g
read = (src) ->
  console.log "Reading #{src}"
  fs.readFileSync src, encoding: 'utf8'

collectComments = (node, comments) ->
  if _.isArray node
    for child in node
      collectComments child, comments
  else if _.isObject node
    for key, child of node
      if key is 'comment'
        comments.push child.trim()
      else
        collectComments child, comments
  comments

parseFunc = (meta, description) ->
  _.defaults meta,
    syntax: {}
    parameters: {}

  syntax = for k, v of meta.syntax
    inputs: words k
    output: words v.trim()

  parameters = for k, v of meta.parameters
    [ name, types... ] = words k
    name: name
    type: types
    description: v.trim()

  type: 'func'
  name: meta['function']
  description: description
  syntax: syntax
  parameters: parameters

parseType = (meta, description) ->
  type: 'type'
  name: meta.type
  description: description

parseMetadata = (source, parse) ->
  [ header, description ] = source.split /\-{3,}/
  parse (yaml.safeLoad header), description.trim()

parseComment = (source) ->
  if /^function\s*:/.test source
    parseMetadata source, parseFunc
  else if /^type\s*:/.test source
    parseMetadata source, parseType
  else
    undefined

dedentComment = (comment) ->
  lines = comment
    .split EOL
    .filter (line) -> line.trim().length > 0

  minIndent = Number.POSITIVE_INFINITY # yeah, right.
  for line in lines when line.trim()
    indent = (line.match /^\s*/)[0].length
    minIndent = indent if indent < minIndent

  lines
    .map (line) -> line.slice minIndent
    .join EOL

extractMetadata = (source) ->
  program = esprima.parse source, comment: yes
  program.comments
    .filter (node) -> node.type is 'Block'
    .map (node) -> parseComment dedentComment node.value
    .filter (node) -> node?

digest = (sourceFiles) ->
  blocksByFile = for sourceFile in sourceFiles
    extractMetadata read sourceFile

  blocks = _.groupBy (_.flatten blocksByFile), 'type'

  types: blocks.type ? []
  functions: blocks.func ? []

module.exports = digest
