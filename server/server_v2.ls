PORT = 80
IP = \unknown
ONLY_LOCAL = false
BASEDIR = __dirname+"/.."
CACHE = image: 86400s # 3600s = 1h
TITLE = "Monopony Server"

MAX_USER_PER_IP = 32users

SPAM_THRESHOLD = 200ms # 1/5 of a second
SPAM_LIMIT = 10msgs
SPAM_FORGIVE = 10forgiven_spampoints_per_s
SPAM_BAN_TIME = 10s

require \colors
require! \http
app = http.createServer handler
# io = require('./socket.io.fixed.js').listen(app)
socket = require \socket.io
require! \fs

io = socket.listen app
io.set 'log level', 1

/*
= Features =
* Spam protection (max 10 messages to the server per 200ms)
* protection against inproper messages (invalid argument types etc)
* max 32 users per IP address
* decentralized game hosting (the server only relays messages and doesn't calculate the game itself)
	-> validity checks are to be done by the clients
* simple moderation system

*/

# fix `with` and the clone operator `^^` as their copied data gets lost on socket.emit
clone$ = -> return {} <<<< it

#== Auxiliaries ==
# helper for defining non-enumerable functions via Object.defineProperty
define = (property, fn) ->
	if @hasOwnProperty property
		console.warn "cannot redefine property", this, property, new TypeError!.stack

	else if @[property] != fn
		Object.defineProperty this, property, do
			enumerable: false
			writable: true
			configurable: true
			value: fn
define.call Object::, \define, define

Array::define \remove, ->
	index = @indexOf it
	if index != -1
		return @splice index, 1


generateID = (namespace) ->
	if namespace
		id = generateID!
		while id of namespace
			id = generateID!

		return id

	return (Math.random!*0x100000000).toString 16

# setTimeout with swapped parameters. why? because it's stylish
sleep = (time, callback) ->
	setTimeout callback, time

geoip = (ip) ->
	if ip == '::1' or ip == '127.0.0.1'
		return \local
	else if not global.geoip_data
		return ''
	if '.' in ip # IPv4
		v4 = true
		data = geoip_data.ipv4
		sep = '.'
		maxList = [255 to 0]


	else if ':' in ip # IPv6
		data = geoip_data.ipv4
		sep = ':'
		maxList = [i.toString 16 for i from 0xFFFF to 0 by -1]
	else
		return false

	for block in ip .split sep
		if data[block]
			data = data[block]
		else
			if v4
				list = [block to 0 by -1]
			else # if v6
				list = [i.toString 16 for i from parseInt(block, 16) to 0 by -1]

			for i in list
				if data[i]
					data = data[i]
					while typeof data == \object
						for i in maxList
							if data[i]
								data = data[i]
								break
					return data
			return false
	return data






#== helpers for the console ==
listPlayers = !->
	text = ""
	length = 0
	for id, player of players
		length++
		text +=  Monopony.player player
		if player.position == \LOBBY
			text +=  "\n  in #{'The Lobby'.magenta.bold}"
		else
			text += "\n  in room #{Monopony.room player.position}"
		text += "\n  avatar: #{player.avatar}\n\n"
		# text += "\n\bits: #{player.bits} bits\n"

	if length == 1
		text = ("[#{'1'.yellow} player online]\n").bold + text
	else
		text = ("[#{(length+'').yellow} players online]\n").bold + text

	return text

listRooms = !->
	# Lobby
	text = "= #{Monopony.room \LOBBY} =\n"
	for player in lobby
		text += "\t#{Monopony.player player}\n"
	else
		text += "<empty>\n".grey
	text += "\n"


	length = 0
	for id, room of rooms
		length++
		text +=  "= #{Monopony.room id} =\n"
		for player in room.players
			text += "  #{Monopony.player player}\n"
		# note: a room should not be empty, because empty rooms are autoremoved
		text += "\n"


	if length == 1
		text = "[#{'1'.yellow} room]\n".bold + text
	else
		text = "[#{(length+'').yellow} rooms]\n".bold + text

	return text

