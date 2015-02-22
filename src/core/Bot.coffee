irc = require 'irc'
path = require 'path'

wrapperFuncs = [
	'connect'
	'disconnect'
	'send'
	'activateFloodProtection'
	'join'
	'part'
	'say'
	'action'
	'notice'
	'whois'
	'list'
	'ctcp'
]

events = [
	'registered'
	'motd'
	'names'
	'topic'
	'join'
	'part'
	'quit'
	'kick'
	'kill'
	'message'
	'message#'
	'notice'
	'ping'
	'pm'
	'ctcp'
	'ctcp-notice'
	'ctcp-privmsg'
	'ctcp-version'
	'nick'
	'invite'
	'+mode'
	'-mode'
	'whois'
	'channellist_start'
	'channellist_item'
	'channellist'
	'raw'
	'error'
]

class Bot
	constructor: (@botManager, @config) ->
		# Private members
		name = @config.name

		# Accessor for private members
		@getName = -> name
		
		@dateStarted = new Date()

		@userManager = new @botManager.userManagerClasses[@config.auth]()
		@conn = new irc.Client @config.server, @config.nick, @config

		@conn.on 'error', (msg) =>
			console.error 'Error: ', msg

		@conn.on 'raw', (msg) =>
			console.log '>>>', @messageToString msg if @config.verbose

		@conn.on 'message', (from, to, text, msg) =>
			@botManager.moduleManager.handleMessage @, from, to, text

		@conn.send 'nickserv', "identify #{@config.password}" if @config.password

	messageToString: (msg) ->
		return "#{if msg.prefix? then ':' + msg.prefix + ' ' else ''}#{msg.rawCommand} #{msg.args.map((a) -> '"' + a + '"')}"

	# Returns the channels the bot is currently in.
	getChannels: -> chan for chan of @conn.chans # Clone the object

	getUsers: (chan) ->
		return [] if not chan
		chan = chan.toLowerCase()
		users = {}
		users = @conn.chans[chan].users if @conn.chans[chan]?
		key for key,value of @conn.chans[chan].users

	getUsersWithPrefix: (chan) ->
		chan = chan.toLowerCase()
		users = {}
		users = @conn.chans[chan].users if @conn.chans[chan]?
		value+key for key,value of @conn.chans[chan].users

	getTopic: (chan) ->
		return @conn.chans[chan].topic if @conn.chans[chan]?
		return ''

	getNick: -> @conn.nick

	getServer: -> @conn.opt.server

	getModules: -> @botManager.moduleManager.modules

	# Attempts to change nick.
	# On success callback is called with (undefined, oldnick, newnick, channels, msg).
	# On error callback is called with (err) where err is the error object (see 'error' event in irc.Client).
	changeNick: (desiredNick, callback) ->
		@conn.send 'NICK', desiredNick

		nickListener = (oldnick, newnick, channels, message) =>
			if newnick is desiredNick
				removeListeners()
				callback undefined, oldnick, newnick, channels, message

		errListener = (msg) =>
			if 431 <= msg.rawCommand <= 436 # irc errors for nicks
				removeListeners()
				callback msg

		removeListeners = =>
			@conn.removeListener 'raw', errListener
			@conn.removeListener 'nick', nickListener

		@conn.on 'nick', nickListener
		@conn.on 'raw', errListener

	setConfig: (key, value) ->
		if not (key in @config.overrides)
			@config.overrides.push key
		@config[key] = value
		@botManager.writeConfig()

# Wraps functions from irc.Client
for f in wrapperFuncs
	Bot::[f] = do (f) ->
		-> irc.Client::[f].apply @conn, arguments

exports.Bot = Bot
exports.events = events
