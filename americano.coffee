#     _____                       .__                             
#    /  _  \   _____   ___________|__| ____ _____    ____   ____  
#   /  /_\  \ /     \_/ __ \_  __ \  |/ ___\\__  \  /    \ /  _ \ 
#  /    |    \  Y Y  \  ___/|  | \/  \  \___ / __ \|   |  (  <_> )
#  \____|__  /__|_|  /\___  >__|  |__|\___  >____  /___|  /\____/ 
#          \/      \/     \/              \/     \/     \/        
#  
#  (or, the fine art of watering down a perfectly good cup of coffee)
#
# ----------------------------------------------------------------------------- 
#
# This is a Javascript-to-Rapids transpiler.
#
# Rapids is an intermediate language used by H2O for cluster computing,
#   easily mistaken for Scheme.
#
# Transpiles a proper subset of referentially transparent Javascript into
#   Rapids, which can then be sent to H2O to do parallel, distributed 
#   map, reduce, combine, filter, join operations on big data.
#
#
# "But, is it web scale?"
# 
# In short, no. This is not intended to take any arbitrary Javascript code and
#   run it distributed, or make Javascript applications scale, etc. 
#
# The idea is to allow applications written in Javascript to be able to
#   load, munge, query, manipulate and model big data(tm) using Javascript
#   functions to specify transformations and predicates, which H2O can then 
#   run parallel and distributed across a cluster.
#

_ = require 'lodash'
_uuid = require 'node-uuid'
esprima = require 'esprima'

dump = (a) -> console.log JSON.stringify a, null, 2
uuid = -> _uuid.v4().replace /\-/g, ''

