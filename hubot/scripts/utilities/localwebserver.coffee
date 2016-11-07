# Description:
#   Local eb server to host static file
#
# Dependencies:
#
#
# Configuration:
#   LOCAL_WEB_SERVER_PATH
#   LOCAL_WEB_SERVER_URL
#

crypto  = require 'crypto'
fs = require 'fs'
path = require 'path'

web_server_path = process.env.LOCAL_WEB_SERVER_PATH
web_server_url = process.env.LOCAL_WEB_SERVER_URL

isAvailable = =>
  return web_server_path? and web_server_url?

uploadPath = (content_type)=>
  name = crypto.randomBytes(20).toString('hex')

  ext = ''
  if content_type?
    switch content_type.toLowerCase()
      when "image/gif" then ext = '.gif'
      when 'image/jpeg' then ext = '.jpeg'
      when 'image/pdf' then ext = '.pdf'
      when 'image/png' then ext = '.png'
      else ext = ''

  return path.join web_server_path, "#{name}#{ext}"

resourceUrl = (filename) =>
  if filename.indexOf(web_server_path) == 0
    filename = filename.substring(web_server_path.length)
  if filename.indexOf('/') == 0
    filename = filename.substring(1)
  return "#{web_server_url}/#{filename}"

uploadToServer = (filename, content, cb) =>
  fs.writeFile filename, content, cb

exports.isAvailable = isAvailable
exports.uploadPath = uploadPath
exports.resourceUrl = resourceUrl
exports.uploadToServer = uploadToServer
