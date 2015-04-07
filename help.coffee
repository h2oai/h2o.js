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
EOL = "\n"

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

compileCoffee = (source) ->
  coffee.compile source, bare: yes

collectTypesInUse = (func) ->
  _.flattenDeep [
    _.map func.syntax, (usage) -> usage.output.constituents
    _.map func.parameters, (param) -> if param.isFunction then [(_.pluck param.type.inputs, 'constituents'), param.type.output.constituents] else param.type.constituents
  ]

validateTypesInFunc = (typeIds, funcs) ->
  for func in funcs
    for type in collectTypesInUse func when not typeIds[type]
      throw new Error "Type [#{type}] not found in [#{func.name}] function definition"
  return

printFuncUsage = (usage) ->
  inputs = usage.inputs
    .map (input) -> linkToType input.type
    .join ', '

  '(' + inputs + ') &rarr; ' + linkToType usage.output.type

stripParagraph = (a) -> a.slice 3, a.length - 5

printFunction = (func) ->
  [ div, h3, table, tbody, tr, td, th, code, cs, js ] = template 'div', 'h3', 'table', 'tbody', 'tr', 'td', 'th', 'code', 'pre.lang-coffeescript', 'pre.lang-javascript'

  parametersTable = table tbody func.parameters.map (parameter) ->
    tr [
      td [
        bookmark '', "func-#{func.name}-#{parameter.name}"
        code parameter.name
      ]
      td code if parameter.isFunction then printFuncUsage parameter.type else linkToType parameter.type.type
      td stripParagraph marked parameter.description
    ]

  usageTable = table tbody func.syntax.map (usage) ->
    args = usage.inputs.map (input) -> link input, "#func-#{func.name}-#{input}"
    tr [
      td code "#{func.name}(#{ args.join ', ' })"
      td code '&rarr; ' + linkToType usage.output.type
    ]

  examplesSection = for example in func.examples
    div [
      div marked example.description
      cs example.code
      js compileCoffee example.code
    ]

  [
    bookmark '', "func-#{func.name}"
    h2 "#{func.name}()"
    marked func.description
    h3 'Usage'
    usageTable
    h3 'Arguments'
    parametersTable
    h3 'Examples'
    examplesSection.join EOL
  ]

termination = /^(\s+)(pass|fail)(\s*)$/gm

createRunnableExample = (title, source) ->
  code = source
    .replace termination, (match, prefix, keyword) ->
      if keyword is 'fail'
        "#{prefix}t.end error"
      else # 'pass'
        "#{prefix}t.end()"
    .split EOL
    .map (line) -> '  ' + line
    .join EOL

  """
  path = require 'path'
  h2o = require('./../../h2o.js').connect()
  test = require 'tape'

  test '#{title}', (t) ->
  #{code}
  """

createPrintableExample = (source) ->
  source.replace termination, (match, prefix, keyword) ->
    if keyword is 'fail'
      "#{prefix}console.log error"
    else # 'pass'
      "#{prefix}console.log 'OK'"

exportExamples = (outputDir, functions) ->
  commands = []
  for func in functions
    for { title, description, code } in func.examples
      throw new Error "Bad characters in example title [#{title}]" unless /^[\w,\(\) -]+$/g.test title

      coffeescript = createRunnableExample title, code
      write (path.join outputDir, "#{title}.coffee"), coffeescript

      javascript = compileCoffee coffeescript
      write (path.join outputDir, "#{title}.js"), javascript

      commands.push "require './#{title}.js'"

  write (path.join outputDir, 'index.js'), compileCoffee commands.join EOL

printTypes = (types) ->

  content = types
    .map (type) ->
      [
        bookmark '', "type-#{type.name}"
        h2 type.name
        marked type.description
      ]

  (_.flatten content).join EOL

rawTypeMappings =
  'boolean': 'Boolean'
  'string': 'String'
  'string[]': 'String[]'
  'string[][]': 'String[][]'
  'byte': 'Number'
  'byte[]': 'Number[]'
  'byte[][]': 'Number[][]'
  'byte[][][]': 'Number[][][]'
  'short': 'Number'
  'short[]': 'Number[]'
  'short[][]': 'Number[][]'
  'short[][][]': 'Number[][][]'
  'int': 'Number'
  'int[]': 'Number[]'
  'int[][]': 'Number[][]'
  'int[][][]': 'Number[][][]'
  'long': 'Number'
  'long[]': 'Number[]'
  'long[][]': 'Number[][]'
  'long[][][]': 'Number[][][]'
  'float': 'Number'
  'float[]': 'Number[]'
  'float[][]': 'Number[][]'
  'float[][][]': 'Number[][][]'
  'double': 'Number'
  'double[]': 'Number[]'
  'double[][]': 'Number[][]'
  'double[][][]': 'Number[][][]'
  'Map': 'Object'
  'IcedWrapper': 'Object'
  'IcedWrapper[][]': 'Object[][]'
  'Polymorphic': 'Object'
  'Polymorphic[][]': 'Object[][]'