status = !->
	console.log "== STATUS ==".yellow.bold
	console.log "IP: ".grey.bold, "#{IP .magenta.bold}#{':'.bold}#{(PORT+'') .magenta.bold}"
	console.log "\n== Players ==".yellow.bold, listPlayers!
	console.log "== Rooms ==".yellow.bold, listRooms!
	console.log!

	console.log!
	time = Date.now!
	sleep 1ms, !->
		lag = Date.now! - time
		process.stdout.write "\x1b[2D\x1b[2A"
		switch
		| lag < 5ms =>
			console.log "LAG: ".grey.bold, "#{lag}ms".green.bold
		| lag < 10ms =>
			console.log "LAG: ".grey.bold, "#{lag}ms".yellow.bold
		| _ =>
			console.log "LAG: ".grey.bold, "#{lag}ms".red.bold
		console.log!
		process.stdout.write "\x1b[2C"

ban = (ipOrPlayer, reason="banned by admin") !->
	if player = Monopony.player ipOrPlayer
		Monopony.leaveRoom player, reason || "banned by admin"
		player.disconnect \banned
		banlist[player .ip] = true
	else if typeof ipOrPlayer == \string and /\d\d\d?\.\d\d?\d?\.\d\d?\d?/.test ipOrPlayer || /(\d{4}:){7}\d{4}/.test ipOrPlayer
		banlist[ipOrPlayer] = true
	else
		console.log "[!] couldn't ban player '#{ipOrPlayer}' (not found)".redBG.yellow.bold



kick = (player, reason="kicked by admin") !->
	if player = Monopony.player player
		Monopony.leaveRoom player, reason
		player.disconnect \kicked
	else
		console.log "[!] couldn't kick player '#{ipOrPlayer}' (not found)".redBG.yellow.bold


