_ = require 'lodash'
fs = require 'fs-extra'
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

parseHeader = (block) ->
  lines = block.split EOL
  [ type, name ] = words lines.shift()
  [ name, lines.join EOL ]

clean = (line) ->
  line.trim().replace /\s+/g, ''

parseCompositeType = (line) ->
  type: line
  constituents: line.match /\w+/g

parseFuncUsage = (line) ->
  [ inputs, output ] = line.split '->' 
  inputs: words inputs.trim()
  output: parseCompositeType output.trim()

parseFuncSyntax = (block) ->
  for line in block.split EOL
    parseFuncUsage line

parseFuncParams = (block) ->
  params = []
  for line in block.split EOL
    if /^\s+/.test line 
      if params.length isnt 0
        last = params[params.length - 1]
        last.description += (if last.description then EOL else '') + line.trim()
    else
      [ name, other ] = line.split /\s*:\s*/
      throw new Error "Type not defined for parameter [#{name}]" unless other

      if 0 <= other.indexOf '->'
        # function
        usage = parseFuncUsage other
        # inputs are types, not identifiers, so parse again
        usage.inputs = usage.inputs.map parseCompositeType
        params.push
          name: name
          isFunction: yes
          type: usage
          description: ''
      else
        params.push
          name: name
          isFunction: no
          type: parseCompositeType other
          description: ''
  params

parseFuncExample = (block) ->
  [ header, code ] = block.split /[`]{3,}/

  [ title, descriptions... ] = header.split EOL

  title: title.trim()
  description: descriptions.join EOL
  code: code.trim()

parseFunc = (headerBlock, syntaxBlock, paramsBlock, exampleBlocks...) ->
  [ name, description ] = parseHeader headerBlock

  throw new Error "No syntax defined for function [#{name}]" unless syntaxBlock
  throw new Error "No parameters defined for function [#{name}]" unless paramsBlock

  type: 'function'
  name: name
  description: description
  syntax: parseFuncSyntax syntaxBlock
  parameters: parseFuncParams paramsBlock
  examples: exampleBlocks.map parseFuncExample

parseType = (headerBlock, propertiesBlock) ->
  [ name, description ] = parseHeader headerBlock

  type: 'type'
  name: name
  description: if description?.trim() then description else 'TODO'
  properties: if propertiesBlock?.trim() then parseFuncParams propertiesBlock else []

parseMetadata = (source, parse) ->
  parse.apply null, source.split(/\-{3,}/g).map (block) -> block.trim()

parseComment = (source) ->
  if /^function\s*/.test source
    parseMetadata source, parseFunc
  else if /^type\s*/.test source
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
  functions: blocks['function'] ? []

module.exports = digest