#
# Mozilla SpiderMonkey/Parser API
# https://developer.mozilla.org/en-US/docs/Mozilla/Projects/SpiderMonkey/Parser_API
# 
# -----------------------------------------------------------------------------
# Node
# -----------------------------------------------------------------------------
# interface Node {
#    type: string;
#    loc: SourceLocation | null;
# }
# -----------------------------------------------------------------------------
# Programs
# -----------------------------------------------------------------------------
# 
# interface Program <: Node {
#     type: "Program";
#     body: [ Statement ];
# }
# A complete program source tree.
# 
# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
# 
# interface Function <: Node {
#     id: Identifier | null;
#     params: [ Pattern ];
#     defaults: [ Expression ];
#     rest: Identifier | null;
#     body: BlockStatement | Expression;
#     generator: boolean;
#     expression: boolean;
# }
# A function declaration or expression. The body of the function may be a block 
#  statement, or in the case of an expression closure, an expression.
# 
# -----------------------------------------------------------------------------
# Statements
# -----------------------------------------------------------------------------
# 
# interface Statement <: Node { }
# Any statement.
# 
# interface EmptyStatement <: Statement {
#     type: "EmptyStatement";
# }
# An empty statement, i.e., a solitary semicolon.
# 
# interface BlockStatement <: Statement {
#     type: "BlockStatement";
#     body: [ Statement ];
# }
# A block statement, i.e., a sequence of statements surrounded by braces.
# 
# interface ExpressionStatement <: Statement {
#     type: "ExpressionStatement";
#     expression: Expression;
# }
# An expression statement, i.e., a statement consisting of a single expression.
# 
# interface IfStatement <: Statement {
#     type: "IfStatement";
#     test: Expression;
#     consequent: Statement;
#     alternate: Statement | null;
# }
# An if statement.
# 
# interface LabeledStatement <: Statement {
#     type: "LabeledStatement";
#     label: Identifier;
#     body: Statement;
# }
# A labeled statement, i.e., a statement prefixed by a break/continue label.
# 
# interface BreakStatement <: Statement {
#     type: "BreakStatement";
#     label: Identifier | null;
# }
# A break statement.
# 
# interface ContinueStatement <: Statement {
#     type: "ContinueStatement";
#     label: Identifier | null;
# }
# A continue statement.
# 
# interface WithStatement <: Statement {
#     type: "WithStatement";
#     object: Expression;
#     body: Statement;
# }
# A with statement.
# 
# interface SwitchStatement <: Statement {
#     type: "SwitchStatement";
#     discriminant: Expression;
#     cases: [ SwitchCase ];
#     lexical: boolean;
# }
# A switch statement. The lexical flag is metadata indicating whether the 
#   switch statement contains any unnested let declarations (and therefore 
#   introduces a new lexical scope).
# 
# interface ReturnStatement <: Statement {
#     type: "ReturnStatement";
#     argument: Expression | null;
# }
# A return statement.
# 
# interface ThrowStatement <: Statement {
#     type: "ThrowStatement";
#     argument: Expression;
# }
# A throw statement.
# 
# interface TryStatement <: Statement {
#     type: "TryStatement";
#     block: BlockStatement;
#     handler: CatchClause | null;
#     guardedHandlers: [ CatchClause ];
#     finalizer: BlockStatement | null;
# }
# A try statement.
# 
# Note: Multiple catch clauses are SpiderMonkey-specific.
#
# interface WhileStatement <: Statement {
#     type: "WhileStatement";
#     test: Expression;
#     body: Statement;
# }
# A while statement.
# 
# interface DoWhileStatement <: Statement {
#     type: "DoWhileStatement";
#     body: Statement;
#     test: Expression;
# }
# A do/while statement.
# 
# interface ForStatement <: Statement {
#     type: "ForStatement";
#     init: VariableDeclaration | Expression | null;
#     test: Expression | null;
#     update: Expression | null;
#     body: Statement;
# }
# A for statement.
# 
# interface ForInStatement <: Statement {
#     type: "ForInStatement";
#     left: VariableDeclaration |  Expression;
#     right: Expression;
#     body: Statement;
#     each: boolean;
# }
# A for/in statement, or, if each is true, a for each/in statement.
# 
# Note: The for each form is SpiderMonkey-specific.
#
# interface ForOfStatement <: Statement {
#     type: "ForOfStatement";
#     left: VariableDeclaration |  Expression;
#     right: Expression;
#     body: Statement;
# }
# A for/of statement.
# 
# interface LetStatement <: Statement {
#     type: "LetStatement";
#     head: [ VariableDeclarator ];
#     body: Statement;
# }
# A let statement.
# 
# Note: The let statement form is SpiderMonkey-specific.
#
# interface DebuggerStatement <: Statement {
#     type: "DebuggerStatement";
# }
# A debugger statement.
# 
# Note: The debugger statement is new in ECMAScript 5th edition, although 
#   SpiderMonkey has supported it for years.
#
#
# -----------------------------------------------------------------------------
# Declarations
# -----------------------------------------------------------------------------
# 
# interface Declaration <: Statement { }
# Any declaration node. Note that declarations are considered statements; this 
#   is because declarations can appear in any statement context in the language 
#   recognized by the SpiderMonkey parser.
# 
# Note: Declarations in arbitrary nested scopes are SpiderMonkey-specific.
#
# interface FunctionDeclaration <: Function, Declaration {
#     type: "FunctionDeclaration";
#     id: Identifier;
#     params: [ Pattern ];
#     defaults: [ Expression ];
#     rest: Identifier | null;
#     body: BlockStatement | Expression;
#     generator: boolean;
#     expression: boolean;
# }
# A function declaration.
# 
# Note: The id field cannot be null.
# interface VariableDeclaration <: Declaration {
#     type: "VariableDeclaration";
#     declarations: [ VariableDeclarator ];
#     kind: "var" | "let" | "const";
# }
# A variable declaration, via one of var, let, or const.
# 
# interface VariableDeclarator <: Node {
#     type: "VariableDeclarator";
#     id: Pattern;
#     init: Expression | null;
# }
# A variable declarator.
# 
# Note: The id field cannot be null.
# Note: let and const are SpiderMonkey-specific.
#
#
# -----------------------------------------------------------------------------
# Expressions
# -----------------------------------------------------------------------------
# 
# interface Expression <: Node, Pattern { }
# Any expression node. Since the left-hand side of an assignment may be any 
#   expression in general, an expression can also be a pattern.
# 
# interface ThisExpression <: Expression {
#     type: "ThisExpression";
# }
# A this expression.
# 
# interface ArrayExpression <: Expression {
#     type: "ArrayExpression";
#     elements: [ Expression | null ];
# }
# An array expression.
# 
# interface ObjectExpression <: Expression {
#     type: "ObjectExpression";
#     properties: [ Property ];
# }
# An object expression.
# 
# interface Property <: Node {
#     type: "Property";
#     key: Literal | Identifier;
#     value: Expression;
#     kind: "init" | "get" | "set";
# }
# A literal property in an object expression can have either a string or number 
#   as its value. Ordinary property initializers have a kind value "init"; 
#   getters and setters have the kind values "get" and "set", respectively.
# 
# interface FunctionExpression <: Function, Expression {
#     type: "FunctionExpression";
#     id: Identifier | null;
#     params: [ Pattern ];
#     defaults: [ Expression ];
#     rest: Identifier | null;
#     body: BlockStatement | Expression;
#     generator: boolean;
#     expression: boolean;
# }
# A function expression.
# 
# interface ArrowExpression <: Function, Expression {
#     type: "ArrowExpression";
#     params: [ Pattern ];
#     defaults: [ Expression ];
#     rest: Identifier | null;
#     body: BlockStatement | Expression;
#     generator: boolean;
#     expression: boolean;
# }
# A fat arrow function expression, i.e., `let foo = (bar) => { /* body */ }`.
# 
# interface SequenceExpression <: Expression {
#     type: "SequenceExpression";
#     expressions: [ Expression ];
# }
# A sequence expression, i.e., a comma-separated sequence of expressions.
# 
# interface UnaryExpression <: Expression {
#     type: "UnaryExpression";
#     operator: UnaryOperator;
#     prefix: boolean;
#     argument: Expression;
# }
# A unary operator expression.
# 
# enum UnaryOperator {
#     "-" | "+" | "!" | "~" | "typeof" | "void" | "delete"
# }
# A unary operator token.
# 
# interface BinaryExpression <: Expression {
#     type: "BinaryExpression";
#     operator: BinaryOperator;
#     left: Expression;
#     right: Expression;
# }
# A binary operator expression.
# 
# enum BinaryOperator {
#     "==" | "!=" | "===" | "!=="
#          | "<" | "<=" | ">" | ">="
#          | "<<" | ">>" | ">>>"
#          | "+" | "-" | "*" | "/" | "%"
#          | "|" | "^" | "&" | "in"
#          | "instanceof" | ".."
# }
# A binary operator token.
# 
# Note: The .. operator is E4X-specific.
# 
# interface AssignmentExpression <: Expression {
#     type: "AssignmentExpression";
#     operator: AssignmentOperator;
#     left: Pattern;
#     right: Expression;
# }
# An assignment operator expression.
# 
# enum AssignmentOperator {
#     "=" | "+=" | "-=" | "*=" | "/=" | "%="
#         | "<<=" | ">>=" | ">>>="
#         | "|=" | "^=" | "&="
# }
# An assignment operator token.
# 
# interface UpdateExpression <: Expression {
#     type: "UpdateExpression";
#     operator: UpdateOperator;
#     argument: Expression;
#     prefix: boolean;
# }
# An update (increment or decrement) operator expression.
# 
# enum UpdateOperator {
#     "++" | "--"
# }
# An update (increment or decrement) operator token.
# 
# interface LogicalExpression <: Expression {
#     type: "LogicalExpression";
#     operator: LogicalOperator;
#     left: Expression;
#     right: Expression;
# }
# A logical operator expression.
# 
# enum LogicalOperator {
#     "||" | "&&"
# }
# A logical operator token.
# 
# interface ConditionalExpression <: Expression {
#     type: "ConditionalExpression";
#     test: Expression;
#     alternate: Expression;
#     consequent: Expression;
# }
# A conditional expression, i.e., a ternary ?/: expression.
# 
# interface NewExpression <: Expression {
#     type: "NewExpression";
#     callee: Expression;
#     arguments: [ Expression ];
# }
# A new expression.
# 
# interface CallExpression <: Expression {
#     type: "CallExpression";
#     callee: Expression;
#     arguments: [ Expression ];
# }
# A function or method call expression.
# 
# interface MemberExpression <: Expression {
#     type: "MemberExpression";
#     object: Expression;
#     property: Identifier | Expression;
#     computed: boolean;
# }
# A member expression. If computed === true, the node corresponds to a 
#   computed e1[e2] expression and property is an Expression. 
#   If computed === false, the node corresponds to a static e1.x expression 
#   and property is an Identifier.
# 
# interface YieldExpression <: Expression {
#     type: "YieldExpression";
#     argument: Expression | null;
# }
# A yield expression.
# 
# Note: yield expressions are SpiderMonkey-specific.
#
# interface ComprehensionExpression <: Expression {
#     type: "ComprehensionExpression";
#     body: Expression;
#     blocks: [ ComprehensionBlock | ComprehensionIf ];
#     filter: Expression | null;
# }
# An array comprehension. The blocks array corresponds to the sequence of for 
#   and for each blocks. The optional filter expression corresponds to the 
#   final if clause, if present.
# 
# Note: Array comprehensions are SpiderMonkey-specific.
#
# interface GeneratorExpression <: Expression {
#     type: "GeneratorExpression";
#     body: Expression;
#     blocks: [ ComprehensionBlock | ComprehensionIf ];
#     filter: Expression | null;
# }
# A generator expression. As with array comprehensions, the blocks array 
#   corresponds to the sequence of for and for each blocks, and the optional 
#   filter expression corresponds to the final if clause, if present.
# 
# Note: Generator expressions are SpiderMonkey-specific.
#
# interface GraphExpression <: Expression {
#     type: "GraphExpression";
#     index: uint32;
#     expression: Literal;
# }
# A graph expression, aka "sharp literal," such as #1={ self: #1# }.
# 
# Note: Graph expressions are SpiderMonkey-specific.
#
# interface GraphIndexExpression <: Expression {
#     type: "GraphIndexExpression";
#     index: uint32;
# }
# A graph index expression, aka "sharp variable," such as #1#.
# 
# Note: Graph index expressions are SpiderMonkey-specific.
#
# interface LetExpression <: Expression {
#     type: "LetExpression";
#     head: [ VariableDeclarator ];
#     body: Expression;
# }
# A let expression.
# 
# Note: The let expression form is SpiderMonkey-specific.
#
# -----------------------------------------------------------------------------
# Patterns
# -----------------------------------------------------------------------------
# 
# interface Pattern <: Node { }
# JavaScript 1.7 introduced destructuring assignment and binding forms. 
#  All binding forms (such as function parameters, variable declarations, and 
#  catch block headers) accept array and object destructuring patterns in 
#  addition to plain identifiers. The left-hand sides of assignment expressions 
#  can be arbitrary expressions, but in the case where the expression is an 
#  object or array literal, it is interpreted by SpiderMonkey as a 
#  destructuring pattern.
# 
# Since the left-hand side of an assignment can in general be any expression, 
#   in an assignment context, a pattern can be any expression. In binding 
#   positions (such as function parameters, variable declarations, and catch 
#   headers), patterns can only be identifiers in the base case, not arbitrary 
#   expressions.
# 
# interface ObjectPattern <: Pattern {
#     type: "ObjectPattern";
#     properties: [ { key: Literal | Identifier, value: Pattern } ];
# }
# An object-destructuring pattern. A literal property in an object pattern can 
#   have either a string or number as its value.
# 
# interface ArrayPattern <: Pattern {
#     type: "ArrayPattern";
#     elements: [ Pattern | null ];
# }
# An array-destructuring pattern.
# 
# -----------------------------------------------------------------------------
# Clauses
# -----------------------------------------------------------------------------
# 
# interface SwitchCase <: Node {
#     type: "SwitchCase";
#     test: Expression | null;
#     consequent: [ Statement ];
# }
# A case (if test is an Expression) or default (if test === null) clause in 
#   the body of a switch statement.
# 
# interface CatchClause <: Node {
#     type: "CatchClause";
#     param: Pattern;
#     guard: Expression | null;
#     body: BlockStatement;
# }
# A catch clause following a try block. The optional guard property corresponds 
#   to the optional expression guard on the bound variable.
# 
# Note: The guard expression is SpiderMonkey-specific.
#
# interface ComprehensionBlock <: Node {
#     type: "ComprehensionBlock";
#     left: Pattern;
#     right: Expression;
#     each: boolean;
# }
# A for or for each block in an array comprehension or generator expression.
# 
# interface ComprehensionIf <: Node {
#     type: "ComprehensionIf";
#     test: Expression;
# }
# An if filter in an array comprehension or generator filter.
# 
# Note: Array comprehensions and generator expressions are SpiderMonkey-specific.
#
# -----------------------------------------------------------------------------
# Miscellaneous
# -----------------------------------------------------------------------------
# 
# interface Identifier <: Node, Expression, Pattern {
#     type: "Identifier";
#     name: string;
# }
# An identifier. Note that an identifier may be an expression or a 
#   destructuring pattern.
# 
# interface Literal <: Node, Expression {
#     type: "Literal";
#     value: string | boolean | null | number | RegExp;
# }
# A literal token. Note that a literal can be an expression.

