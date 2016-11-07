#  Description:
#   This script holds various flowdock utility functions
#
#   uploadToFlowdock - upload files to flowdock
#
#   listFiles - list the last N files uploaded to a flowdock room. Defaults to last 5 files
#
#   downloadFile - download file from flowdock
#
# Dependencies:
#   "request": "~2"
#
# Configuration:
#   HUBOT_FLOWDOCK_API_TOKEN
#   FLOWDOCK_ORG_NAME
#

## modules
request = require 'request'
fs = require 'fs'
debug = require('debug')('flowdockUtils')

## config
hubot_api_token = process.env.HUBOT_FLOWDOCK_API_TOKEN
flow_org = process.env.FLOWDOCK_ORG_NAME
flowUtils_local_path = process.env.FLOWUTILS_SERVER_PATH
flowdock_base_url = "https://#{hubot_api_token}@api.flowdock.com"

logger =
    info: (msg,robot) ->
      return debug msg if debug.enabled
      msg = JSON.stringify msg if typeof msg isnt 'string'
      robot.logger.info "#{debug.namespace}: #{msg}"
    error: (msg,robot,err) ->
      return debug msg if debug.enabled
      msg = JSON.stringify msg if typeof msg isnt 'string'
      robot.logger.error "#{debug.namespace}: #{msg}", err

uploadToFlowdock = (robot, file, flowRoom, cb) ->
  logger.info "file is #{file} flow room is #{flowRoom}", robot
  
  url = "#{flowdock_base_url}/messages"
  options =
    method: 'POST'
    url: url
    formData:
      flow: flowRoom
      event: "file"
      content: fs.createReadStream(file)

  logger.info "url is #{url}", robot
  httpRequest options, cb

listFiles = (robot, flow, num, cb) ->
  logger.info "flow is #{flow}, num is #{num}", robot

  getFlowName robot, flow, (err, flowName, paramFlowName) ->
    if err?
      logger.error "Failed getting flow name", robot, err
      return msg.send "Error contacting flowdock: #{err.message}"
    
    url = "#{flowdock_base_url}/flows/#{flow_org}/#{paramFlowName}/messages"
    options =
      method: 'GET'
      url: url
      formData:
        event: 'file'
        limit: num

    logger.info "url is #{url}", robot

    httpRequest options, (err, res, body) ->
      return cb err if err?

      logger.info "body is " + JSON.stringify(body), robot

      files = null
      try
        files = JSON.parse(body)
      catch error
        logger.error "failed parsing files json", robot, error
        return msg.send "error parsing files json: #{error.message}"
      if files?
        cb null, files

getFlowName = (robot, flowId, cb) ->
  logger.info "enter getFlowName", robot
  logger.info "flowId is #{flowId}", robot

  url = "#{flowdock_base_url}/flows/find"
  options =
    method: 'GET'
    url: url
    formData:
      id: flowId

  logger.info "url is #{url}", robot

  httpRequest options, (err, res, body) ->
    return cb err if err?

    flow = null
    try
      flow = JSON.parse(body)
    catch error
      logger.error "failed parsing flow json", robot, error
      return msg.send "error parsing json: #{error.message}"
    if flow?
      cb null, flow.name, flow.parameterized_name

downloadFile = (robot, serverPath, fileName, cb) ->
  logger.info "enter downloadfile", robot
  logger.info "serverPath is #{serverPath}\nfileName is #{fileName}", robot

  url = "#{flowdock_base_url}#{serverPath}"

  options =
    method: 'GET'
    url: url
    encoding: null

  logger.info "url is #{url}", robot

  httpRequest options, (err, res, body) ->
    return cb err if err?

    logger.info "Saving file as #{fileName}: #{body.length} bytes, content-type[#{res.headers['content-type']}]", robot
    fs.writeFile "#{flowUtils_local_path}/#{fileName}", body, cb

httpRequest = (options, cb) ->
  request options, (err, res, body) ->
    if err?
      return cb err
    if res.statusCode != 200 and res.statusCode != 201
      err = new Error res.statusCode
      err.body = body
      return cb err

    cb null, res, body


exports.uploadToFlowdock = uploadToFlowdock
exports.listFiles = listFiles
exports.getFlowName = getFlowName
exports.downloadFile = downloadFile
