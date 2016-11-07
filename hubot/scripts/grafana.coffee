# Description:
#   Query Grafana dashboards, based on http://docs.grafana.org/tutorials/hubot_howto/
#
#   Examples:
#   - `hubot graf list` - List all dashboards and their panels
#   - `hubot graf list ec` - List all panels of dashboards which slug contains ec
#   - `hubot graf server` - Get all panels in the dashboard
#   - `hubot graf server:3` - Get only the third panel of a particular dashboard
#   - `hubot graf server:load` - Get only the panels containing "load" (case insensitive) in the title
#   - `hubot graf server last 12h` - Get a dashboard with a window of 12 hours ago to now
#   - `hubot graf server from 2015-9-5 to 2015-9-6` - Get a dashboard with a window of 2015-9-5 00:00 to 2015-9-6 00:00
#   - `hubot graf server:3 from 2015-9-5 8:00 to 2015-9-6 16:00` - Get only the third panel of a particular dashboard with a window of 2015-9-5 00:00 to 2015-9-6 00:00
#
# Configuration:
#   HUBOT_GRAFANA_HOST - Host for your Grafana 2.0 install, e.g. 'http://play.grafana.org'
#   HUBOT_GRAFANA_API_KEY - API key for a particular user (leave unset if unauthenticated)
#   HUBOT_GRAFANA_API_USER - Optional; Username to access Grafana API
#   HUBOT_GRAFANA_API_PASSWORD - Optional; Password to access Grafana API
#   HUBOT_GRAFANA_LOCAL_SERVER_PATH - Optional; Path on the local server to copy the graph into
#   HUBOT_GRAFANA_LOCAL_SERVER_URL - Optional; URL prefix to access the graph from the local server
#
# Dependencies:
#   "request": "~2"
#   "async": "^1.4.2"
#   "./utilities/localwebserver"
#
# Commands:
#   hubot graf db <dashboard slug>[:<panel id>][ <template variables>][ last <last cluase> | from <from clause>] to <to clause>] - Show grafana dashboard graphs
#   hubot graf list <filter> - Lists grafana dashboards. If a filter is specified, only matched dashboards are listed.
#

request = require 'request'
async   = require 'async'

local_web_server = require './utilities/localwebserver'
uploadToFlowdock = require './utilities/flowdockUtils'

# Various configuration options stored in environment variables
grafana_host = process.env.HUBOT_GRAFANA_HOST
grafana_api_key = process.env.HUBOT_GRAFANA_API_KEY
grafana_api_user = process.env.HUBOT_GRAFANA_API_USER
grafana_api_password = process.env.HUBOT_GRAFANA_API_PASSWORD


