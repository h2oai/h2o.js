map = [
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
    'Fails on unsupported unary operator'
    null
    ['A']
    (a) -> ~a
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

module.exports =
  map: map