#== Auxiliaries ==
fields = ["[A] GO", "[B] Rock Farm", "[A] Community Chest", "[B] Ponyville", "[A] Income Tax", "[S] Ponyville Station", "[B] Fillydelphia", "[A] Chance", "[B] Hoofington", "[B] Trottingham", "[A] The Moon", "[B] Las Pegasus", "[U] Apple Harvest", "[B] Baltimare", "[B] Manehattan", "[S] Appleloosa Station", "[B] Appleloosa", "[A] Community Chest", "[B] Dodge Junction", "[B] Sweet Apple Acres", "[A] Free Parking", "[B] Canterlot Gardens", "[A] Chance", "[B] Ghastly Gorge", "[B] Whitetail Wood", "[S] Dodge Junction Station", "[B] The Everfree Forest", "[B] Froggy Bottom Bog", "[U] Weather Factory", "[B] Zecora's Hut", "[A] Banished To The Moon", "[B] Sugarcube Corner", "[B] Carousel Boutique", "[A] Community Chest", "[B] School House", "[S] Canterlot Station", "[A] Chance", "[B] Cloudsdale", "[A] Luxury Tax", "[B] Canterlot"]
Monopony = do
	# return text for a given room
	room: (idOrRoom) ->
		if !idOrRoom
			return false
		else if idOrRoom == \LOBBY
			return \LOBBY .magenta.bold
		else if typeof idOrRoom == \string
			idOrRoom = rooms[idOrRoom]
		if idOrRoom && typeof idOrRoom == \object and \name of idOrRoom and \id of idOrRoom
			return "#{idOrRoom.id .magenta} (#{idOrRoom.name .magenta.bold})"
		return false

	# return text for a given player
	player: (idOrPlayer) ->
		if !idOrPlayer
			return false
		if typeof idOrPlayer == \string
			idOrPlayer = players[idOrPlayer]
		if typeof idOrPlayer == \object and \name of idOrPlayer && \id of idOrPlayer
			return "#{idOrPlayer.id .cyan} (#{idOrPlayer.name .cyan.bold})"
		return false

	field: (fieldID) ->
		return fields[fieldID]

	# applies Monopony.player and Monopony.room to each item in the given Array when appropriate
	beautifyParams: (arr) ->
		res = new Array(arr.length)
		for el, i in arr
			res[i] = Monopony.player el || Monopony.room el || (if typeof el == \string then "\"#{el}\"" else el)

		return res


	userData: (socket) ->
		if typeof socket == \string
			socket = players[socket]
		return do
			id: socket.id
			name: socket.name
			avatar: socket.avatar
			playerController: \remote



	notifyAllInRoom: (roomOrPlayer, type, ...params) ->
		room = rooms[roomOrPlayer.position] || roomOrPlayer

		console `console.log .apply` (["> notifyAllInRoom".grey.bold, Monopony.room(room), type] ++ Monopony.beautifyParams params)
		for otherPlayer in room.players
			console.log "-->", Monopony.player otherPlayer
			otherPlayer `otherPlayer.emit .apply` ([type] ++ params)


	notifyAllInRoomButSelf: (player, type, ...params) !->
		room = rooms[player.position] || player
		console.log "> notifyAllInRoomButSelf".grey.bold, Monopony.room(room), Monopony.player(player), type, " : "
		console `console.log .apply` Monopony.beautifyParams params

		if not (room || players of room)
			console.log "[EROOR] $notifyAllInRoomButSelf with inproper room".bold.red, ([] ++ arguments)
			return false
		for otherPlayer in room.players when player != player
			console.log "-->", Monopony.player otherPlayer
			otherPlayer `otherPlayer.emit .apply` ([type] ++ params)



	notifyAllInLobby: (type, ...params) !->
		console `console.log .apply` (["> notifyAllInLobby".grey.bold, type] ++ Monopony.beautifyParams params)
		for otherPlayer in lobby
			console.log "-->", Monopony.player otherPlayer
			lobby[i] `otherPlayer.emit .apply` ([type] ++ params)



	leaveRoom: (player, reason) ->
		console.log "[leaveRoom]".grey.bold , Monopony.player(player), Monopony.room(player.position), reason
		room = rooms[player.position]
		room.players .remove player
		Monopony.notifyAllInRoom room, \playerLeftRoom, player.id, reason
		player.position = \LOBBY
		Monopony.gotoLobby player # watch out that this doesn't cause a loop

		if room.creator == player.id
			# kill the room
			# Monopony.notifyAllInRoom room, \roomClosed, room.id, reason
			Monopony.notifyAllInLobby \roomClosed, room.id, "host: "+reason
			Monopony.notifyAllInRoom room, \roomClosed, room.id, "host: "+reason
			for otherPlayer in room.players
				Monopony.leaveRoom otherPlayer, "host left"

			delete! rooms[room.id]



	gotoLobby: (player) ->
		oldPosition = player.position
		if player.position != \LOBBY && player.position != \SP
			# if the player is leaving a room
			Monopony.leaveRoom player, "left room" # watch out that this doesn't cause a loop

			lobby.push player


		roomList = {[i, room.name] for i, room of rooms}
		usersInLobby = [Monopony.userData(user) for user in lobby]
		player.emit \lobby, roomList, usersInLobby

		io.sockets.in \lobby .emit \otherUserJoined player.id, Monopony.userData player, oldPosition
		player.join \lobby

	avatars: fs.readdirSync "#{BASEDIR}/images/avatars/" .map (.replace /\..*?$/, '')
	#['Twilight', 'Pinkie Pie', 'Applejack', 'Rainbow Dash', 'Rarity', 'Fluttershy', 'Princess Luna', 'Spike', 'Gummy', 'Derpy', 'Colgate', 'Alptraum Mond', 'Brinkie Pie', 'Canpan', 'Cookie', 'Ryan', 'Swift', 'Thermal Cake', 'TropicDash', 'Death Mint', 'MrSleepyguy']
	checks: do
		String: -> typeof it == \string
		Number: -> isFinite it
		Array: -> it instanceof Array
		#pwhash: ->
		Player: -> typeof it == \string
		Room: -> typeof it == \string
		avatar: (avi) ->
			if avi in @avatars or /^https?:\/\//.test avi
				return true
		fieldID: -> (0 <= it < fields.length) and (i % 1 == 0)
		tradeSubject: -> subject == \returnFromTheMoonCard or checks.fieldID it

	on: (socket, event, expectedArgs, fn) ->
		<- socket.on event
		try
			o = 0
			for type, i in expectedArgs
				parg = arguments[o]
				if type[*-1] == '?'
					optional = true
					type .= substring 0, -1
				else
					optional = false

				if (not optional && parg?) and (not Monopony.checks[type] parg)
					console.log "[improper args!]".red.bold + "event: #{event}\n\texpected", expectedArgs, "\n\tgot", (slice$.call arguments)
					return false
			fn ...
		catch e
			console.log "[ERROR]".red.bold, "on event '".grey + event.yellow.bold + "'. arguments:".grey, (slice$.call arguments), "\n", e.stack.red