Node = 'Node'
Program = 'Program'
Function = 'Function'
Statement = 'Statement'
EmptyStatement = 'EmptyStatement'
BlockStatement = 'BlockStatement'
ExpressionStatement = 'ExpressionStatement'
IfStatement = 'IfStatement'
LabeledStatement = 'LabeledStatement'
BreakStatement = 'BreakStatement'
ContinueStatement = 'ContinueStatement'
WithStatement = 'WithStatement'
SwitchStatement = 'SwitchStatement'
ReturnStatement = 'ReturnStatement'
ThrowStatement = 'ThrowStatement'
TryStatement = 'TryStatement'
WhileStatement = 'WhileStatement'
DoWhileStatement = 'DoWhileStatement'
ForStatement = 'ForStatement'
ForInStatement = 'ForInStatement'
ForOfStatement = 'ForOfStatement'
LetStatement = 'LetStatement'
DebuggerStatement = 'DebuggerStatement'
Declaration = 'Declaration'
FunctionDeclaration = 'FunctionDeclaration'
VariableDeclaration = 'VariableDeclaration'
VariableDeclarator = 'VariableDeclarator'
Expression = 'Expression'
ThisExpression = 'ThisExpression'
ArrayExpression = 'ArrayExpression'
ObjectExpression = 'ObjectExpression'
Property = 'Property'
FunctionExpression = 'FunctionExpression'
ArrowExpression = 'ArrowExpression'
SequenceExpression = 'SequenceExpression'
UnaryExpression = 'UnaryExpression'
BinaryExpression = 'BinaryExpression'
AssignmentExpression = 'AssignmentExpression'
UpdateExpression = 'UpdateExpression'
LogicalExpression = 'LogicalExpression'
ConditionalExpression = 'ConditionalExpression'
NewExpression = 'NewExpression'
CallExpression = 'CallExpression'
MemberExpression = 'MemberExpression'
YieldExpression = 'YieldExpression'
ComprehensionExpression = 'ComprehensionExpression'
GeneratorExpression = 'GeneratorExpression'
GraphExpression = 'GraphExpression'
GraphIndexExpression = 'GraphIndexExpression'
LetExpression = 'LetExpression'
Pattern = 'Pattern'
ObjectPattern = 'ObjectPattern'
ArrayPattern = 'ArrayPattern'
SwitchCase = 'SwitchCase'
CatchClause = 'CatchClause'
ComprehensionBlock = 'ComprehensionBlock'
ComprehensionIf = 'ComprehensionIf'
Identifier = 'Identifier'
Literal = 'Literal'

