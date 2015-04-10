test = require 'tape'
transpiler = require '../americano.js'

testCases = [
  [
    'Fails when arg is not a function'
    null
    []
    null
  ]
  [
    'Fails on arity mismatch'
    null
    ['A', 'B']
    (a) -> a * a
  ]
  [
    'Fails if body has multiple statements'
    null
    ['A']
    (a) -> a * a; a * a
  ]
  [
    'Fails if body has no return'
    null
    ['A']
    `function(a){ foo(bar); }`
  ]
  [
    'Fails if body has unknown identifier'
    null
    ['A']
    (a) -> b
  ]
  [
    'Fails on sequence expressions'
    null
    []
    `function(){ return (b = a, a); }`
  ]
  [
    'Fails on assignment expressions'
    null
    []
    `function(){ return a = b; }`
  ]
  [
    '!'
    '(not %A)'
    ['A']
    (a) -> not a
  ]
  [
    '+'
    '(as.numeric %A)'
    ['A']
    (a) -> +a
  ]
  [
    '-'
    '(* %A #-1)'
    ['A']
    (a) -> -a
  ]
  [
    'Fails on unary ~'
    null
    ['A']
    (a) -> ~a
  ]
  [
    'Fails on unary typeof'
    null
    ['A']
    (a) -> typeof a
  ]
  [
    'Fails on unary delete'
    null
    ['A']
    (a) -> delete a.foo
  ]
  [
    'Fails on unary void'
    null
    ['A']
    (a) -> undefined
  ]
  [
    '=='
    '(n %A %B)'
    ['A', 'B']
    `function(a, b){ return a == b; }`
  ]
  [
    '==='
    '(n %A %B)'
    ['A', 'B']
    (a, b) -> a is b
  ]
  [
    '!='
    '(N %A %B)'
    ['A', 'B']
    `function(a, b){ return a != b; }`
  ]
  [
    '!=='
    '(N %A %B)'
    ['A', 'B']
    (a, b) -> a isnt b
  ]
  [
    '<'
    '(l %A %B)'
    ['A', 'B']
    (a, b) -> a < b
  ]
  [
    '<='
    '(L %A %B)'
    ['A', 'B']
    (a, b) -> a <= b
  ]
  [
    '>'
    '(g %A %B)'
    ['A', 'B']
    (a, b) -> a > b
  ]
  [
    '>='
    '(G %A %B)'
    ['A', 'B']
    (a, b) -> a >= b
  ]
  [
    '+'
    '(+ %A %B)'
    ['A', 'B']
    (a, b) -> a + b
  ]
  [
    '-'
    '(- %A %B)'
    ['A', 'B']
    (a, b) -> a - b
  ]
  [
    '*'
    '(* %A %B)'
    ['A', 'B']
    (a, b) -> a * b
  ]
  [
    '/'
    '(/ %A %B)'
    ['A', 'B']
    (a, b) -> a / b
  ]
  [
    '%'
    '(mod %A %B)'
    ['A', 'B']
    (a, b) -> a % b
  ]
  [
    'Fails on unsupported binary operators'
    null
    ['A', 'B']
    (a, b) -> a >> b
  ]
  [
    '&&'
    '(& %A %B)'
    ['A', 'B']
    (a, b) -> a && b
  ]
  [
    '||'
    '(| %A %B)'
    ['A', 'B']
    (a, b) -> a || b
  ]
  [
    'NaN'
    '#NaN'
    []
    -> NaN
  ]
  [
    'null'
    '#NaN'
    []
    -> null
  ]
  [
    'Number'
    '#42'
    []
    -> 42
  ]
  [
    'String'
    '"string"'
    []
    -> 'string'
  ]
  [
    'true'
    '%TRUE'
    []
    -> true
  ]
  [
    'false'
    '%FALSE'
    []
    -> false
  ]
]

test 'transpiler.map', (t) ->
  for [ message, expected, symbols, func ] in testCases
    if expected is null
      t.throws (-> transpiler.map(symbols, func)), undefined, message
    else
      t.equal transpiler.map(symbols, func), expected, message

  t.end()
