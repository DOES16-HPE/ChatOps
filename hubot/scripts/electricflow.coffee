# Description:
#   Interact with your ElectricFlow server
#   This was built on EF 6.1.0
#
# Dependencies:
#   "./utilities/electricflow"
#
# Commands:
#   hubot ec list projects <filter> - lists ElectricFlow projects. If a project is specified, its procedures are listed.
#   hubot ec list env - list all environments in the system
#   hubot ec destroy env <env> - deleting an environment from the system
#   hubot ec run <procedure> of <project> - runs the specified ElectricFlow procedure. 
#   hubot ec run <procedure> of <project>, <params> - runs the specified ElectricFlow procedure with parameters as key=value&key2=value2
#   hubot ec status <jobId> - Status abot the specified ElectricFlow job.
#
# Author:
#   daniel.perez3@hpe.com,da-sheng.jian@hpe.com,lucas.gravley@hpe.com
#

ec = require './utilities/electricflow'

module.exports = (robot) ->
  robot.respond /ec list env/i, (msg) ->
    robot.logger.info "List environments"

    ec.listEnvironments (err, environments) ->
      if err?
        robot.logger.error "Failed to list environments", err
        return msg.send "ElectricFlow says: #{err.message}"

      response = "Available environments:\n"
      for environment in environments
        response = response + "#{environment.environmentName}\n"
      response.trim()
      msg.send response
      
  robot.respond /(?:ec) destroy env (.*)?/i, (msg) ->
    environment = msg.match[1]
    robot.logger.info "Deleting env '#{environment}'."

    project = "Default"
    procedure = "TerminateEnvironment"
    robot.logger.info "Run procedure '#{procedure}' of project '#{project}'."

    parameters = {}
    parameters["Environment"] = environment
    robot.logger.info "with parameters: ", parameters

    ec.runProcedure project, procedure, parameters, (err, result) =>
      if err?
        robot.logger.error "Failed to delete environment", err
        return msg.send "ElectricFlow says: #{err.message}"

      robot.logger.debug "Procedure is run: ", result
      response = "Job is scheduled, jobId is #{result.jobId}.\n"
      response = response + "To query the job status: ec status #{result.jobId}"
      msg.send response

      robot.logger.debug "Deleting environment ", result
      response = "The environmment should now be deleted.\n"
      msg.send response

  robot.respond /(?:ec) list projects( (.+))?/i, (msg) ->
    filter = msg.match[2]
    robot.logger.info "List projects with filter #{filter}."

    ec.listProjects (err, projects) ->
      if err?
        robot.logger.error "Failed to list projects", err
        return msg.send "ElectricFlow says: #{err.message}"

      matched_project = null
      filtered_projects = []
      if filter?
        for project in projects
          if project.projectName.toLowerCase() == filter.toLowerCase()
            matched_project = project
            break
           else if project.projectName.toLowerCase().indexOf(filter.toLowerCase()) >= 0
             filtered_projects.push(project)
       else
         filtered_projects = projects

      if matched_project?
        ec.listProcedures matched_project, (err, procedures) =>
          if err?
            robot.logger.error "Failed to list procedures", err
            return msg.send "ElectricFlow says: #{err.message}"

          response = "Available procedures:\n"
          for procedure in procedures
            response = response + "#{procedure.procedureName}\n"
          response.trim()
          msg.send response
      else
        response = "Available projects:\n"
        for project in filtered_projects
          response = response + "#{project.projectName}\n"
        response.trim()
        msg.send response

  robot.respond /(?:ec) run (\S+) of (\S+)(.*)?/i, (msg) ->
    project = msg.match[2]
    procedure = msg.match[1]
    reminder = msg.match[3]
    robot.logger.info "Run procedure '#{procedure}' of project '#{project}'."

    parameters = null
    if reminder?
      parameters = {}
      for part in reminder.trim().split ' '
        if part.indexOf('=') > 0
          key_values = part.split('=', 2)
          parameters[key_values[0]] = key_values[1]
      robot.logger.info "with parameters: ", parameters

    ec.runProcedure project, procedure, parameters, (err, result) =>
      if err?
        robot.logger.error "Failed to run procedure", err
        return msg.send "ElectricFlow says: #{err.message}"

      robot.logger.debug "Procedure is run: ", result
      response = "Job is scheduled, jobId is #{result.jobId}.\n"
      response = response + "To query the job status: ec status #{result.jobId}"
      msg.send response

  robot.respond /(?:ec) status ([a-f\d]{8}(-[a-f\d]{4}){3}-[a-f\d]{12})/i, (msg) ->
    jobId = msg.match[1]
    robot.logger.info "Query job #{jobId} status."

    ec.getJob jobId, (err, job) =>
      if err?
        robot.logger.error "Failed to query job status", err
        return msg.send "ElectricFlow says: #{err.message}"

      robot.logger.debug "Job status is: ", job
      response = "Job Status: #{job.status}\n"
      for step in job.jobStep
        response = response + " - #{step.stepName}: #{step.status}\n"
      response.trim()
      msg.send response