# Get a specific dashboard with options
getDashboard = (robot, msg, slug, timespan, variables) ->
  # Parse out a specific panel
  pid = false
  pname = false
  if /\:/.test slug
    parts = slug.split(':')
    slug = parts[0]
    pid = parseInt parts[1], 10
    if isNaN pid
      pid = false
      pname = parts[1].toLowerCase()

  robot.logger.debug slug
  robot.logger.debug pid
  robot.logger.debug pname
  robot.logger.debug timespan
  robot.logger.debug variables

  # Call the API to get information about this dashboard
  callGrafana robot, msg, "dashboards/db/#{slug}", (dashboard) ->
    if dashboard.message
      robot.logger.info "Possible Grafana Error: #{dashboard.message}"
      return msg.send dashboard.message

    # Handle refactor done for version 2.0.2+
    if dashboard.dashboard
      # 2.0.2+: Changed in https://github.com/grafana/grafana/commit/e5c11691203fe68958e66693e429f6f5a3c77200
      data = dashboard.dashboard
      # The URL was changed in https://github.com/grafana/grafana/commit/35cc0a1cc0bca453ce789056f6fbd2fcb13f74cb
      apiEndpoint = 'dashboard-solo'
    else
      # 2.0.2 and older
      data = dashboard.model
      apiEndpoint = 'dashboard/solo'

    # Support for templated dashboards
    if data.templating.list
      template_map = []
      for template in data.templating.list
        template_map['$' + template.name] = template.current.text

    # Return dashboard rows
    panelFound = false
    panelNumber = 0
    for row in data.rows
      for panel in row.panels
        panelNumber += 1

        # Skip if panel ID was specified and didn't match
        if pid && pid != panelNumber
          continue

        # Skip if panel name was specified any didn't match
        if pname && panel.title.toLowerCase().indexOf(pname) is -1
          continue

        panelFound = true

        # Build links for message sending
        title = formatTitleWithTemplate(panel.title, template_map)
        imageUrl = "#{grafana_host}/render/#{apiEndpoint}/db/#{slug}/?panelId=#{panel.id}&width=1000&height=500&from=#{timespan.from}&to=#{timespan.to}#{variables}"
        link = "#{grafana_host}/dashboard/db/#{slug}/?panelId=#{panel.id}&fullscreen&from=#{timespan.from}&to=#{timespan.to}#{variables}"

        if local_web_server.isAvailable()
          fetchAndUpload robot, msg, title, imageUrl, link
        else
          sendRobotResponse msg, title, imageUrl, link

    if not panelFound
      robot.logger.info "The specified panel is not found, or the dashboard has not panel."
      msg.send "Panel not found"


# Get a list of available dashboards
listDashboards = (filter, robot, msg) ->
  callGrafana robot, msg, 'search', (dashboards) ->
    if dashboards?
      response = "Available dashboards:\n"

      # Handle refactor done for version 2.0.2+
      if dashboards.dashboards
        list = dashboards.dashboards
      else
        list = dashboards

      async.each(list, ((dashboard, cb) ->
        result = ""
        # Handle refactor done for version 2.0.2+
        if dashboard.uri
          slug = dashboard.uri.replace /^db\//, ''
        else
          slug = dashboard.slug

        if filter?
          if slug.toLowerCase().indexOf(filter.toLowerCase()) is -1
            return cb()

        result = result + "- #{slug}\n"

        callGrafana robot, msg, "dashboards/db/#{slug}", (dashboard) ->
          if dashboard?
            # Handle refactor done for version 2.0.2+
            if dashboard.dashboard
              rows = dashboard.dashboard.rows
            else
              rows = dashboard.model.rows

            for row in rows
              for panel  in row.panels
                title = panel.title
                result = result + "  - #{slug}:#{title}\n"

          response = response + "#{result}"
          return cb()
      ), ((err) ->
        # Remove trailing newline
        response.trim()
        msg.send response
      ))


# Display help texts
displayHelp = (robot, msg) ->
  robot_name = robot.alias or robot.name
  help_commands = robot.helpCommands().filter (command) ->
    command.match new RegExp('graf', 'i')
  help_commands = help_commands.map (command) ->
    command.replace /hubot/ig, robot_name
  help_commands = help_commands.sort()

  emit = help_commands.join "\n"

  msg.send emit


# Call off to Grafana
callGrafana = (robot, msg, url, callback) ->
  if grafana_api_key
    requestHeaders =
      json: true
      auth:
        bearer: grafana_api_key
  else if grafana_api_user and grafana_api_password
    requestHeaders =
      json: true
      auth:
        user: grafana_api_user
        pass: grafana_api_password
  else
    requestHeaders =
      json: true

  data = null
  request "#{grafana_host}/api/#{url}", requestHeaders, (err, res, body) ->
    if err?
      robot.logger.error "Connect Grafana Error: ", err
      msg.send "Connect Grafana Error: #{err.message}"
    else if (200 != res.statusCode)
      robot.logger.error "Connect Grafana Error: #{res.statusCode} - ", body
      msg.send "Connect Grafana Error: #{res.statusCode}"
    else
      data = body

    callback data


