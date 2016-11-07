# Description:
#   Action alias for hubot
#
# Commands:
#   hubot alias xxx=yyy - Create alias xxx for action yyy
#   hubot alias rm xxx - Remove alias xxx from the table
#   hubot alias clear - Clear the alias table
#   hubot alias - Display table of aliases as Key : Value pairs
#
# Author:
#   jesus.galvan@hpe.com
#
"use strict"

ALIAS_TABLE_KEY = 'hubot-alias-table'

loadArgumentsInAction = (args, action) ->
  args = args.trim()
  if args
    argItems = args.split(' ')
    for val, i in argItems
      if action.indexOf('$'+(i+1)) > -1 then action = action.replace('$'+(i+1), val) else action += " #{val}"
  action = action.replace(/\$\d+/g, "")
  action.trim()


module.exports = (robot) ->
  receiveOrg = robot.receive
  robot.receive = (msg)->
    table = robot.brain.get(ALIAS_TABLE_KEY) || {}
    orgText = msg.text?.trim()
    if new RegExp("(^[@]?(?:#{robot.name}|#{robot.alias})[:,]?)(\\s+)([^\\s]*)(.*)$").test orgText
      #Break up the command into action and arguments, we will determine what kind of command this is
      name = RegExp.$1
      sp = RegExp.$2
      action = RegExp.$3
      rest = RegExp.$4
      #Check if this is an alias command, if it is, treat it like a regular comand with action and args 
      if action != 'alias'
        #Check if this command exists in our alias table
        queried_action = table[action+rest]
        #If this alias exists in the table, then this is the action to execute without arguments
        if queried_action != undefined
          action = queried_action
          rest = ""
        msg.text = "#{name}#{sp}"
        msg.text += loadArgumentsInAction(rest, action)

    robot.logger.info "Replace \"#{orgText}\" as \"#{msg.text}\"" if orgText != msg.text
    receiveOrg.bind(robot)(msg)

  robot.respond /alias(.*)$/i, (msg)->
    text = msg.match[1].trim()
    table = robot.brain.get(ALIAS_TABLE_KEY) || {}

    #Alias command with clear argument, clear the table
    if text.toLowerCase() == 'clear'
      robot.brain.set ALIAS_TABLE_KEY, {}
      msg.send "Alias table cleared."

    #If there are no arguments, iterate through the table and print key:value pairs  
    else if !text
      format_table = ""
      for k, v of table
        format_table = format_table+ "#{k} : #{v}\n"
      msg.send "```\n#{format_table}```"

    #If there are arguments that match xxx=yyy format, create this entry in the table  
    else
      match = text.match /^(.*?)=(.*)?$/
      alias = match[1].trim()
      action = match[2].trim()
      if action?
        table[alias] = action
        robot.brain.set ALIAS_TABLE_KEY, table
        msg.send "\nAlias has been created:\n```\n#{alias} : #{action}\n```"

  #Check if this entry exists in the table, if it does delete it from the table
  robot.respond /alias rm (.*)$/i, (msg)->
    table = robot.brain.get(ALIAS_TABLE_KEY) || {}
    query_action = table[msg.match[1]]
    if query_action != undefined
      delete table[msg.match[1]]
      robot.brain.set ALIAS_TABLE_KEY, table
      msg.send "\nAlias ```#{msg.match[1]}``` has been removed.\n"
    else
      msg.send "\nThere was no alias ```#{msg.match[1]}``` found in the table."
