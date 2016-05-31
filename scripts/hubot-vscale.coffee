# Description:
#   Interact with vscale API using token
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_VSCALE_LOCATION - datacenter location spb0 or msk0
#   HUBOT_VSCALE_RPLAN - type of instance small or medium or large or huge or monster
#   HUBOT_VSCALE_OS - OS to use
#        debian_8.1_64_001_master
#        centos_7.1_64_001_master
#        ubuntu_14.04_64_002_master
#        centos_6.7_64_001_master
#        debian_7_64_001_master
#        opensuse_13.2_64_001_preseed
#        fedora_23_64_001_master
#        centos_7.2_64_001_master
#        ubuntu_16.04_64_001_master
#        ubuntu_14.04_64_001_ajenti
#        ubuntu_14.04_64_001_vesta
#        debian_8.1_64_001_master
#        ubuntu_14.04_64_002_master
#        centos_7.1_64_001_master
#        debian_7_64_001_master
#        opensuse_13.2_64_001_preseed
#        centos_6.7_64_001_master
#        fedora_23_64_001_master
#        centos_7.2_64_001_master
#        ubuntu_16.04_64_001_master
#        ubuntu_14.04_64_001_ajenti
#        ubuntu_14.04_64_001_vesta
#
# Commands:
#   hubot vscale set auth <apitoken> - Set vscale credentials (get token from https://vscale.io/panel/settings/tokens/)
#   hubot vscale list - lists all your servers
#   hubot vscale describe <serverId> - Describe the server with specified id
#   hubot vscale start <serverId> - Start the server with specified id
#   hubot vscale stop <serverId> - Stop the server with specified id
#   hubot vscale delete <serverId> - Delete the server with specified id
#   hubot vscale restart <serverId> - Restart the server with specified id
#   hubot vscale run <serverName> - Run new server with specified name
#
# Author:
#   Nagaev Maksim

generatePassword = require 'password-generator'
querystring = require 'querystring'

default_location = process.env.HUBOT_VSCALE_LOCATION || "spb0"
default_rplan = process.env.HUBOT_VSCALE_RPLAN || "small"
default_os = process.env.HUBOT_VSCALE_OS || "ubuntu_16.04_64_001_master"

api_url = "https://api.vscale.io/v1"

createSignedRequest = (url, msg) ->
  user_id = msg.envelope.user.id
  token = msg.robot.brain.data.users[user_id].vscale_auth
  if !token
    msg.send "Please set auth token first"
    return false

  req = msg.robot.http(url)
  req.header('X-Token', token)
  req.header('Accept', 'application/json')
  req.header('Content-Type', 'application/json;charset=UTF-8')
  return req

vscaleRun = (msg) ->
  serverName = querystring.escape msg.match[1]
  password = generatePassword()

  req = createSignedRequest("#{api_url}/scalets", msg)
  if req == false
    return

  dataObj = {
    "make_from": default_os,
    "rplan": default_rplan,
    "do_start": true,
    "name": serverName,
    "password": password,
    "location": default_location
  }

  req.post(JSON.stringify(dataObj)) (err, res, body) ->
    if err
      msg.send "Vscale says: #{err}"
    else
      try
        response = ""
        content = JSON.parse(body)
        response += "Server created:\n"
        response += "Please save password: #{password}\n\n"
        response += "Status: #{content.status}\n"
        response += "Rplan: #{content.rplan}\n"
        response += "Locked: #{content.locked}\n"
        response += "Name: #{content.name}\n"
        response += "PublicIP: #{content.public_address.address}\n"
        response += "Hostname: #{content.hostname}\n"
        response += "Locations: #{content.locations}\n"
        response += "Active: #{content.active}\n"
        response += "Made From: #{content.made_from}\n"

        msg.send response
      catch error
        msg.send error

vscaleAction = (msg, action) ->
  ctid = querystring.escape msg.match[1]
  safeAction = querystring.escape action

  req = createSignedRequest("#{api_url}/scalets/"+ctid+"/"+safeAction, msg)
  if req == false
    return

  data = JSON.stringify({
    id: ctid
  })
  req.patch(data) (err, res, body) ->
    if err
      msg.send "Vscale says: #{err}"
    else
      try
        content = JSON.parse(body)
        response = action+" successful"
        msg.send response
      catch error
        msg.send error

vscaleDelete = (msg) ->
  ctid = querystring.escape msg.match[1]

  req = createSignedRequest("#{api_url}/scalets/"+ctid, msg)
  if req == false
    return

  req.delete() (err, res, body) ->
    if err
      msg.send "Vscale says: #{err}"
    else
      try
        content = JSON.parse(body)
        response = "Server deleted"
        msg.send response
      catch error
        msg.send error



vscaleDescribe = (msg) ->
  ctid = querystring.escape msg.match[1]

  req = createSignedRequest("#{api_url}/scalets/"+ctid, msg)
  if req == false
    return

  req.get() (err, res, body) ->
    if err
      msg.send "Vscale says: #{err}"
    else
      response = ""
      try
        content = JSON.parse(body)
        response += "Status: #{content.status}\n"
        response += "Rplan: #{content.rplan}\n"
        response += "Locked: #{content.locked}\n"
        response += "Name: #{content.name}\n"
        response += "PublicIP: #{content.public_address.address}\n"
        response += "Hostname: #{content.hostname}\n"
        response += "Locations: #{content.locations}\n"
        response += "Active: #{content.active}\n"
        response += "Made From: #{content.made_from}\n"
        msg.send response

      catch error
        msg.send error

vscaleAuth = (msg) ->
  user_id = msg.envelope.user.id
  credentials = msg.match[1].trim()
  msg.robot.brain.data.users[user_id].vscale_auth = credentials
  msg.send "Saved vscale token for #{user_id}"

vscaleList = (msg) ->
  req = createSignedRequest("#{api_url}/scalets", msg)
  if req == false
    return

  req.get() (err, res, body) ->
    response = ""
    response += "Name-------ID---------IP-------Status-------Plan\n"
    if err
      msg.send "Vscale says: #{err}"
    else
      try
        content = JSON.parse(body)
        for server in content
          response += "#{server.name}-------#{server.ctid}---------#{server.public_address.address}-------#{server.status}-------#{server.rplan}\n"
        msg.send response
      catch error
        msg.send error



module.exports = (robot) ->

#  Used for debug purposes
#  proxy = require 'proxy-agent'
#  process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";
#  robot.globalHttpOptions.httpAgent  = proxy('http://127.0.0.1:8888', false)
#  robot.globalHttpOptions.httpsAgent = proxy('http://127.0.0.1:8888', true)


  robot.respond /vs(?:cale)? list( (.+))?/i, (msg) ->
    vscaleList(msg)

  robot.respond /vs(?:cale)? describe (\d+)/i, (msg) ->
    vscaleDescribe(msg)

  robot.respond /vs(?:cale)? restart (\d+)/i, (msg) ->
    vscaleAction(msg, "restart")

  robot.respond /vs(?:cale)? start (\d+)/i, (msg) ->
    vscaleAction(msg, "start")

  robot.respond /vs(?:cale)? stop (\d+)/i, (msg) ->
    vscaleAction(msg, "stop")

  robot.respond /vs(?:cale)? delete (\d+)/i, (msg) ->
    vscaleDelete(msg)

  robot.respond /vs(?:cale)? set auth (.*)/i, (msg) ->
    vscaleAuth(msg)

  robot.respond /vs(?:cale)? run ([\w-_.]*)/i, (msg) ->
    vscaleRun(msg)