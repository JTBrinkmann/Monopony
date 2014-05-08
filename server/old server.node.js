PORT = 80
ONLY_LOCAL = false
BASEDIR = ".." // __dirname
CACHE = {
	"image": 86400 // 3600s = 1h
}
IP = "unknown"

require('colors');
http = require('http');
app = http.createServer(handler);
//io = require('./socket.io.fixed.js').listen(app);
socket = require('socket.io'); io = socket.listen(app);
fs = require('fs');
mime = require('mime');


function urlToPath(url){
	return BASEDIR + url
//		.replace(/\//g, '\\') // replace any slash with a windows-typical backslash
		//.replace(/\.\.\\/g, '') // remove any "..\" -> Security goes first ;D
		.replace(/\/.*?\/\.\.\//g, '') // remove any "..\" -> Security goes first ;D
		.replace(/(?:#|\?).*/,'') // remove hash and query
		.replace(/\/$/, '/index.html') // extend "blabla/" to "blabla/index.html
		.replace(/%20/g, " ")
		.replace(/(\/[^\.]*)$/, '$1.html') // add .html to the end of the path if path does not contain an extension
}

function removeFromArray(array, item) {
	array.splice(array.indexOf(item), 1)
}
io.settings.log=false;
app.listen(PORT);

function handler (req, res) {
	if(/(?:.\.html?|\/)$/i.test(req.url))
		console.log("==User connects==".cyan.bold, req.connection.remoteAddress);



	console.log();
	console.log("requesting " + req.url.cyan);

//		path = "C:\\Windows" //__dirname
// + (/^\/[^\w]/.test(req.url) ? '/index.html' : req.url.replace(/\?.*/,'').replace(/\//g, "\\"))
//.replace(/\\css\\/g, "\\").replace(/\\js\\/g, "\\").replace(/\\images\\/g, "\\");
	var paths = [urlToPath(req.url)]
	if(paths[0].lastIndexOf("/index.html") == paths[0].length - "/index.html".length)
		paths.push(paths[0].replace(/\/index\.html$/, ".html"))
	else if (paths[0].indexOf(".") == -1)
		paths.push(paths[0]+"/index.html")
	//paths.push(paths[0].replace(/\.html?(\/index\.html)?$/, "/index.html"))

	var tryFile = function(path) {
		fs.readFile(path, function (err, data) {
			if (err) {
				if(paths.length) {
					console.log("couldn't load: "+path.red.bold)
					console.log("retrying...");
					tryFile(paths.shift())
				} else {
					console.log("couldn't load: "+path.red.bold, ("["+err.errno+"]").bold.red);
					if(err.errno!=34)
						console.log("unknown error: ", err);
//						console.log("file not found".red);
					res.writeHead(err.errno==34 ? 404 : 500);
					return res.end(err.errno==34 ? 'page not found :(' : 'internal error D:');
				}
			}

			console.log("sending: "+path.green);
			var mimeType = mime.lookup(path)
			res.writeHead(200, {
				 'Content-Type': mimeType
				,'Cache-Control': 'max-age=' + CACHE[req.url] || CACHE[path] || CACHE[mimeType] || CACHE[mimeType.replace(/\/.*/, "")] || 5
			});
			return res.end(data);
		});
	}
	tryFile(paths.shift())
}








extend = function(obj) {
	for(var i=1,l=arguments.length; i<l; i++) {
		for (var key in arguments[i])
			obj[key] = arguments[i][key]
	}
	return obj
}

listPlayers = function() {
	var text = ""
	var length = 0
	for(var i in players) {
		length++
		text +=  Monopony.player(players[i])
		if (players[i].position == "LOBBY")
			text +=  "\n\tin the " + "lobby".magenta.bold
		else
			text += "\n\tin room " +Monopony.room(players[i].position)
		text += "\n\tavatar: "+players[i].avatar + "\n"
		//text += "\n\bits: "+players[i].bits + " bits\n"
	}
	if (length == 1)
		text = ("["+"1".yellow+" player online]\n").bold + text
	else
		text = ("["+(length+"").yellow+" players online]\n").bold + text

	return text
}
listRooms = function() {
	var text = ""

	// Lobby
	text +=  "= "+Monopony.room("LOBBY") + " =\n"
	for (var o = 0, player; player = lobby[o]; o++) {
		text += "\t "+Monopony.player(player)+"\n"
	}

	var length = 0
	for(var i in rooms) {
		length++
		text +=  "= "+Monopony.room(rooms[i]) + " =\n"
		for (var o = 0, player; player = rooms[i].players[o]; o++) {
			text += "\t "+Monopony.player(player)+"\n"
		}
	}
	if (length == 1)
		text = ("["+"1".yellow+" room]\n").bold + text
	else
		text = ("["+(length+"").yellow+" rooms]\n").bold + text

	return text
}
status = function() {
	console.log("== STATUS ==".yellow.bold)
	console.log("IP: ".grey.bold, IP.magenta.bold+":".bold+(PORT+"").magenta.bold)
	console.log("\n== Players ==\n".yellow.bold, listPlayers())
	console.log("== Rooms ==\n".yellow.bold, listRooms())
	var lag=Date.now()
	setTimeout(function(){
		console.log("LAG: ".grey.bold, (Date.now()-lag+"ms").yellow.bold)
	}, 1)
}


Monopony = {
	// return text for a given room
	 room: function(idOrRoom) {
		if (!idOrRoom)
			return false
		else if (idOrRoom == "LOBBY")
			return "LOBBY".magenta.bold
		else if (typeof idOrRoom == "string")
			idOrRoom = rooms[idOrRoom]
		if (idOrRoom && typeof idOrRoom == "object" && "name" in idOrRoom && "id" in idOrRoom)
			return idOrRoom.id.magenta + " ("+idOrRoom.name.magenta.bold+")"
		return false
	}
	// return text for a given player
	,player: function(idOrPlayer) {
		if (!idOrPlayer)
			return false
		if (typeof idOrPlayer == "string")
			idOrPlayer = players[idOrPlayer]
		if (idOrPlayer && typeof idOrPlayer == "object" && "name" in idOrPlayer && "id" in idOrPlayer)
			return idOrPlayer.id.cyan + " ("+idOrPlayer.name.cyan.bold+")"
		return false
	}
	// applies Monopony.player and Monopony.room to each item in the given Array when appropriate
	,beautifyParams: function(arr) {
		var res=new Array(arr.length)
		for (var i=arr.length; i--;) {
			res[i] = Monopony.player(arr[i]) || Monopony.room(arr[i]) || (typeof arr[i] == "string" ? '"'+arr[i]+'"' : arr[i])
		}
		return res
	}

	,minifyPlayer: function(socket) {
		if (typeof socket == "string")
			socket = players[socket]
		return {
			id: socket.id,
			name: socket.name,
			avatar: socket.avatar,
			playerController: "remote"
		}
	}

	,notifyAllInRoom: function(roomOrPlayer, type /*, params*/) {
		var room = rooms[roomOrPlayer.position] || roomOrPlayer
		var params = []
		for(var i=arguments.length-1; i>1; i--)
			params[i-2]=arguments[i]
		console.log.apply(console, ["[$notifyAllInRoom]".grey.bold, Monopony.room(room), type].concat(Monopony.beautifyParams(params)))
		for (var i=room.players.length; i--;) {
			console.log("-->", Monopony.player(room.players[i]))
			room.players[i].emit.apply(room.players[i], [type].concat(params))
		}
	}
	,notifyAllInRoomButSelf: function(player, type /*, params*/) {
		var room = rooms[player.position] || player
		var params = []
		for(var i=arguments.length-1; i>1; i--)
			params[i-2]=arguments[i]
		console.log.apply(console, ["[$notifyAllInRoomButSelf]".grey.bold, Monopony.room(room), Monopony.player(player), type].concat(Monopony.beautifyParams(params)))
		for (var i=room.players.length; i--;) {
			if (room.players[i] != player) {
				console.log("-->", Monopony.player(room.players[i]))
				room.players[i].emit.apply(room.players[i], [type].concat(params))
			}
		}
	}
	,notifyAllInLobby: function(type /*, params*/) {
		var params = []
		for(var i=arguments.length-1; i>0; i--)
			params[i-1]=arguments[i]
		console.log.apply(console, ["[$notifyAllInLobby]".grey.bold, type].concat(Monopony.beautifyParams(params)))
		for (var i=lobby.length; i--;) {
			console.log("-->", Monopony.player(lobby[i]))
			lobby[i].emit.apply(lobby[i], [type].concat(params))
		}
	}

	,leaveRoom: function(player, reason) {
		console.log("[leaveRoom]".grey.bold , Monopony.player(player), Monopony.room(player.position), reason)
		var room = rooms[player.position]
		removeFromArray(room.players, player)
		Monopony.notifyAllInRoom(room, "playerLeftRoom", player.id, reason)
		player.position = "LOBBY"
		Monopony.gotoLobby(player) // watch out that this doesn't cause a loop

		if (room.creator == player.id) {
			// kill the room
			//Monopony.notifyAllInRoom(room, "roomClosed", room.id, reason)
			Monopony.notifyAllInLobby("roomClosed", room.id, "host: "+reason)
			Monopony.notifyAllInRoom(room, "roomClosed", room.id, "host: "+reason)
			for (var i=room.players.length; i--;) {
				Monopony.leaveRoom(room.players[i], "host left")
			}
			delete rooms[room.id]
		}
	}

	,gotoLobby: function(player) {
		if (player.position != "LOBBY" && player.position != "SP") {
			// if the player is leaving a room
			Monopony.leaveRoom(player, "left room") // watch out that this doesn't cause a loop

			lobby.push(player)
		}

		var roomList = {}
		for (var i in rooms)
			roomList[i] = rooms[i].name

		player.emit("roomList", roomList)
	}

	,generateID: function(namespace) {
		if (namespace) {
			var id = Monopony.generateID()
			while (id in namespace) {
				id = Monopony.generateID()
			}
			return id
		}
		return (Math.random()*0x100000000).toString(16)
	}
}


// = Multiplayer =
players = io.sockets.sockets
lobby = []
rooms = {}
SP = [] // SinglePlayer

/*
room = {
	id: roomID,
	players: [Socket, Socket, ...],
	setup: false,
	creator: PLAYER-ID,

	options: {...}
}

player = socket = {
	name: "user-SOCKET.ID",
	avatar: "",
	position: "LOBBY" OR "SP" OR "<ROOM-ID>",
	//bits: 0
}

Client -> Server = [ gotoLobby(), startSP(), createRoom(reqID, options), joinRoom(reqID, id), request_dices(reqNum), changeName(newName), changeAvatar(newAvatar), button(reqNum, btn) ]
Client (host) -> Server = [ ..., startGame(), kick(playerID), updateOptions(options) ]

Server -> Client (SP) = [ ]
Server -> Client (lobby) = [ ok(reqID, data), notOK(reqID, reason), roomList(rooms), roomOpened(id, name), roomClosed(id), gameStarted(id) ]
Server -> Client (ingame) = [ ok(reqID, data), notOK(reqID, reason), gameStarted(id), dice(reqNum, dice1, dice2), button(reqNum, btn), buttonCheck(reqNum, btn, playerID), playerLeftRoom(id, reason), playerJoinedRoom(data), roomOpened(id, roomName), kicked(reason), roomClosed(id, reason), playerChangedName(id, newName), playerChangedAvatar(id, newAvatar), chat(fromID, msg), updateOptions(options) ]
Server -> Client (host) = [ ..., buttonCheck(reqNum, btn, playerID) ]

= Notes =
The game is completly hosted by the host. The server does NOT check for cheating or sanity.
This is not a bug but by design
*/

io.sockets.on('connection', function (socket) {
	console.log("==Client connected [".cyan.bold+socket.id.cyan+"]==".cyan.bold)
	global.socket = socket //DEBUG
	global.id = socket.id //DEBUG
	socket.ID = Monopony.generateID(players)

	socket.on('disconnect', function (data) {
		console.log("==Client disconnected [".yellow.bold+Monopony.player(socket.id)+"]==".yellow.bold)
		if (socket.position != "LOBBY" && socket.position != "SP")
			Monopony.leaveRoom(socket, "disconnected")
		removeFromArray(lobby, socket)
	})


	socket.position = "LOBBY"
	socket.name = "user-"+socket.id
	socket.avatar = ""
	socket.playerController = "remote"
	lobby.push(socket)

	Monopony.gotoLobby(socket)



	socket.on('gotoLobby', function () {
		console.log("[*gotoLobby]".bold.grey, Monopony.player(socket.id))
		Monopony.gotoLobby(socket)
	})

	socket.on('changeName', function (newName) {
		console.log("[*changeName]".bold.grey, Monopony.player(socket.id), "-->", newName)
		if (socket.position == "LOBBY" || socket.position == "SP") {
			socket.name = newName
		} else if (rooms[socket.position].setup) {
			socket.name = newName
			Monopony.notifyAllInRoomButSelf(socket, "playerChangedName", socket.id, newName)
		}
	})

	socket.on('chanceAvatar', function (newAvatar) {
		console.log("[*chanceAvatar]".bold.grey, Monopony.player(socket.id), "-->", newAvatar)
		if (socket.position == "LOBBY" || socket.position == "SP") {
			socket.avatar = newAvatar
		} else if (rooms[socket.position].setup) {
			socket.avatar  = newAvatar
			Monopony.notifyAllInRoomButSelf(socket, "playerChangedAvatar", socket.id, newAvatar)
		}
	})

	socket.on('joinRoom', function (reqID, roomID) {
		console.log("[*joinRoom]".grey.bold, Monopony.player(socket.id), Monopony.room(roomID))
		var room = rooms[roomID]
		if (!room) {
			console.log("--> no such room", roomID.red.bold)
			socket.emit("notOk", reqID, "room does not exist")
			return;
		}
		socket.position = roomID
		removeFromArray(lobby, socket)
		room.players.push(socket)
		Monopony.notifyAllInRoomButSelf(socket, "playerJoinedRoom", Monopony.toPlayer(socket))
		//Monopony.notifyAllInRoom(socket, "playerJoinedRoom", socket.id, socket.name, socket.avatar)
		var players = []
		for (var i=0; i<room.players.length; i++) {
			players.push(Monopony.minifyPlayer(room.players[i].id))
		}
		socket.emit("ok", reqID, extend({players: players}, room.options)) // is it good to tell the client ALL the rules? maybe he's not supposed to know... meh
	})

	socket.on('createRoom', function (reqID, options) {
		console.log("[*createRoom]".bold.grey, Monopony.player(socket.id), options.name, options)
		var roomID = Monopony.generateID(rooms)
		if (!options.name)
			options.name = roomID

		rooms[roomID] = {
			id: roomID,
			name: options.name,
			setup: true,
			players: [socket],
			currentPlayer: null,
			creator: socket.id,

			options: {
				startBits: +options.startBits || 1500
				// maxPlayers, allowBots, allowSpectators, extraRules={},
			}
		}
		socket.position = roomID
		removeFromArray(lobby, socket)

		Monopony.notifyAllInLobby("roomOpened", roomID, options.name)
		socket.emit("ok", reqID, roomID)
	})

	socket.on('startGame', function () {
		console.log("[*startGame]".bold.grey, Monopony.player(socket.id))
		var room = rooms[socket.position]
		if (room.creator == socket.id) {
			room.setup = false
			Monopony.notifyAllInRoom(socket, "gameStarted", socket.position)
			Monopony.notifyAllInLobby("gameStarted", socket.position)
		} else {
			console.log("\tperson requesting is not the host".yellow.bold)
		}
	})

	socket.on('kick', function (playerID, reason) {
		console.log("[*kick]".red.bold, Monopony.player(socket.id), "-->", Monopony.player(playerID), "("+reason+")")
		var room = rooms[socket.position]

		if (!players[playerID].position == room.id)
			return socket.emit("chat", "[SYSTEM] there is no player with this ID in the room")

		if (room.creator == socket.id) {
			players[playerID].emit("kicked", reason)
			if (reason)
				reason = " ("+reason+")"
			else
				reason = ""
			Monopony.leaveRoom(players[playerID], "kicked"+reason)
			//socket.emit("ok")
		} else {
			socket.emit("chat", "[SYSTEM] only the host can kick other players.")
			console.log("\tperson requesting is not the host".yellow.bold)
		}
	})
	socket.on('updateOptions', function (options) {
		console.log("[*updateOptions]".grey.bold, options)
		var room = rooms[socket.position]

		if (room.creator == socket.id) {
			Monopony.notifyAllInRoom(room, "updateOptions", options)
		} else {
			socket.emit("chat", "[SYSTEM] only the host can change the options, ask him/her to do it.")
			console.log("\tperson requesting is not the host".yellow.bold)
		}
	})


	socket.on('button', function (reqNum, btn) {
		console.log("[*button]".bold.grey, Monopony.player(socket.id), "("+reqNum+")", btn)
		var room = rooms[socket.position]
		//if (room.players.indexOf(socket) == room.currentPlayer)
		if (room.creator == socket.id)
			Monopony.notifyAllInRoom(socket, "button", reqNum, btn)
		else
			io.sockets.sockets[room.creator].emit("buttonCheck", reqNum, btn, socket.id)
	})



	socket.on('request_dice', function (reqNum) {
		console.log("[request_dice]".bold.grey, "("+reqNum+")", Monopony.player(socket.id))
		Monopony.notifyAllInRoom( socket, "dice", reqNum, Math.ceil(Math.random()*6), Math.ceil(Math.random()*6) )
	})


	socket.emit("ok", 0, socket.id)
})






console.log("running on port "+PORT)
// get IP
var data=""
var request = http.request(
	{
		hostname: 'jsonip.appspot.com',
		port: 80,
		path: '/',
		method: 'POST'
	}, function(response){
		response.on('data', function(chunk){
			data += chunk
		})
		response.on('end', function(chunk){
			data += chunk
			IP = /(?:\d|\.)+/.exec(data)[0]
			console.log("address: http://"+IP+":"+PORT)

			console.log()
			require("./CLI_debug.js")
		})
		response.on('error', function() {
			console.log("[Error] receiving IP. Maybe you are not connected to the internet?\n".bold.red)
			require("./CLI_debug.js")
		})
	}
)
request.on('error', function(e) {})
request.end()
