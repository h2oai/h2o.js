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
    '"null"'
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
    'random() without seed'
    '(h2o.runif %A #-1)'
    ['A']
    (a) -> random a
  ]
  [
    'random() with seed'
    '(h2o.runif %A #42)'
    ['A']
    (a) -> random a, 42
  ]
  [
    'Fails on select using float index'
    null
    ['A']
    (a) -> a[10.5]
  ]
  [
    'select using index'
    '([ %A "null" #10)'
    ['A']
    (a) -> a[10]
  ]
  [
    'select using integer index'
    '([ %A "null" #10)'
    ['A']
    (a) -> a[10.0]
  ]
  [
    'select using computed members'
    '([ %A "null" (+ %B #5))'
    ['A', 'B']
    (a, b) -> a[b + 5]
  ]
  [
    'select on computed object'
    '([ (+ %A %B) "null" #10)'
    ['A', 'B']
    (a, b) -> (a + b)[10]
  ]
  [
    'select using label (double quotes)'
    '([ %A "null" (slist "foo bar"))'
    ['A']
    (a) -> a["foo bar"]
  ]
  [
    'select using label (single quotes)'
    '([ %A "null" (slist "foo bar"))'
    ['A']
    (a) -> a['foo bar']
  ]
  [
    'select using label (literal member)'
    '([ %A "null" (slist "foo"))'
    ['A']
    (a) -> a.foo
  ]
  [
    'select multiple using labels'
    '([ %A "null" (slist "foo" "bar" "baz"))'
    ['A']
    (a) -> select a, labels "foo", "bar", "baz"
  ]
  [
    'select using frame'
    '([ %A "null" %B)'
    ['A', 'B']
    (a, b) -> select a, b
  ]
  [
    'select using indices/spans'
    '([ %A "null" (llist #10 #20 (: #30 #40)))'
    ['A']
    (a) -> select a, indices 10, 20, span 30, 40
  ]
  [
    'select using expression'
    '([ %A "null" (g ([ %A "null" (slist "foo")) #10))'
    ['A']
    (a) -> select a, a.foo > 10
  ]
  [
    'filter using frame'
    '([ %A %B "null")'
    ['A', 'B']
    (a, b) -> filter a, b
  ]
  [
    'filter using indices/spans'
    '([ %A (llist #10 #20 (: #30 #40)) "null")'
    ['A']
    (a) -> filter a, indices 10, 20, span 30, 40
  ]
  [
    'filter using expression'
    '([ %A (g ([ %A "null" (slist "foo")) #10) "null")'
    ['A']
    (a) -> filter a, a.foo > 10
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
    'replicate'
    '(rep_len %A #1000)'
    ['A']
    (a) -> replicate a, 1000
  ]
  [
    'span'
    '(: #10 #20)'
    []
    -> span 10, 20
  ]
  [
    'combine numbers'
    '(c #1 #2 #3)'
    []
    -> combine 1, 2, 3
  ]
  [
    'combine numbers and spans'
    '(c #1 #2 #3 (: #10 #20))'
    []
    -> combine 1, 2, 3, span 10, 20
  ]
  [
    'sequence() fails without args'
    null
    []
    -> sequence()
  ]
  [
    'sequence 10'
    '(seq_len #10)'
    []
    -> sequence 10
  ]
  [
    'sequence 10, 20'
    '(seq #10 #20 #1)'
    []
    -> sequence 10, 20
  ]
  [
    'sequence 10, 20, 2'
    '(seq #10 #20 #2)'
    []
    -> sequence 10, 20, 2
  ]
  [
    'sequence() fails with 3+ args'
    null
    []
    -> sequence 10, 20, 30, 40
  ]
  [
    'multiply'
    '(x %A %B)'
    ['A', 'B']
    (a, b) -> multiply a, b
  ]
  [
    'transpose'
    '(t %A)'
    ['A']
    (a) -> transpose a
  ]
  [
    'map'
    [
      '(apply %A #1 %anon)'
      [ 
        name: 'anon'
        expr: '(def anon "b" (+ (* %A %b) #10))'
      ]
    ]
    ['A']
    (a) -> map a, (b) -> a * b + 10
  ]
  [
    'collect'
    [
      '(apply %A #2 %anon)'
      [ 
        name: 'anon'
        expr: '(def anon "b" (+ (* %A %b) #10))'
      ]
    ]
    ['A']
    (a) -> collect a, (b) -> a * b + 10
  ]
]

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