###

Laundry list
============================

Unary infix ops
---------------
ASTNot

Binary infix ops
---------------
ASTPlus
ASTSub
ASTMul
ASTMMult
ASTDiv
TODO ASTIntDiv
ASTPow
ASTPow2
ASTMod
ASTAND
ASTOR
ASTLT
ASTLE
ASTGT
ASTGE
ASTEQ
ASTNE
ASTLA
ASTLO

Unary prefix ops
---------------
ASTIsNA 
ASTNrow (nrow frame)
ASTNcol (ncol frame)
TODO ASTLength (length frame)
ASTAbs
ASTSgn
ASTSqrt
ASTCeil
ASTFlr
ASTLog
ASTLog10
ASTLog2
ASTLog1p
ASTExp
ASTExpm1
ASTGamma
ASTLGamma
ASTDiGamma
ASTTriGamma
TODO ASTScale # scale(x, center = TRUE, scale = TRUE)
ASTCharacter
ASTFactor (as.factor vector)
ASTAsNumeric
ASTIsFactor (is.factor vector)
ASTAnyFactor// For Runit testing
ASTCanBeCoercedToLogical
ASTAnyNA (any.na frame)
ASTRound
ASTSignif
ASTTrun

ASTTranspose

Trigonometric functions
---------------
ASTCos
ASTSin
ASTTan
ASTACos
ASTASin
ASTATan
ASTCosh
ASTSinh
ASTTanh
ASTACosh
ASTASinh
ASTATanh
ASTCosPi
ASTSinPi
ASTTanPi

