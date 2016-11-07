# Description:
#   Capture the web page
#
# Dependencies:
#   "phantomjs": "^1.9.18"
#
# Configuration:
#

phantom = require 'phantom'

loadWebPage = (url, cb) =>
  phantom.create (ph) ->
    ph.createPage (page) ->
      page.set 'viewportSize', {width: 1024, height: 768}
      page.set 'onResourceError', (resourceError) =>
        page.reason = resourceError.errorString
        page.reason_url = resourceError.url
      page.set 'resourceTimeout', (request) =>
        page.reason = request.errorString
        page.reason_url = request.url
      page.open url, (status) ->
        if status == 'fail'
          err = new Error "Failed to open url '#{page.reason_url}': #{page.reason}"
          ph.exit()
          return cb err
        cb null, ph, page

captureWebPage = (url, filename, cb) =>
  loadWebPage url, (err, ph, page) ->
    if err?
      return cb err
    page.render filename, ->
      ph.exit()
      return cb null

captureWebElement = (url, selector, filename, cb) =>
  loadWebPage url, (err, ph, page) ->
    if err?
      return cb err
    page.evaluate (selector)->
      return document.querySelector(selector).getBoundingClientRect()
    , (clipRect) ->
      page.set 'clipRect',
        top: clipRect.top
        left: clipRect.left
        width: clipRect.width
        height: clipRect.height
      page.render filename, ->
        ph.exit()
        return cb null
    , selector

captureWebPageUtillTargetLoaded = (url, target, filename, timeOutMillis, cb) =>
  loadWebPage url, (err, ph, page) ->
    if err?
      return cb err
    waitFor (cb) ->
      page.evaluate (target) ->
        return document.querySelector(target)?
      , cb, target
    , (err) ->
      if err?
        return cb err
      page.render filename, ->
        ph.exit()
        return cb null
    , timeOutMillis

captureWebElementUtillTargetLoaded = (url, selector, target, filename, timeOutMillis, cb) =>
  loadWebPage url, (err, ph, page) ->
    if err?
      return cb err
    waitFor (cb) ->
      page.evaluate (target) ->
        return document.querySelector(target)?
      , cb, target
    , (err) ->
      if err?
        return cb err
      page.evaluate (selector) ->
        return document.querySelector(selector).getBoundingClientRect()
      , (clipRect) ->
        page.set 'clipRect',
          top: clipRect.top
          left: clipRect.left
          width: clipRect.width
          height: clipRect.height
        page.render filename, ->
          ph.exit()
          return cb null
      , selector
    , timeOutMillis

waitFor = (testFx, onReady, timeOutMillis) ->
  maxtimeOutMillis = if timeOutMillis then timeOutMillis else 3000
  start = new Date().getTime()
  condition = false
  interval = setInterval ->
    if ((new Date().getTime() - start < maxtimeOutMillis) && !condition)
      testFx (result) ->
        condition = result
    else
      if condition
        onReady null
        clearInterval interval
      else
        err = new Error 'Page load timeout: ' + (new Date().getTime() - start) + 'ms.'
        onReady err
        clearInterval interval
  , 250

exports.captureWebPage = captureWebPage
exports.captureWebElement = captureWebElement
exports.captureWebPageUtillTargetLoaded = captureWebPageUtillTargetLoaded
exports.captureWebElementUtillTargetLoaded = captureWebElementUtillTargetLoaded