# Format the title with template vars
formatTitleWithTemplate = (title, template_map) ->
  title.replace /\$\w+/g, (match) ->
    if template_map[match]
      return template_map[match]
    else
      return match


# Send robot response
sendRobotResponse = (msg, title, image, link) ->
  # msg.send "#{title}: #{image} - #{link}"
  msg.send "#{title}: #{image}"


# Fetch an image from provided URL, upload it to S3, returning the resulting URL
fetchAndUpload = (robot, msg, title, url, link) ->
  if grafana_api_key
    requestHeaders =
      encoding: null
      auth:
        bearer: grafana_api_key
  else if grafana_api_user and grafana_api_password
    requestHeaders =
      encoding: null
      auth:
        user: grafana_api_user
        pass: grafana_api_password
  else
    requestHeaders =
      encoding: null

  request url, requestHeaders, (err, res, body) ->
    if err
      robot.logger.error "Fetch Error: ", err
      return msg.send "#{title} - [Fetch Error] - #{link}"
    robot.logger.debug "Uploading file: #{body.length} bytes, content-type[#{res.headers['content-type']}]"
    uploadToLocalServer(robot, msg, title, link, body, body.length, res.headers['content-type'])


# Upload image to local server
uploadToLocalServer = (robot, msg, title, link, content, length, content_type) ->
  filename = local_web_server.uploadPath content_type
  flowRoom = msg.message.room 
  robot.logger.info "file name is #{filename}"
  local_web_server.uploadToServer filename, content, (err)->
    if err
      robot.logger.error "Upload Error: ", err
      return msg.send "#{title} - [Upload Error] - #{link}"
    uploadToFlowdock.uploadToFlowdock robot, filename, flowRoom, (err,res) ->
      if err?
        robot.logger.error "Failed upload to flowdock: ", err
        return msg.send "Failed upload to flowdock: #{err.message}"

      if res?
        robot.logger.info "upload success: ", res

    #sendRobotResponse msg, title, local_web_server.resourceUrl filename, link


module.exports = (robot) ->
  # Capture unsupport options
  robot.respond /(?:grafana|graf) ((?!dash|dashboard|db|list)\w+)(.*)?/i, (msg) ->
    displayHelp robot, msg


  # Get a list of available dashboards
  robot.respond /(?:grafana|graf) list( (.+))?$/i, (msg) ->
    filter = msg.match[2]
    listDashboards filter, robot, msg


  # Get a specific dashboard with options
  robot.respond /(?:grafana|graf) (?:dash|dashboard|db) ([A-Za-z0-9\-\:_]+)(( [^\s=]+=[^\s=]+)*)(( (?:last) (\d+(d|h|m))|( (?:from) ([\d\-\/\:\s]+) (?:to) ([\d\-\/\:\s]+))))?(.*)?/i, (msg) ->
    slug = msg.match[1].trim()

    variables = ""
    if msg.match[2]
      for part in msg.match[2].trim().split ' '
        # Check if it's a variable
        if part.indexOf('=') >= 0
          variables = "#{variables}&var-#{part}"

    last = msg.match[6]
    from = msg.match[9]
    to = msg.match[10]
    timespan = {
      from: 'now-6h'
      to: 'now'
    }
    if last
      timespan = {
        from: "now-#{last}"
        to: 'now'
      }
    if from && to
      from = new Date(from.trim())
      to = new Date(to.trim())
      if !isNaN(from.getTime()) && !isNaN(to.getTime())
        from =  from.toISOString()
        from = from.slice(0, -5).replace(/\-/g, '').replace(/\:/g, '')
        to =  to.toISOString()
        to = to.slice(0, -5).replace(/\-/g, '').replace(/\:/g, '')
        timespan = {
          from: from
          to: to
        }
      else
        robot.logger.info "Invalid datetime string: from #{msg.match[9]} to #{msg.match[10]}"
        return msg.send "Invalid datetime format"

    getDashboard robot, msg, slug, timespan, variables