More generic reducers
---------------
ASTMin
ASTMax
ASTSum
ASTSdev
ASTVar
ASTMean
ASTMedian

Misc
---------------
TODO ASTSetLevel
TODO ASTMatch match(x, y): search for elements of x in y. returns 1-based indices.
TODO ASTRename
ASTSeq
ASTSeqLen
ASTRepLen
TODO ASTQtile
ASTCbind
ASTRbind
TODO ASTTable
ASTIfElse
ASTApply
TODO ASTSApply
TODO ASTddply
TODO ASTMerge
TODO ASTGroupBy
TODO ASTXorSum
ASTRunif
TODO ASTCut
TODO ASTLs
ASTSetColNames

Date
---------------
ASTasDate

ASTCat

Time extractions, to and from msec since the Unix Epoch
---------------
ASTYear
ASTMonth
ASTDay
ASTDayOfWeek
ASTHour
ASTMinute
ASTSecond
ASTMillis
ASTMktime

TODO ASTFoldCombine
TODO COp
TODO ROp
TODO O
###


#TODO need type attributes scalar -> scalar; vector -> scalar; etc.
Funcs =

  # Javascript Math.* scalar
  abs:
    name: 'abs'
  acos:
    name: 'acos'
  asin:
    name: 'asin'
  atan:
    name: 'atan'
# atan2:
#   name: ''
  ceil:
    name: 'ceiling'
  cos:
    name: 'cos'
  exp:
    name: 'exp'
  floor:
    name: 'floor'
  log:
    name: 'log'
  log2 :
    name: 'log2'
  pow:
    name: '^'
  random:
    apply: (sexpr, context, args) ->
      name = 'h2o.runif'
      switch args.length
        when 1
          sexpr_call name, (sexpr args[0]), sexpr_number -1
        when 2
          sexpr_apply name, args.map sexpr
        else
          throw new Error "random: Invalid number of arguments, expected 2 , found #{args.length}"
  round:
    name: 'round' # round(num, digits)
  sin:
    name: 'sin'
  sqrt:
    name: 'sqrt'
  tan:
    name: 'tan'

  # Javascript Math.* scalar (Experimental / ES6 Harmony)
  acosh :
    name: 'acosh'
  asinh :
    name: 'asinh'
  atanh :
    name: 'atanh'
# cbrt :
#   name: ''
# clz32 :
#   name: ''
  cosh :
    name: 'cosh'
  expm1 :
    name: 'expm1'