#== Main Server Logic ==
#= Multiplayer =
players = io.sockets.sockets
lobby = []
rooms = {}
SP = [] # SinglePlayer
banlist = {}
IPs = {}

/*
	room = do
		id: roomID,
		players: [Socket, Socket, ...],
		setup: false,
		creator: PLAYER-ID,

		options: ...


	player = socket = do
		ip: "AAAA.BB.CC.DD"
		spamCount: 0
		lastCommand: DATE
		name: "user-SOCKET.ID"
		avatar: ""
		position: \LOBBY OR \SP OR "<ROOM-ID>"
		# bits: 0

	= Notes =
	The game is completly hosted by the host. The server does NOT check for cheating or sanity.
	This is not a bug but by design
*/

io.sockets.on \connection, (socket) -> try
	socket.ip = socket.handshake.address.address
	IPs[socket.ip]++

	# check for unauthorized access
	if socket.ip of banlist
		if banlist[socket.ip] > Date.now!
			console.log "#{'==banned Client connected ['.red.bold}#{socket.id .cyan} (#{socket.ip .yellow.bold})#{']=='.red.bold}"
			socket.emit \error, 'ip banned'
			socket.disconnect \unauthorized
			return
		else
			delete! banlist[socket.ip]

	if IPs[socket.ip] > MAX_USER_PER_IP
		console.log "#{'==spamming Client connected ['.red.bold}#{socket.id .cyan} (#{socket.ip .yellow.bold})#{']=='.red.bold}"
		socket.emit \error, "too many connections from your IP (#{socket.ip})"
		socket.disconnect \unauthorized
		return

	console.log "==Client connected [".cyan.bold + socket.id.cyan + "] (".cyan.bold + "#{socket.ip} #{geoip socket.ip}".yellow.bold + ")==".cyan.bold
	global.socket = socket #DEBUG
	global.id = socket.id #DEBUG

	socket.on \disconnect, (data) ->
		console.log "#{'==Client disconnected ['.yellow.bold}#{Monopony.player(socket.id)} (#{socket.ip .yellow.bold})#{']=='.yellow.bold}"
		IPs[socket.ip]--
		if socket.position != \LOBBY && socket.position != \SP
			Monopony.leaveRoom socket, \disconnected
		lobby .remove socket

	socket.on \anything, ->
		date = Date.now!
		timediff = socket.lastCommand - date
		if timediff < SPAM_THRESHOLD
			socket.spamCount++
		else if socket.spamCount
			socket.spamCount = 0 >? Math.ceil socket.spamCount - timediff * SPAM_FORGIVE / 1_000 # converting ms to s

		if socket.spamCount > SPAM_LIMIT
			unbanTime = date + SPAM_BAN_TIME*1_000 # converting s to ms
			banlist[socket.ip] = unbanTime
			socket.disconnected \spam, SPAM_BAN_TIME, unbanTime


	socket.position = \LOBBY
	socket.name = "user-#{socket.id}"
	socket.avatar = ""
	socket.playerController = \remote

	Monopony.gotoLobby socket

	#= State independent =
	Monopony.on socket, \chat, [\String], (message) ->
		console.log "< chat".bold.grey, Monopony.player(socket.id), message.grey
		room = rooms[socket.position]

		Monopony.notifyAllInRoomButSelf socket, \chat, socket.id, Date.now!

	#= State: LOBBY =
	#socket.on \login, (username, passwordHash) ->
	#	console.log "< login".bold.grey, username
	#	...

	socket.on \changeName, (newName) ->
		console.log "< changeName".bold.grey, Monopony.player(socket.id), "->", newName.cyan.bold
		if socket.position == \LOBBY || socket.position == \SP
			socket.name = newName

		else if rooms[socket.position].setup
			socket.name = newName
			Monopony.notifyAllInRoomButSelf socket, \playerChangedName, socket.id, newName

	socket.on \changeAvatar, (newAvatar) ->
		console.log "< chanceAvatar".bold.grey, Monopony.player(socket.id), "-->", newAvatar
		if socket.position == \LOBBY || socket.position == \SP
			socket.avatar = newAvatar
		else if rooms[socket.position].setup
			socket.avatar  = newAvatar
			Monopony.notifyAllInRoomButSelf socket, \playerChangedAvatar, socket.id, newAvatar

	socket.on \createRoom, (reqID, options) ->
		console.log "< createRoom".bold.grey, Monopony.player(socket.id), options.name, options
		roomID = generateID rooms
		if !options.name
			options.name = roomID

		rooms[roomID] = do
			id: roomID,
			name: options.name,
			setup: true,
			players: [socket],
			currentPlayer: null,
			creator: socket.id,

			options: do
				startBits: +options.startBits || 1500
				# maxPlayers, allowBots, allowSpectators, extraRules={},


		socket.position = roomID
		lobby .remove socket

		Monopony.notifyAllInLobby \roomOpened, roomID, options.name
		socket.emit \ok, reqID, roomID

	socket.on \joinRoom, (reqID, roomID) ->
		console.log "< joinRoom".grey.bold, Monopony.player(socket.id), Monopony.room(roomID)
		if !roomID
			console.warn "--> no roomID specified"
			return
		room = rooms[roomID]
		if !room
			console.warn "--> no such room", roomID.red.bold
			socket.emit \notOk, reqID, "room does not exist"
			return

		socket.position = roomID
		lobby .remove socket
		room.players ++= socket
		Monopony.notifyAllInRoomButSelf socket, \playerJoinedRoom, Monopony.userData(socket)
		# Monopony.notifyAllInRoom(socket, \playerJoinedRoom, socket.id, socket.name, socket.avatar)
		players = [Monopony.userData otherPlayer.id for otherPlayer in room.players]
		socket.emit \ok, reqID, {players: players} <<<< room.options
		# is it good to tell the client ALL the rules? maybe he's not supposed to know... meh
		# that is up to decision, once custom rules are implemented


	#= State: INGAME ($isMod) =
	socket.on \startGame, ->
		console.log "< startGame".bold.grey, Monopony.player(socket.id)
		room = rooms[socket.position]
		if room.creator == socket.id
			room.setup = false
			Monopony.notifyAllInRoom socket, \gameStarted, socket.position
			Monopony.notifyAllInLobby \gameStarted, socket.position
		else
			console.log "\tperson requesting is not the host".yellow.bold
	socket.on \kick, (playerID, /*optional*/ reason) ->
		console.log "< kick".red.bold, Monopony.player(socket.id), "-->", Monopony.player(playerID), "(#{reason})"
		room = rooms[socket.position]

		if !players[playerID].position == room.id
			return socket.emit \chat, "[SYSTEM] there is no player with this ID in the room"

		if room.creator == socket.id
			players[playerID].emit \kicked, reason
			if reason
				reason = "kicked (#{reason})"
			else
				reason = "kicked"
			Monopony.leaveRoom players[playerID], reason
			# socket.emit \ok
		else
			socket.emit \chat, "[SYSTEM] only the host can kick other players."
			console.log "\tperson requesting is not the host".yellow.bold

	socket.on \ban, (username, /*optional*/ reason) ->
		console.log "< ban".bold.grey, username, reason
		...


	#= State: INGAME ($setup) =
	# socket.on \changeName, (newName) ->

	#= State: INGAME =
	#	Meta
	socket.on \joinLobby, ->
		console.log "< joinLobby".bold.grey, Monopony.player(socket.id)
		Monopony.gotoLobby socket


	#	game related
	socket.on \button, (btn) ->
		console.log "< button".bold.grey, Monopony.player(socket.id), "(#{reqNum})", btn
		Monopony.notifyAllInRoom socket, \button, socket.id, btn

	socket.on \request_dice, (reqNum) ->
		console.log "[request_dice]".bold.grey, "(#{reqNum})", Monopony.player(socket.id)
		Monopony.notifyAllInRoom socket, \dice, reqNum, Math.ceil(Math.random!*6), Math.ceil(Math.random!*6)

	socket.on \setFieldHouses, (fieldID, houses) ->
		console.log "< setFieldHouses".bold.grey, Monopony.player(socket.id), Monopony.field(fieldID), houses
		Monopony.notifyAllInRoom socket, \setFieldHouses, socket.id, btn

	socket.on \trade, (sellingOrBuying, otherUserID, subject, priceOffer) ->
		console.log "< trade".bold.grey, Monopony.player(socket.id), sellingOrBuying, Monopony.player(otherUserID), subject, priceOffer
		players[otherUserID].emit \tradeOffer, socket.id, sellingOrBuying, otherUserID, subject, priceOffer

	socket.on \tradeAccept, (otherUserID, subject) ->
		console.log "< tradeAccept".bold.grey, Monopony.player(socket.id), Monopony.player(otherUserID), subject
		players[otherUserID].emit \tradeAccept, socket.id, subject

	socket.on \tradeDeny, (otherUserID, subject) ->
		console.log "< tradeDeny".bold.grey, Monopony.player(socket.id), Monopony.player(otherUserID), subject
		players[otherUserID].emit \tradeDeny, socket.id, subject




	#= etc =
	/* socket.on \updateOptions, (options) ->
		console.log "< updateOptions".grey.bold, options
		room = rooms[socket.position]

		if room.creator == socket.id
			Monopony.notifyAllInRoom room, \updateOptions, options
		else
			socket.emit \chat, "[SYSTEM] only the host can change the options, ask him/her to do it."
			console.log "\tperson requesting is not the host".yellow.bold
	*/



	socket.emit \welcome, socket.id

