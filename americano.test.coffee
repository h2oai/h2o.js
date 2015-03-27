map = [
  [
    '(, (return (+ %A %B)))'
    ['A', 'B']
    (a, b) -> a + b
  ]
  [
    '(, (= b null) (= b (, (= %A (+ %A #1)) (- %A #1))) (return b))'
    ['A']
    (a) ->
      b = a++
      b
  ]
  [
    '(, (= b null) (= b (= %A (+ %A #1))) (return b))'
    ['A']
    (a) ->
      b = ++a
      b
  ]
  [ 
    '(, (= c null) (= c (+ %A %B)) (return c))'
    ['A', 'B']
    (a, b) ->
      c = a + b
      c
  ]
]

module.exports =
  map: map