# fround :
#   name: ''
# hypot :
#   name: ''
# imul :
#   name: ''
  log10 :
    name: 'log10'
  log1p :
    name: 'log1p'
  sign :
    name: 'sign' # Returns the signum function of the argument; zero if the argument is zero, 1.0 if the argument is greater than zero, -1.0 if the argument is less than zero.
  sinh :
    name: 'sinh'
  tanh :
    name: 'tanh'
  trunc :
    name: 'trunc'

  # Other Math
  signif:
    name: 'signif' # signif(num, digits)
  gamma:
    name: 'gamma'
  logGamma:
    name: 'lgamma'
  digamma:
    name: 'digamma'
  trigamma:
    name: 'trigamma'

  # Computations / Descriptive Statistics
  max:
    name: 'max'
  min:
    name: 'min'
  sum:
    name: 'sum'
  std:
    name: 'sd'
  mean:
    name: 'mean'
  median:
    name: 'median'
  variance:
    name: 'var'

  # Date functions
  year:
    name: 'year'
  day:
    name: 'day'
  hours:
    name: 'hour'
  minutes:
    name: 'minute'
  seconds:
    name: 'second'
  milliseconds:
    name: 'millis'
  month:
    name: 'month'
  weekday:
    name: 'dayOfWeek'
  date:
    name: 'mktime'

  isNaN:
    name: 'is.na' # H2O does not differentiate between NA and NaN

  toFactor:
    name: 'as.factor'
  toNumber:
    name: 'as.numeric'
  toString:
    name: 'as.character'
  toDate:
    name: 'toDate'

  multiply: 
    name: 'x'
  transpose:
    name: 't'

  length:
    name: 'nrow'
  width:
    name: 'ncol'
  combine:
    name: 'cbind'
  append:
    name: 'rbind'
  vector:
    name: 'c'
  at:
    name: 'llist' # long arrays
  to:
    name: ':'
  replicate:
    name: 'rep_len'
  labels:
    name: 'slist' # string arrays

  select:
    apply: (sexpr, context, args) ->
      switch args.length
        when 2
          sexpr_call '[', (sexpr args[0]), (sexpr null), (sexpr args[1])
        else
          throw new Error "select: Invalid number of arguments, expected 2 , found #{args.length}"

  filter:
    apply: (sexpr, context, args) ->
      switch args.length
        when 2
          sexpr_call '[', (sexpr args[0]), (sexpr args[1]), (sexpr null)
        else
          throw new Error "filter: Invalid number of arguments, expected 2 , found #{args.length}"

  slice:
    apply: (sexpr, context, args) ->
      switch args.length
        when 3
          sexpr_apply '[', args.map sexpr
        else
          throw new Error "slice: Invalid number of arguments, expected 3 , found #{args.length}"

  sequence:
    apply: (sexpr, context, args) ->
      switch args.length
        when 1
          sexpr_call 'seq_len', sexpr args[0]
        when 2
          sexpr_call 'seq', (sexpr args[0]), (sexpr args[1]), (sexpr_number 1)
        when 3
          sexpr_apply 'seq', args.map sexpr
        else
          throw new Error "sequence: Invalid number of arguments, expected 1 - 3, found #{args.length}"

  map:
    apply: (sexpr, context, args) ->
      throw new Error "map: Expected 2 args, found #{args.length}" if args.length isnt 2
      [ object, func ] = args
      throw new Error "map: Expected arg #2 to be #{FunctionExpression}" if func.type isnt FunctionExpression
      throw new Error "map: Expected #{FunctionExpression} to have 1 parameter" if func.params.length isnt 1

      sexpr_call 'apply', (sexpr object), (sexpr_number 1), sexpr_lookup collectFunc sexpr, context, func

  collect:
    apply: (sexpr, context, args) ->
      throw new Error "collect: Expected 2 args, found #{args.length}" if args.length isnt 2
      [ object, func ] = args
      throw new Error "collect: Expected arg #2 to be #{FunctionExpression}" if func.type isnt FunctionExpression
      throw new Error "collect: Expected #{FunctionExpression} to have 1 parameter" if func.params.length isnt 1

      sexpr_call 'apply', (sexpr object), (sexpr_number 2), sexpr_lookup collectFunc sexpr, context, func

do ->
  for funcName, func of Funcs
    func.isFunction = yes
    func.isGlobal = yes
  return

Asts =
  Identifier: (name) ->
    name: name

  MemberExpression: (computed, object, property) ->
    computed: computed
    object: object
    property: property

  BinaryExpression: (operator, left, right) ->
    operator: operator
    left: left
    right: right

  Literal: (value, raw) ->
    value: value
    raw: raw

  CallExpression: (name, args) ->
    callee:
      type: Identifier
      name: name
    "arguments": args

Ast = _.mapValues Asts, (build, type) ->
  (args...) ->
    ast = build.apply null, args
    ast.type = type
    ast

Call = (name) ->
  (args...) ->
    Ast.CallExpression name, args

Func = _.mapValues Funcs, (func, localName) ->
  Call localName 

