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
esprima = require 'esprima'

dump = (a) -> console.log JSON.stringify a, null, 2

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

Funcs =
  toDate: 'as.Date'
  toString: 'as.character'
  toNumber: 'as.numeric'

Ast = (type, args...) ->

AssignmentExpression = (operator, left, right) ->
  type: 'AssignmentExpression'
  operator: operator
  left: left
  right: right

BinaryExpression = (operator, left, right) ->
  type: 'BinaryExpression'
  operator: operator
  left: left
  right: right

Literal = (value, raw) ->
  type: 'Literal'
  value: value
  raw: raw

SequenceExpression = (expressions) ->
  type: 'SequenceExpression'
  expressions: expressions

CallExpression = (name, args) ->
  type: 'CallExpression'
  callee:
    type: 'Identifier'
    name: name
  "arguments": args

Call = (name) ->
  (args...) ->
    CallExpression name, args

Func = _.forIn Funcs, (remoteName, localName) ->
  Call localName

SExpr = (context) ->
  Nodes =
    Node: null
    Program: null
    Function: null
    Statement: null
    EmptyStatement: null
    BlockStatement: (node) ->
      if node.body.length is 1
        sexprt node.body[0]
      else
        "(, #{ sexprs (sexpr statement for statement in node.body) })"

    ExpressionStatement: (node) ->
      sexpr node.expression

    IfStatement: null
    LabeledStatement: null
    BreakStatement: null
    ContinueStatement: null
    WithStatement: null
    SwitchStatement: null

    ReturnStatement: (node) ->
      "(return #{sexpr node.argument})"

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

    VariableDeclaration: (node) ->
      switch node.kind
        when 'var'
          sexprs (sexpr declarator for declarator in node.declarations)
        else # 'let', 'const'
          throw new Error "Unsupported #{node.kind} #{node.type}"

    VariableDeclarator: (node) ->
      "(= #{sexpr node.id} #{sexpr node.init})"

    Expression: null
    ThisExpression: null
    ArrayExpression: null
    ObjectExpression: null
    Property: null
    FunctionExpression: null
    ArrowExpression: null

    SequenceExpression: (node) ->
      "(, #{ sexprs (sexpr expression for expression in node.expressions) })"

    UnaryExpression: (node) ->
      { operator, argument, prefix } = node
      if prefix
        switch operator
          when '!'
            "(not #{sexpr argument})"
          when '+'
            # http://www.ecma-international.org/ecma-262/5.1/#sec-11.4.6
            # The unary + operator converts its operand to Number type.
            sexpr Func.toNumber argument
          when '-'
            sexpr BinaryExpression '*', argument, Literal -1, '-1'
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

      "(#{op} #{sexpr left} #{sexpr right})"

    AssignmentExpression: (node) ->
      { operator, left, right } = node
      switch operator
        when '='
          "(= #{sexpr left} #{sexpr right})"
        else
          # '+=', '-=', '*=', '/=', '%=', '<<=', '>>=', '>>>=', '|=', '^=', '&='
          op = operator.substr 0, operator.length - 1
          sexpr BinaryExpression op, left, right

    UpdateExpression: (node) ->
      { operator, argument, prefix } = node
      op = operator.substr 0, operator.length - 1
      incrOrDecrExpression = AssignmentExpression '=', argument, BinaryExpression op, argument, Literal 1, '1'

      if prefix
        # ++a --> a = a + 1
        sexpr incrOrDecrExpression

      else
        # a++ --> (a = a + 1, a - 1)
        sexpr SequenceExpression [
          incrOrDecrExpression
          BinaryExpression '-', argument, Literal 1, '1'
        ]

    LogicalExpression: (node) ->
      { operator, left, right } = node
      op = switch operator
        when '||'
          '|'
        when '&&'
          '&'
        else
          throw new Error "Unsupported #{node.type} operator [#{operator}]"

      "(#{op} #{sexpr left} #{sexpr right})"

    ConditionalExpression: null
    NewExpression: null
    CallExpression: null
    MemberExpression: null
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
      if symbol = context.symbols[node.name]
        # Replace with lookup
        "%#{symbol}"
      else
        node.name

    Literal: (node) ->
      { value, raw } = node
      if value is null
        sexpr value

      else if _.isNumber value
        "##{raw}"

      else if _.isString value
        '"' + raw + '"'

      else if _.isBoolean value
        if value
          "%TRUE"
        else
          "%FALSE"

      else # RegExp
        throw new Error "Unsupported literal [#{raw}]"

    Null: (node) ->
      '#NaN'

  sexprs = (sexprs) -> sexprs.join ' '

  sexprt = (node) ->
    sexpr if node.type is 'ReturnStatement' then node.argument else node

  sexpr = (node) ->
    if handler = (if node then Nodes[node.type] else Nodes.Null)
      handler node
    else
      dumpNode node
      throw new Error "Unsupported operation: [#{node.type}]"

walk = (ast, f) -> 
  f ast

  for key, node of ast when node isnt undefined and node isnt null
    if node instanceof Array
      for child in node
        walk child, f

    else if 'string' is typeof node.type
      walk node, f

  return


dumpNode = (node) ->
  console.log '----------------------------------'
  for k, v of node when not _.isFunction v
    console.log "#{k}: #{v}"
  console.log '----------------------------------'
  return

map = (symbols, func) ->
  if _.isFunction func
    source = func.toString()
    ast = esprima.parse "var _O_o_ = #{source}"
    astFunc = ast.body[0].declarations[0].init  

    if astFunc.params.length isnt symbols.length
      throw new Error "Invalid number of formal parameters in map function: expected [#{symbols.length}], found [#{astFunc.params.length}] at #{source}"

    symbolTable = {}
    for param, paramIndex in astFunc.params
      symbolTable[param.name] = symbols[paramIndex]

    sexpr = SExpr
      symbols: symbolTable

    try
      sexpr astFunc.body

    catch error
      console.log dump astFunc.body 
      throw error

  else
    undefined


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
  map: map
