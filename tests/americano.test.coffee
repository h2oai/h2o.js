_ = require 'lodash'
test = require 'tape'
transpiler = require '../americano.js'

transpileTestCases = [
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
    (a) -> random a, seed: 42
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
    (a) -> select a, at 10, 20, to 30, 40
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
    (a) -> filter a, at 10, 20, to 30, 40
  ]
  [
    'filter using expression'
    '([ %A (g ([ %A "null" (slist "foo")) #10) "null")'
    ['A']
    (a) -> filter a, a.foo > 10
  ]
  [
    'slice'
    '([ %A (g ([ %A "null" (slist "foo")) #10) (llist #10 #20 (: #30 #40)))'
    ['A']
    (a) -> slice a, a.foo > 10, at 10, 20, to 30, 40
  ]
  [
    'length'
    '(nrow %A)'
    ['A']
    (a) -> length a
  ]
  [
    'width'
    '(ncol %A)'
    ['A']
    (a) -> width a
  ]
  [
    'combine'
    '(cbind %A %B %C %D)'
    ['A', 'B', 'C', 'D']
    (a, b, c, d) -> combine a, b, c, d
  ]
  [
    'append'
    '(rbind %A %B %C %D)'
    ['A', 'B', 'C', 'D']
    (a, b, c, d) -> append a, b, c, d
  ]
  [
    'replicate'
    '(rep_len %A #1000)'
    ['A']
    (a) -> replicate a, 1000
  ]
  [
    'clone'
    '(rename %A "New Name")'
    ['A']
    (a) -> clone a, "New Name"
  ]
  [
    'rename'
    '(colnames= %A (slist "foo" "bar" "baz"))'
    ['A']
    (a) -> rename a, labels 'foo', 'bar', 'baz'
  ]
  [
    'to'
    '(: #10 #20)'
    []
    -> to 10, 20
  ]
  [
    'vector'
    '(c #1 #2 #3)'
    []
    -> vector 1, 2, 3
  ]
  [
    'vector with spans'
    '(c #7 #8 #9 (: #10 #20) #21)'
    []
    -> vector 7, 8, 9, (to 10, 20), 21
  ]
  [
    'sequence$0 fails'
    null
    []
    -> sequence()
  ]
  [
    'sequence$1'
    '(seq_len #10)'
    []
    -> sequence 10
  ]
  [
    'sequence$2'
    '(seq #10 #20 #1)'
    []
    -> sequence 10, 20
  ]
  [
    'sequence$3'
    '(seq #10 #20 #2)'
    []
    -> sequence 10, 20, 2
  ]
  [
    'sequence$4 fails'
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
    'sum$0 fails'
    null
    ['A']
    (a) -> sum()
  ]
  [
    'sum$1'
    '(sum %A %TRUE)'
    ['A']
    (a) -> sum a
  ]
  [
    'sum$2 missing=remove'
    '(sum %A %FALSE)'
    ['A']
    (a) -> sum a, missing: 'remove'
  ]
  [
    'sum$2 missing=?'
    '(sum %A %TRUE)'
    ['A']
    (a) -> sum a, missing: '?'
  ]
  [
    'sum$3 fails'
    null
    ['A']
    (a) -> sum a, no, 'why?'
  ]
  [
    'min$0 fails'
    null
    ['A']
    (a) -> min()
  ]
  [
    'min$1'
    '(min %A %TRUE)'
    ['A']
    (a) -> min a
  ]
  [
    'min$2 missing=remove'
    '(min %A %FALSE)'
    ['A']
    (a) -> min a, missing: 'remove'
  ]
  [
    'min$2 missing=?'
    '(min %A %TRUE)'
    ['A']
    (a) -> min a, missing: '?'
  ]
  [
    'min$3 fails'
    null
    ['A']
    (a) -> min a, no, 'why?'
  ]
  [
    'max$0 fails'
    null
    ['A']
    (a) -> max()
  ]
  [
    'max$1'
    '(max %A %TRUE)'
    ['A']
    (a) -> max a
  ]
  [
    'max$2 missing=remove'
    '(max %A %FALSE)'
    ['A']
    (a) -> max a, missing: 'remove'
  ]
  [
    'max$2 missing=?'
    '(max %A %TRUE)'
    ['A']
    (a) -> max a, missing: '?'
  ]
  [
    'max$3 fails'
    null
    ['A']
    (a) -> max a, no, 'why?'
  ]
  [
    'median$0 fails'
    null
    ['A']
    (a) -> median()
  ]
  [
    'median$1'
    '(median %A %TRUE)'
    ['A']
    (a) -> median a
  ]
  [
    'median$2 missing=remove'
    '(median %A %FALSE)'
    ['A']
    (a) -> median a, missing: 'remove'
  ]
  [
    'median$2 missing=?'
    '(median %A %TRUE)'
    ['A']
    (a) -> median a, missing: '?'
  ]
  [
    'median$3 fails'
    null
    ['A']
    (a) -> median a, no, 'why?'
  ]
  [
    'scale$1'
    '(scale %A %TRUE %TRUE)'
    ['A']
    (a) -> scale a
  ]
  [
    'scale$2, center=false'
    '(scale %A %FALSE %TRUE)'
    ['A']
    (a) -> scale a, center: no
  ]
  [
    'scale$2, scale=false'
    '(scale %A %TRUE %FALSE)'
    ['A']
    (a) -> scale a, scale: no
  ]
  [
    'scale$2, center=false, scale=false'
    '(scale %A %FALSE %FALSE)'
    ['A']
    (a) -> scale a, center: no, scale: no
  ]
  [
    'scale$2, center=true, scale=true'
    '(scale %A %TRUE %TRUE)'
    ['A']
    (a) -> scale a, center: yes, scale: yes
  ]
  [
    'if-else'
    '(ifelse (l %A %B) (/ %A #42) (* %B #42))'
    ['A', 'B']
    (a, b) -> return (if a < b then a / 42 else b * 42)
  ]
  [
    'map'
    [
      '(apply %A #1 %anon)'
      [ 
        name: 'anon'
        expr: '(def "anon" (slist "b") (+ (* %A %b) #10))'
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
        expr: '(def "anon" (slist "b") (+ (* %A %b) #10))'
      ]
    ]
    ['A']
    (a) -> collect a, (b) -> a * b + 10
  ]
]

