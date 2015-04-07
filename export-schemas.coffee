fs = require 'fs'
path = require 'path'
h2o = (require './h2o.js').connect()

h2o.getSchemas (error, schemas) ->
  if error
    throw error 
  else
    fs.writeFileSync(
      path.join __dirname, 'doc', 'schemas.json'
      JSON.stringify { schemas: schemas }, null, 2
    )

