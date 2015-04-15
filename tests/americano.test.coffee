_ = require 'lodash'
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
    'Unary !'
    '(not %A)'
    ['A']
    (a) -> not a
  ]
  [
    'Unary +'
    '(as.numeric %A)'
    ['A']
    (a) -> +a
  ]
  [
    'Unary -10'
    '#-10'
    ['A']
    (a) -> -10
  ]
  [
    'Unary -a'
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
    'Binary =='
    '(n %A %B)'
    ['A', 'B']
    `function(a, b){ return a == b; }`
  ]
  [
    'Binary ==='
    '(n %A %B)'
    ['A', 'B']
    (a, b) -> a is b
  ]
  [
    'Binary !='
    '(N %A %B)'
    ['A', 'B']
    `function(a, b){ return a != b; }`
  ]
  [
    'Binary !=='
    '(N %A %B)'
    ['A', 'B']
    (a, b) -> a isnt b
  ]
  [
    'Binary <'
    '(l %A %B)'
    ['A', 'B']
    (a, b) -> a < b
  ]
  [
    'Binary <='
    '(L %A %B)'
    ['A', 'B']
    (a, b) -> a <= b
  ]
  [
    'Binary >'
    '(g %A %B)'
    ['A', 'B']
    (a, b) -> a > b
  ]
  [
    'Binary >='
    '(G %A %B)'
    ['A', 'B']
    (a, b) -> a >= b
  ]
  [
    'Binary +'
    '(+ %A %B)'
    ['A', 'B']
    (a, b) -> a + b
  ]
  [
    'Binary -'
    '(- %A %B)'
    ['A', 'B']
    (a, b) -> a - b
  ]
  [
    'Binary *'
    '(* %A %B)'
    ['A', 'B']
    (a, b) -> a * b
  ]
  [
    'Binary /'
    '(/ %A %B)'
    ['A', 'B']
    (a, b) -> a / b
  ]
  [
    'Binary %'
    '(mod %A %B)'
    ['A', 'B']
    (a, b) -> a % b
  ]
  [
    'Fails on binary <<'
    null
    ['A', 'B']
    (a, b) -> a << b
  ]
  [
    'Fails on binary >>'
    null
    ['A', 'B']
    (a, b) -> a >> b
  ]
  [
    'Fails on binary >>>'
    null
    ['A', 'B']
    (a, b) -> a >>> b
  ]
  [
    'Fails on binary |'
    null
    ['A', 'B']
    (a, b) -> a | b
  ]
  [
    'Fails on binary ^'
    null
    ['A', 'B']
    (a, b) -> a ^ b
  ]
  [
    'Fails on binary &'
    null
    ['A', 'B']
    (a, b) -> a & b
  ]
  [
    'Fails on binary in'
    null
    ['A', 'B']
    (a, b) -> a of b
  ]
  [
    'Fails on binary instanceof'
    null
    ['A', 'B']
    (a, b) -> a instanceof b
  ]
  [
    'Logical &&'
    '(& %A %B)'
    ['A', 'B']
    (a, b) -> a && b
  ]
  [
    'Logical ||'
    '(| %A %B)'
    ['A', 'B']
    (a, b) -> a || b
  ]
  [
    'Literal NaN'
    '#NaN'
    []
    -> NaN
  ]
  [
    'Literal null'
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
  [
    'Fails on non-literal computed members'
    null
    ['A']
    (a) -> a[5 + 5]
  ]
  [
    'Fails on column slice by float'
    null
    ['A']
    (a) -> a[10.5]
  ]
  [
    'Column slice by index'
    '([ %A "null" #10)'
    ['A']
    (a) -> a[10]
  ]
  [
    'Column slice by integer index'
    '([ %A "null" #10)'
    ['A']
    (a) -> a[10.0]
  ]
  [
    'Fails on computed slicee'
    null
    ['A', 'B']
    (a, b) -> (a + b)[10]
  ]
  [
    'Slice by label (double quotes)'
    '([ %A "null" (slist "foo bar"))'
    ['A']
    (a) -> a["foo bar"]
  ]
  [
    'Slice by label (single quotes)'
    '([ %A "null" (slist "foo bar"))'
    ['A']
    (a) -> a['foo bar']
  ]
  [
    'Slice by label (literal member)'
    '([ %A "null" (slist "foo"))'
    ['A']
    (a) -> a.foo
  ]
  [
    'bind'
    '(cbind %A %B %C %D)'
    ['A', 'B', 'C', 'D']
    (a, b, c, d) -> bind a, b, c, d
  ]
  [
    'concat'
    '(rbind %A %B %C %D)'
    ['A', 'B', 'C', 'D']
    (a, b, c, d) -> concat a, b, c, d
  ]
  [
    'multiply'
    '(x %A %B)'
    ['A', 'B']
    (a, b) -> multiply a, b
  ]
  [
    'transpose'
    '(t %A %B)'
    ['A', 'B']
    (a, b) -> transpose a, b
  ]
  [
    'filter'
    '([ %A (g ([ %A "null" (slist "foo")) #10) "null")'
    ['A']
    (a) -> filter a, -> a.foo > 10
  ]
  [
    'apply'
    [
      '(apply %A #1 %anon)'
      [ 
        name: 'anon'
        expr: '(def anon "b" (+ (* %A %b) #10))'
      ]
    ]
    ['A']
    (a) -> apply a, (b) -> a * b + 10
  ]
  [
    'sapply'
    [
      '(apply %A #2 %anon)'
      [ 
        name: 'anon'
        expr: '(def anon "b" (+ (* %A %b) #10))'
      ]
    ]
    ['A']
    (a) -> sapply a, (b) -> a * b + 10
  ]
]

# TODO
# apply(frame, function)
# sapply(frame, function)
# slice(begin, end)
# combine
# replicate
# sequence

test 'transpiler.map', (t) ->
  for [ message, expected, symbols, func ] in testCases
    if expected is null
      t.throws (-> transpiler.map(symbols, func)), undefined, message
    else if _.isArray expected
      [ expectedAst, expectedFuncs ] = expected
      [ actualAst, actualFuncs ] = transpiler.map symbols, func
      ast = expectedAst
      t.equal actualFuncs.length, expectedFuncs.length, message + ' (func count)'
      for el, i in expectedFuncs
        al = actualFuncs[i]
        t.equal al.expr, el.expr.split(el.name).join(al.name), message + ' (func)'
        ast = ast.split(el.name).join(al.name)
      t.equal ast, actualAst, message
    else
      [ actualAst, actualFuncs] = transpiler.map symbols, func
      t.equal actualAst, expected, message

  t.end()