catch e
	console.error "[ERROR]".bold.red, "on connecting to socket #{socket.id} (#{socket.handshake.address.address})\n".bold.red, e.stack.red
	socket.emit \error




#== HTTP server ==
require! \mime
urlToPath = (url) ->
	return BASEDIR + url
		#.replace(/\//g, '\\') # replace any slash with a windows-typical backslash
		.replace(/\.\.\\/g, '') # remove any "..\" -> The browser should do that, but Security goes first ;D
		.replace(/\/.*?\/\.\.\//g, '') # remove any "..\" -> Security goes first ;D
		.replace(/(?:#|\?).*/,'') # remove hash and query
		.replace(/\/$/, '/index.html') # extend "blabla/" to "blabla/index.html
		.replace(/%20/g, " ")
		.replace(/(\/[^\.]*)$/, '$1.html') # add .html to the end of the path if path does not contain an extension

function handler req, res
	try
		ip = req.connection.remoteAddress
		if /(?:.\.html?|\/)$/i.test(req.url)
			console.log "==User connects==".cyan.bold, "#ip #{geoip ip}".yellow.bold


		console.log "< #{req.url .cyan}"

		/*
		if req.url == "/GEOIP"
			res.writeHead 200, 'Content-Type': "text/plain"
			console.log "converting to JSON"
			res.end JSON.stringify geoip_data
			console.log "done"
			return
		*/

		paths = [urlToPath req.url]
		if /\/index\.html$/.test paths.0
			paths ++= paths.0.replace(/\/index\.html$/, ".html")
		else if "." not in paths.0 .substr BASEDIR.length
			paths ++= "#{paths.0}/index.html"

		tryFile = (path) ->
			(err, data) <- fs.readFile path
			if (err)
				if paths.length
					console.log "couldn't load: #{path.red.bold}"
					console.log "retrying..."
					tryFile paths.shift!
				else
					console.log "couldn't load: #{path.red.bold}", "[#{err.errno}]".bold.red

					if err.errno == 34
						res.writeHead 404
						res.end 'file not found :('
					else
						console.log "unknown error: ", err
						res.writeHead 500
						res.end 'internal error D:'

			mimeType = mime.lookup path
			console.log "> #{path.green} [#{mimeType}]"
			res.writeHead 200, do
				'Content-Type': mimeType
				'Cache-Control': "max-age=#{CACHE[req.url] || CACHE[path] || CACHE[mimeType] || CACHE[mimeType.replace(/\/.*/, "")] || 5}"

			res.end data

		tryFile paths.shift!
	catch e
		console.error "[INTERNAL ERROR]".bold.red, err
		res.writeHead 500
		res.end 'internal error D:'



# get IP
do ->
	data = ""
	request = http.request do
		hostname: "jsonip.appspot.com",
		port: 80,
		path: '/',
		method: \POST
		(response) ->
			response.on \data, (chunk) ->
				data += chunk

			response.on \end, (chunk) ->
				data += chunk
				IP := /(?:\d|\.)+/.exec(data).0
				console.log "server address: http://#{IP}:#{PORT}"

				console.log!
				require "./CLI_debug.js"

			response.on \error, ->
				console.log "#{'[Error]' .bold.red} receiving IP. Maybe you are not connected to the internet?\n".bold.red
				require "./CLI_debug.js"


	request.on \error, (e) ->
		console.log "#{'[Error]' .bold.red} receiving IP. Maybe you are not connected to the internet?\n".bold.red
		require "./CLI_debug.js"
	request.end!

# check lag
/*
setInterval do
	->
		for from 100 to 0
			void
		time1 = Date.now!
		sleep 0ms, ->
			time2 = Date.now!
			process.title = "#{TITLE} (#{time2 - time1}ms lag)"
	,3000ms
*/

app.on \error, ({errno}) ->
	if errno == \EADDRINUSE
		PORT++
		console.log "\nretrying on port #PORT".cyan
		app.listen PORT

app.listen PORT
console.log "\nrunning on port #PORT".cyan

console.log "use 'loadGeoIp()' to show IPs with their according country".yellow.bold
loadGeoIp = !->
	console.log "loading GeoIP data..."
	require! "./geoip_data.js" #DEBUG

global <<<< {PORT, IP, ONLY_LOCAL, BASEDIR, CACHE, TITLE, MAX_USER_PER_IP, SPAM_THRESHOLD, SPAM_LIMIT, SPAM_FORGIVE, SPAM_BAN_TIME, http, app, socket, fs, io, define, generateID, sleep, geoip, listPlayers, listRooms, status, ban, kick, fields, Monopony, players, lobby, rooms, SP, banlist, IPs, mime, urlToPath, loadGeoIp}