sexpr_apply = (func, args) ->
  "(#{func} #{args.join ' '})"

sexpr_call = (func, args...) ->
  sexpr_apply func, args

sexpr_string = (value) ->
  JSON.stringify value

sexpr_number = (value) ->
  "##{value}"

sexpr_boolean = (value) ->
  if value then "%TRUE" else "%FALSE"

sexpr_null = ->
  '"null"'

sexpr_nan = ->
  '#NaN'

sexpr_lookup = (identifier) ->
  "%#{identifier}"

sexpr_strings = (strings) ->
  args = for string in strings
    if string? then sexpr_string string else sexpr_null()
  sexpr_apply 'slist', args

sexpr_doubles = (numbers) ->
  args = for number in numbers
    if number? then sexpr_number number else sexpr_nan()
  sexpr_apply 'dlist', args

sexpr_span = (begin, end) ->
  sexpr_call ':', begin, end

sexpr_def = (name, params, body) ->
  sexpr_call 'def', (sexpr_string name), (sexpr_strings params), body

SExpr = (context) ->
  Nodes =
    Node: null
    Program: null
    Function: null
    Statement: null
    EmptyStatement: null
    BlockStatement: null
    IfStatement: null
    LabeledStatement: null
    BreakStatement: null
    ContinueStatement: null
    WithStatement: null
    SwitchStatement: null
    ReturnStatement: null
    ThrowStatement: null
    TryStatement: null
    WhileStatement: null
    DoWhileStatement: null
    ForStatement: null
    ForInStatement: null
    ForOfStatement: null
    LetStatement: null
    DebuggerStatement: null
    Declaration: null
    FunctionDeclaration: null
    VariableDeclaration: null
    VariableDeclarator: null
    Expression: null
    ThisExpression: null
    ArrayExpression: null
    ObjectExpression: null
    Property: null
    FunctionExpression: null
    ArrowExpression: null
    ExpressionStatement: null
    SequenceExpression: null

    UnaryExpression: (node) ->
      { operator, argument, prefix } = node
      if prefix
        switch operator
          when '!'
            sexpr_call 'not', sexpr argument
          when '+'
            # http://www.ecma-international.org/ecma-262/5.1/#sec-11.4.6
            # The unary + operator converts its operand to Number type.
            sexpr Func.toNumber argument
          when '-'
            if argument.type is Literal and _.isFinite argument.value
              sexpr_number -argument.value
            else
              sexpr Ast.BinaryExpression '*', argument, Ast.Literal -1, '-1'
          else
            # '~', 'typeof', 'void', 'delete'
            throw new Error "Unsupported #{node.type} prefix operator [#{operator}]"
      else
        # Forth?
        throw new Error "Unsupported #{node.type} postfix operator [#{operator}]"

    BinaryExpression: (node) ->
      { operator, left, right } = node
      op = switch operator
        when '==', '==='
          'n'
        when '!=', '!=='
          'N'
        when '<'
          'l'
        when '<='
          'L'
        when '>'
          'g'
        when '>='
          'G'
        when '+', '-', '*', '/'
          operator
        when '%'
          'mod'
        else
          # '<<', '>>', '>>>', '|', '^', '&', 'in', 'instanceof', '..'
          throw new Error "Unsupported #{node.type} operator [#{operator}]"

      sexpr_call op, (sexpr left), (sexpr right)

    AssignmentExpression: null

    UpdateExpression: null

    LogicalExpression: (node) ->
      { operator, left, right } = node
      op = switch operator
        when '||'
          '|'
        when '&&'
          '&'
        else
          throw new Error "Unsupported #{node.type} operator [#{operator}]"

      sexpr_call op, (sexpr left), (sexpr right)

    ConditionalExpression: (node) ->
     { test, consequent, alternate } = node
     sexpr_call 'ifelse', (sexpr test), (sexpr consequent), (sexpr alternate)

    NewExpression: null

    CallExpression: (node) ->
      { callee } = node
      if callee.type is Identifier
        func = context.lookup callee.name
        if func?.isFunction
          if func.isGlobal
            if func.apply
              func.apply sexpr, context, node.arguments
            else
              # Built-in function
              sexpr_apply func.name, (sexpr arg for arg in node.arguments)
          else
            # UDF
            sexpr_apply (sexpr_lookup func.name), (sexpr arg for arg in node.arguments)
        else
          throw new Error "Not a function: [#{callee.name}]"
      else
        throw new Error "#{CallExpression}: expected #{Identifier}, found #{callee.type}.]"

    MemberExpression: (node) ->
      { computed, object, property } = node
      if computed
        # expression
        if property.type is Literal
          if _.isFinite property.value
            if property.value % 1 is 0
              # slice column by index 
              sexpr_call '[', (sexpr object), sexpr_null(), (sexpr_number property.value)
            else
              throw new Error "Property accessor is not an integer: [#{property.value}]."
          else
            sexpr_call '[', (sexpr object), sexpr_null(), (sexpr_strings [property.value])
        else
          sexpr_call '[', (sexpr object), sexpr_null(), (sexpr property)
      else
        sexpr_call '[', (sexpr object), sexpr_null(), (sexpr_strings [property.name])

    YieldExpression: null
    ComprehensionExpression: null
    GeneratorExpression: null
    GraphExpression: null
    GraphIndexExpression: null
    LetExpression: null
    Pattern: null
    ObjectPattern: null
    ArrayPattern: null
    SwitchCase: null
    CatchClause: null
    ComprehensionBlock: null
    ComprehensionIf: null

    Identifier: (node) ->
      if node.name is 'NaN'
        sexpr_nan()
      else if symbol = context.lookup node.name
        sexpr_lookup symbol.name
      else
        throw new Error "Unknown #{node.type}: [#{node.name}]"

    Literal: (node) ->
      { value, raw } = node
      if value is null
        sexpr value

      else if _.isFinite value
        sexpr_number raw

      else if _.isString value
        sexpr_string value

      else if _.isBoolean value
        sexpr_boolean value

      else # RegExp
        throw new Error "Unsupported literal [#{raw}]"

  sexpr = (node) ->
    if node
      if handler = Nodes[node.type]
        handler node
      else
        dump node
        throw new Error "Unsupported operation: [#{node.type}]"
    else
      sexpr_null()

