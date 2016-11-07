# Description:
#   Interact with your ElectricFlow server
#
# Dependencies:
#   "request": "~2"
#
# Configuration:
#   FLOW_BASE
#   FLOW_USER
#   FLOW_PASSWORD
#

request = require 'request'

flow_base_url = process.env.FLOW_BASE
flow_user = process.env.FLOW_USER
flow_password = process.env.FLOW_PASSWORD

listProjects = (cb) =>
  path = "/projects"
  httpGet path, (err, result) =>
    return cb err if err?
    cb null, result.project

listEnvironments = (cb) =>
  path = "/projects/default/environments"
  httpGet path, (err, result) =>
    return cb err if err?
    cb null, result.environment

listProcedures = (project, cb) =>
  path = "/projects/#{project.projectName}/procedures"
  httpGet path, (err, result) =>
    return cb err if err?
    cb null, result.procedure

runProcedure = (project, procedure, parameters, cb) =>
  path = "/jobs?request=runProcedure&projectName=#{project}&procedureName=#{procedure}"

  data = {}
  if parameters?
    actualParameter = []
    for key, value of parameters
      actualParameter.push({actualParameterName: key, value: value})
    data =
      parameters:
        actualParameter: actualParameter

  httpPost path, data, (err, result) =>
    return cb err if err?
    cb null, result

getJob = (jobId, cb) =>
  path = "/jobs/#{jobId}"
  httpGet path, (err, result) =>
    return cb err if err?
    cb null, result.job

deleteEnv = (environment, cb) =>
  path = "/projects/default/environments/#{environment}"
  httpDelete path, (err, result) =>
    return cb err if err?
    cb null, result

httpGet = (path, cb) =>
  url = "#{flow_base_url}#{path}"
  options =
    method: 'GET'
    url: url
    rejectUnauthorized: false
    auth:
      user: flow_user
      password: flow_password
    json: true

  httpRequest options, cb
  
httpDelete = (path, cb) =>
  url = "#{flow_base_url}#{path}"
  options =
    method: 'DELETE'
    url: url
    rejectUnauthorized: false
    auth:
      user: flow_user
      password: flow_password
    json: true

  httpRequest options, cb

httpPost = (path, data, cb) =>
  url = "#{flow_base_url}#{path}"
  options =
    method: 'POST'
    url: url
    rejectUnauthorized: false
    auth:
      user: flow_user
      password: flow_password
    json: true
    body: data

  httpRequest options, cb

httpRequest = (options, cb) =>
  request options, (err, res, body) ->
    if err?
      return cb err
    if 200 != res.statusCode
      err = new Error res.statusCode
      err.body = body
      return cb err
    if body.responses? and body.responses[0]?.error?.message?
      err = new Error body.responses[0].error.message
      err.body = body
      return cb err

    cb null, body

exports.listProjects = listProjects
exports.listProcedures = listProcedures
exports.runProcedure = runProcedure
exports.getJob = getJob
exports.listEnvironments = listEnvironments
exports.deleteEnv = deleteEnv