toJavascriptType = (rawType) ->
  rawTypeMappings[rawType] or rawType

getSubtypes = (rawType) ->
  rawType.match /\w+/g

toDirectionLabel = (direction) ->
  switch direction
    when 'INPUT'
      'In'
    when 'INOUT'
      'In/Out'
    when 'OUTPUT'
      'Out'

toJavascriptSchemas = (dict, schemas_json) ->
  for schema in schemas_json
    fields = for field in schema.fields

      description = field.help

      if field.name is '__meta'
        null
      else
        if field.type is 'enum'
          type = 'String'
          description = field.help + ' (`' + field.values.join('`, `') + '`)'
        else if field.type is 'enum[]'
          type = 'String[]'
        else if field.schema_name isnt null
          type = field.schema_name
          unless dict[type]
            dump field
            throw new Error "Unknown schema field type [#{type}] for field [#{field.name}] in schema [#{schema.name}]"
        else
          type = toJavascriptType field.type
          constituents = getSubtypes type
          for constituent in constituents
            unless dict[constituent]
              dump field
              throw new Error "Unknown schema field type [#{type}] for field [#{field.name}] in schema [#{schema.name}]"

        directionKey = if field.direction is 'INPUT'
          'A'
        else if field.direction is 'INOUT'
          'B'
        else
          'C'

        sortKey: directionKey + field.name.toUpperCase()
        name: field.name
        type: type
        direction: toDirectionLabel field.direction
        description: description

    name: schema.name
    description: ''
    fields: _.sortBy (fields.filter (field) -> if field then yes else no), (field) -> field.sortKey

[ h2, bookmark, link ] = template 'h2', 'a name="$1"', 'a href="$1"'

linkToType = (compositeType) ->
  _.escape(compositeType)
    .replace /\w+/g, (match) ->
      if match is 'lt' or match is 'gt'
        match
      else
        link match, "#type-#{match}"

printSchemas = (schemas) ->
  [ table, tbody, tr, th, td, tdr, code, bookmark, sup ] = template 'table', 'tbody', 'tr', 'th', 'td', 'td.right', 'code', 'a name="$1"', 'sup'

  content = schemas
    .map (schema) ->
      trs = schema.fields.map (field) ->
        tr [
          tdr [
            code field.name
            '<br/>'
            code linkToType field.type
          ]
          td stripParagraph marked field.description
          td field.direction
        ]
      [
        bookmark '', "type-#{schema.name}"
        h2 schema.name
        marked schema.description
        table tbody trs
      ]

  (_.flatten content).join EOL

printFunctions = (functions) ->
  for func in functions
    for example in func.examples
      example.code = createPrintableExample example.code

  entries = for func in functions
    printFunction func

  (_.flatten entries).join EOL

main = (config) ->
  docDir = locate 'doc'

  webDir = locate 'web'
  mkdir webDir
  examplesDir = path.join webDir, 'examples'
  mkdir examplesDir

  definitions = digest config.sources, (sourceFile) -> locate sourceFile

  schemas = (JSON.parse read path.join docDir, 'schemas.json').schemas


  # Write all examples scripts to web/examples/
  exportExamples examplesDir, definitions.functions

  # dump definitions

  typeDict = _.indexBy definitions.types, (type) -> type.name
  schemaDict = _.indexBy schemas, (schema) -> schema.name

  _.defaults typeDict, schemaDict

  schemas = toJavascriptSchemas typeDict, schemas
  schemas = _.sortBy schemas, (schema) -> schema.name

  validateTypesInFunc typeDict, definitions.functions

  funcDict = _.indexBy definitions.functions, (func) -> func.category

  index_md = read path.join docDir, 'index.md'
  content = marked index_md

  [ h1, ul, li ] = template 'h1', 'ul', 'li'

  body =  [
    content
    h1 'Types'
    printTypes definitions.types
    printSchemas schemas
    h1 'Functions'
    printFunctions definitions.functions
  ]

  typeLinks = for type in definitions.types
    link type.name, "#type-#{type.name}"

  schemaLinks = for schema in schemas
    link schema.name, "#type-#{schema.name}"

  toc = typeLinks
    .concat schemaLinks
    .map (link) -> li link

  index_html = read path.join docDir, 'template', 'index.html'
  html = index_html
    .replace '{{content}}', body.join EOL
    .replace '{{toc}}', ul toc

  write (path.join webDir, 'index.html'), html

  cpn (path.join docDir, 'template', 'javascripts', 'scale.fix.js'), path.join webDir, 'javascripts', 'scale.fix.js'
  cp (path.join docDir, 'template', 'stylesheets', 'styles.css'), path.join webDir, 'stylesheets', 'styles.css'
  cpn (path.join docDir, 'template', 'stylesheets', 'swirl.png'), path.join webDir, 'stylesheets', 'swirl.png'

  console.log 'Done!'

main yaml.safeLoad read locate 'help.yml'