test 'transpile', (t) ->
  for [ title, expected, symbols, func ] in transpileTestCases
    message = 'transpile: ' + title
    if expected is null
      t.throws (-> transpiler.transpile(symbols, func)), undefined, message
    else if _.isArray expected
      [ expectedAst, expectedFuncs ] = expected
      [ actualAst, actualFuncs ] = transpiler.transpile symbols, func
      ast = expectedAst
      t.equal actualFuncs.length, expectedFuncs.length, message + ' (func count)'
      for el, i in expectedFuncs
        al = actualFuncs[i]
        t.equal al.expr, el.expr.split(el.name).join(al.name), message + ' (func)'
        ast = ast.split(el.name).join(al.name)
      t.equal ast, actualAst, message
    else
      [ actualAst, actualFuncs] = transpiler.transpile symbols, func
      t.equal actualAst, expected, message

  t.end()


evaluationTestCases = [
  [ 'undefined', undefined, -> undefined ]
  [ 'null', ((a) -> a is null), -> null ]
  [ 'NaN', ((a) -> isNaN a), -> NaN ]
  [ 'Infinity', Infinity, -> Infinity ]
  [ 'true', true, -> true ]
  [ 'false', false, -> false ]
  [ '0', 0, -> 0 ]
  [ '1', 1, -> 1 ]
  [ 'string', 'foo', -> 'foo' ]
  [ 'Unary !', not true, -> not true ]
  [ 'Unary +', +"100", -> +"100" ]
  [ 'Unary -', -10, -> -10 ]
  [ 'Unary ~', ~9, -> ~9 ]
  [ 'Unary typeof', (typeof 'foo'), -> typeof 'foo' ]
  [ 'Unary void', undefined, -> undefined ]
  [ 'Unary delete', true, -> delete 10 ]
  [ 'Binary +', 42 + 2, -> 42 + 2 ]
  [ 'Binary -', 42 - 2, -> 42 - 2 ]
  [ 'Binary *', 42 * 2, -> 42 * 2 ]
  [ 'Binary /', 42 / 2, -> 42 / 2 ]
  [ 'Binary %', 42 % 10, -> 42 % 10 ]
  [ 'Binary ==', true, -> `"42" == 42` ]
  [ 'Binary !=', false, -> `"42" != 42` ]
  [ 'Binary ===', false, -> "42" is 42 ]
  [ 'Binary !==', true, -> "42" isnt 42 ]
  [ 'Binary <', 42 < 420, -> 42 < 420 ]
  [ 'Binary <=', 42 <= 42, -> 42 <= 42 ]
  [ 'Binary >', 42 > 41, -> 42 > 41 ]
  [ 'Binary >=', 42 >= 42, -> 42 >= 42 ]
  [ 'Binary <<', 9 << 2, -> 9 << 2 ]
  [ 'Binary >>', -9 >> 2, -> -9 >> 2 ]
  [ 'Binary >>>', -9 >>> 2, -> -9 >>> 2 ]
  [ 'Binary |', -2 | -3, -> -2 | -3 ]
  [ 'Binary ^', 14 ^ 9, -> 14 ^ 9 ]
  [ 'Binary &', 1 & 2 & 8, -> 1 & 2 & 8 ]
  [ 'Binary in', 'PI' of Math, -> 'PI' of Math ]
  [ 'Logical false || false', false or false, -> false or false ]
  [ 'Logical false || true', false or true, -> false or true ]
  [ 'Logical true || false', true or false, -> true or false ]
  [ 'Logical true || true', true or true, -> true or true ]
  [ 'Logical false && false', false and false, -> false and false ]
  [ 'Logical false && true', false and true, -> false and true ]
  [ 'Logical true && false', true and false, -> true and false ]
  [ 'Logical true && true', true and true, -> true and true ]
  [ 'Ternary consequent', 'foo', -> return (if 'foo' is 'foo' then 'foo' else 'bar') ]
  [ 'Ternary alternate', 'bar', -> return (if 'foo' is 'bar' then 'foo' else 'bar') ]
  [ 'isFinite()', (isFinite Infinity), -> isFinite Infinity ]
  [ 'isNaN()', (isNaN NaN), -> isNaN NaN ]
  [ 'parseFloat()', (parseFloat '42.424242'), -> parseFloat '42.424242' ]
  [ 'parseInt()', (parseInt '42', 10), -> parseInt '42', 10 ]
  [ 'String.function()', 'FOO'.toLowerCase(), -> 'FOO'.toLowerCase() ]
  [ 'String.function().function()', 'FOO'.toLowerCase().toUpperCase(), -> 'FOO'.toLowerCase().toUpperCase() ]
  [ 'Number.PROPERTY', (Number.isFinite Number.POSITIVE_INFINITY), -> Number.isFinite Number.POSITIVE_INFINITY ]
  [ 'Number.function()', ((42.42424242).toFixed 2), -> (42.42424242).toFixed 2 ]
  [ 'Math.PROPERTY', (Math.PI.toFixed 2), -> Math.PI.toFixed 2 ]
  [ 'Math.function', (Math.floor 42.424242), -> Math.floor 42.424242 ]
  [ 'Undefined function', null, -> foo 10 ]
  [ 'Undefined variable', null, -> parseFloat foo ]
  [ 'Undefined member', null, -> String.foo.toString() ]
  [ 'Undefined property', null, -> String['foo'].toString() ]
  [ 'Undefined object', null, -> foo.bar 10 ]
  [ 'undefined.function()', null, -> (undefined).toString() ]
  [ 'null.function()', null, -> (null).toString() ]
]

test 'evaluate', (t) ->
  for [ title, expected, input ] in evaluationTestCases
    message = 'evaluate: ' + title
    { expression } = transpiler.parse input
    if expected is null
      t.throws (-> transpiler.evaluate expression), undefined, message
    else
      if _.isFunction expected
        t.ok expected(transpiler.evaluate expression), message
      else
        t.equal (transpiler.evaluate expression), expected, message
  t.end()