Context = (funcs, symbols, params) ->
  _funcs = []

  _table = {}
  for funcName, func of funcs
    _table[funcName] = func
  for param, paramIndex in params
    _table[param.name] = name: symbols[paramIndex]

  _tables = [_table]

  push = (table) ->
    _tables.unshift table

  pop = ->
    _tables.shift()

  lookup = (name) ->
    for table in _tables when symbol = table[name]
      return symbol
    return

  collect = (name, expr) ->
    _funcs.push name: name, expr: expr

  lookup: lookup
  push: push
  pop: pop
  collect: collect
  funcs: -> _funcs

asSymbolTable = (names) ->
  table = {}
  for name in names
    table[name] = name: name
  table

collectFunc = (sexpr, context, func) ->
  paramNames = func.params.map (param) -> param.name
  context.push asSymbolTable paramNames
  funcName = 'anon' + uuid()
  funcExpr = sexpr_def funcName, paramNames, sexpr getFunctionExpression func
  context.pop()

  context.collect funcName, funcExpr

  funcName


getFunctionExpression = (node) ->
  block = node.body
  if block.body.length > 1
    throw new Error 'Multiple statements are not supported in function bodies'
  statement = block.body[0]
  if statement.type isnt ReturnStatement
    throw new Error "No #{ReturnStatement} found in function body"

  statement.argument

transpile = (symbols, lambda) ->

  unless _.isFunction lambda
    throw new Error "Not a function: [#{lambda}]"

  source = lambda.toString()

  program = esprima.parse "var _O_o_ = #{source}"
  func = program.body[0].declarations[0].init  

  params = func.params
  if params.length isnt symbols.length
    throw new Error "Invalid function arity: expected [#{expectedArity}], found [#{params.length}] at #{source}"

  expression = getFunctionExpression func

  sexpr = SExpr context = Context Funcs, symbols, params
  try
    ast = sexpr expression
    [ ast, context.funcs() ]

  catch error
    #console.log dump expression
    throw error

toVector = (array) ->
  throw new Error 'Not an array.' unless _.isArray array

  hasNumber = no
  hasString = no
  message = 'Cannot import heterogeneous arrays.'

  vector = for element, i in array
    if _.isFinite element
      hasNumber = yes
      if hasString
        throw new Error message
      else
        element
    else if _.isString element
      hasString = yes
      if hasNumber
        throw new Error message
      else
        element
    else
      if element?
        throw new Error message
      else
        null

  if hasNumber
    sexpr_call 'c', sexpr_doubles vector
  else # String
    sexpr_call 'c', sexpr_strings vector

#
# Notes
# =====
# 

# Create a new temp frame with an extra computed vec attached:
# (cbind %source_frame (colnames= (+ "vec_key_1" "vec_key_2") #0 "new_col_name"))
# (cbind %foo (colnames= (+ "$04ff68000000ffffffff230e88cc0d8454ae5e4c352f8b$g0X" "$04ff69000000ffffffff230e88cc0d8454ae5e4c352f8b$g0X") #0 "gamma"))
#
# Same as above, but save as new frame to global ns:
# (= !target_frame (cbind %source_frame ...))
#
# Same as above, but mutate existing frame:
# (= ([ %source_frame "null" #6) (colnames= (+ ... )))
#
#
# Create a new temp frame with n vecs
# (cbind %target_frame "k1" "k2" ...)

module.exports =
  transpile: transpile
  toVector: toVector
