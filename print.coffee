EOL = require('os').EOL
_ = require 'lodash'

repeatChar = (count, char) ->
  if count
    (Array count + 1).join char
  else
    ''

repeatChars = (counts, char) ->
  for count in counts
    repeatChar count, char

unwrap = (string) ->
  string.replace /[\r\n\t]/g, ' '

clampWidths = (widths, maxWidth) ->
  for width in widths
    if width > maxWidth then maxWidth else width

computeTableWidth = (widths) ->
  total = 0
  for width in widths
    total += width
  total

printRow_ = (pads, before, separator, after) -> (values) ->
  cells = for pad, i in pads
    value = values[i]
    content = if value? then (unwrap value) else ''
    (content + pad).slice 0, pad.length
  "#{before}#{cells.join separator}#{after}"

printTable = (table, opts) ->
  widths = clampWidths table.widths, opts.maxWidth
  borders = repeatChars widths, '-'
  pads = repeatChars widths, ' '

  rule = "+-#{ borders.join '-+-' }-+"
  printRow = printRow_ pads, '| ', ' | ', ' |'

  lines = []

  lines.push rule
  for row in table.headers
    lines.push printRow row
  lines.push rule

  for row in table.rows
    lines.push printRow row

  lines.push rule
  lines.push ''

  lines.join EOL

sliceTable = (table, begin, end) ->
  headers = for row in table.headers
    row.slice begin, end
  rows = for row in table.rows
    row.slice begin, end
  widths = table.widths.slice begin, end

  createPrintableTable headers, rows, widths

wrapAndPrintTable = (table, opts) ->
  { maxWidth } = opts
  totalWidth = computeTableWidth table.widths
  if totalWidth > maxWidth and table.widths.length
    tables = []
    begin = 0
    end = 1
    # inefficient
    while end < table.widths.length
      widths = table.widths.slice begin, end
      span = computeTableWidth widths
      if span > maxWidth
        tables.push printTable (sliceTable table, begin, end - 1), opts
        begin = end - 1
      end++
    tables.push printTable (sliceTable table, begin, end), opts
    tables.join EOL
  else
    printTable table, opts

normalize = (header) ->
  rowCount = 0
  for labels in header
    rowCount = labels.length if labels.length > rowCount

  rows = []
  for i in [0 ... rowCount]
    row = []
    for labels in header
      row.push labels[i]
    rows.push row
  rows

createPrintableTable = (headers, rows, widths) ->
  headers: headers
  rows: rows
  widths: widths

createLabels = (key) ->
  labels = for label, i in key.split '\0'
    (if i is 0 then '' else repeatChar i * 2, ' ') + label
  labels

createTable = (header, rows, opts) ->
  columnLabels = []
  widths = []

  for key, i in header
    labels = createLabels key

    width = 0
    if userWidth = opts.widths[key]
      width = userWidth
    else
      for label in labels
        width = len if width < (len = label.length)

      for row in rows
        cell = row[i]
        width = len if cell? and width < (len = cell.length)

    widths[i] = width
    columnLabels[i] = labels

  createPrintableTable (normalize columnLabels), rows, widths

createTableFromColumns = (_header, columns, opts) ->
  header = ('' + value for value in _header)

  widths = (heading.length for heading in header)

  rows = for i in [0 ... columns[0].length]
    new Array columns.length

  for row, i in rows
    for column, j in columns
      value = column[i]
      row[j] = cell = if value? then  '' + value else '-'
      widths[j] = len if widths[j] < (len = cell.length)

  createPrintableTable [ header ], rows, widths

tabulate = (objs, opts) ->
  dict = {}
  headers = []
  _index = 0
  rows = [] 

  for obj in objs
    row = []
    for key, value of obj
      if entry = dict[key]
        i = entry.index
      else
        i = _index++
        dict[key] = index: i
        headers[i] = key
      row[i] = value
    rows.push row

  createTable headers, rows, opts

flatten = (source, maxDepth, depth, parentKey, target) ->
  for key, value of source
    path = if parentKey then "#{parentKey}\0#{key}" else key
    if value?
      text = Object::toString.call value
      switch text
        when '[object String]'
          target[path] = unwrap value
        when '[object Number]', '[object Boolean]'
          target[path] = '' + value
        when '[object Array]'
          target[path] = unwrap JSON.stringify value
        when '[object Date]', '[object Arguments]', '[object Function]', '[object RegExp]', '[object Error]'
          target[path] = text.replace 'object ', ''
        when '[object Object]'
          if depth <= maxDepth
            flatten value, maxDepth, depth + 1, path, target
          else
            target[path] = unwrap JSON.stringify value
        else
          target[path] = text
    else
      target[path] = '-'
  return

unfurl = (source, maxIndent, indent, parentKey, rows) ->
  for key, value of source
    path = if parentKey then "#{parentKey}\0#{key}" else key
    label = indent + key
    if value?
      text = Object::toString.call value
      switch text
        when '[object String]'
          rows.push [ label, unwrap value ]
        when '[object Number]', '[object Boolean]'
          rows.push [ label, '' + value ]
        when '[object Array]'
          rows.push [ label, unwrap JSON.stringify value ]
        when '[object Date]', '[object Arguments]', '[object Function]', '[object RegExp]', '[object Error]'
          rows.push [ label, text.replace 'object ', '' ]
        when '[object Object]'
          if indent.length < maxIndent
            rows.push [ label, '' ]
            unfurl value, maxIndent, indent + '  ', path, rows
          else
            rows.push [ label, unwrap JSON.stringify value ]
        else
          rows.push [ label, text ]
    else
      rows.push [ label, '-' ]
  return

makeDefaults = (opts) ->
  _.defaults opts,
    maxWidth: 80
    maxDepth: 10
    widths: {}

print = (arg, opts={}) ->
  makeDefaults opts
  if _.isArray arg
    targets = for source in arg
      flatten source, opts.maxDepth, 0, null, target = {}
      target

    console.log wrapAndPrintTable(
      tabulate targets, opts
      opts
    )

  else if _.isObject arg
    rows = []
    unfurl arg, opts.maxDepth * 2, '', null, rows

    console.log wrapAndPrintTable(
      createTable [ 'Key', 'Value' ], rows, opts
      opts
    )

  else
    console.log arg

print.columns = (headers, columns, opts={}) ->
  makeDefaults opts
  table = createTableFromColumns headers, columns, opts
  console.log wrapAndPrintTable table, opts

module.exports = print
