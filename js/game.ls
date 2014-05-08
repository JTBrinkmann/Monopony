/*!
Author: J.-T.Brinkmann (aka. Brinkie Pie)
last-modified: 2013-11-04
source-file: http://brink.peder.us/Monopony/js/game.ls
all rights reserved, you may not modify or distribute this file or any fily associated with it by J.-T. Brinkmann (Brinkie Pie) without written permission
*/
/*
== StyleGuide (for text visible to the user) ==
you:
	* Always prefer using a player's name instead of "you"!
	 exceptions are:
		* if you are talking to the PERSON who is using Monopony (not a specific player). e.g. in forceDice()
		* if it's a text that get's shown only to the specific player's client (board.msgBox, cards, …)
	* don't surround players' names in quotes
plural:
	* always take care to pluralize unknown amounts of something properly.
	  e.g. board.log "This field costs #{plural field.price 'bit'}."
		so in case of the price being 1, it evaluates to "This field costs 1 bit."
	  note: this is useful for i18n too, because some languages have multiple pluralization forms.
numbers:
	* always use "#{number 123}" when showing numbers in a text. This will format the number depending on the user's locale.
	  e.g. in German one thousand dollar, 23 cents are displayed as "$1.000,23" where as in english it's "$1,000.23"
dates:
	* same as with numbers
	  note: if the client doesn't have Intl support, it will fall back to YYYY-MM-DD because that is the least confusing format
	  (given that both MM/DD/YYYY and DD/MM/YYYY are common)
buttons:
	* the text of buttons should be capitalized in a movie title fashion.
	  e.g. "Roll the Dice"

etc:
	* "The Moon" is to be capialized, because in the context of this game, it is a place's name, not only an astonomical objct
	* write "Return-From-the-Moon card(s)" as such (except when in a button's text, then capitalise "Card" as well)
*/


#== Bootstrapper ==
var Monopony
var board
var player, forceDice, forceCard, showAllCards, clickBtn, checkUnusedPrototypeAttrs
<- (do) # wrapper

#== AUXILIARIES ==
debugLog = (...args) ->
	console.log "DEBUG:: #{[].join.call args}\n#{new Error!.stack}"
	if board.socket
		board.socket.emit \debugLog
	#ToDo add some socket.emit stuff

var requestAnimationFrame, sleep, clone, setLanguage, language, number, date, strCompare_i, xth, plural, list, capitalize, MicroEvent, isNum, randomNum, throttle, safeToString, icedCoffee
#if true
let $span = $ \<span>
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

	NBSP = "\xa0"

	# polyfill ECMAScript5 functions
	if !String::strip
		String::define \strip, -> return $.trim it
	if !Function::bind
		Function::bind ?= (context) ->
			fn = this
			return ->
				fn.apply context, arguments
	if !Array::filter
		Array::define \filter, (fn) ->
			return $.grep this, fn
	if !window.requestAnimationFrame
		requestAnimationFrame :=
			window.webkitRequestAnimationFrame
			|| window.mozRequestAnimationFrame
			|| let timeOut = 1_000ms / 60fps
				(callback) ->
					window.setTimeout callback, timeOut

	# note: IE 5 and less are not supported
	# ie := +((navigator.appName == 'Microsoft Internet Explorer') && /MSIE ([0-9]+)/.exec navigator.userAgent ? .1)

	# setTimeout with swapped parameters. why? because it's stylish
	sleep := (time, callback) ->
		setTimeout callback, time

	# clone operator (fix Arrays)
	clone := (obj) ->
		if $.isArray obj
			if obj.length
				return [] <<<< obj # note, the ^^ cloning operator is buggy with Arrays
			else
				return []
		else
			return ^^obj

	#==  LOCALISATION ==
	# see https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Intl
	setLanguage := (lang) -> # lang can be one or more BCP 47 language tags
		language := lang
		if "Intl" of window
			number := new Intl.NumberFormat lang .format
			date := new Intl.DateTimeFormat lang .format
			strCompare_i := (str1, str2) ->
					return 0 == new Intl.Collator lang, {usage: "search", sensitivity: "base"} .compare str1, str2
		else
			number := let thousandMark=".", decimalPoint="."
				(num) ->
					return "#{'0' * (3 - num % 3)}#{num}"
						.replace /(\d\d\d)/g, "#{thousandMark}$1" # thousand marker
						.replace /^[0\.]+/, ""
			date := (date) ->
				return "#{date.getFullYear!}-#{date.getMonth!}-#{date.getDate!}"
			strCompare_i := (str1, str2) ->
				return str1 == str2

		#ToDo: add other languages
		xth := (i) ->
			return i+(if i==1 then "st" else if i==2 then "nd" else if i==3 then "rd" else "th")

		plural := (num, singular, plural=singular+'s') ->
			# for further functionality, see
			# * http://unicode.org/repos/cldr-tmp/trunk/diff/supplemental/language_plural_rules.html
			# * http://www.unicode.org/cldr/charts/latest/supplemental/language_plural_rules.html
			# * https://developer.mozilla.org/en-US/docs/Localization_and_Plurals
			if num == 1 # note: 0 will cause an s at the end, too
				return "#{number num}#{NBSP}#singular"
			else
				return "#{number num}#{NBSP}#{plural}"

		list := (elements) ->
			if elements.length > 1
				elements[*-2] += " and#{NBSP}#{elements.pop!}"
			return elements.join ", "

	capitalize := (str) ->
		return str.replace(/\b\a/, (letter) -> letter.toUpperCase!)

	/*
		gender := (player, strMale, strFemale) ->
			if player.gender == \female
				return strFemale
			else
				return strMale
	*/


	#== extending/fixing jQuery ==
	$.fn.visible = ->
		if this.length == 0
			return
		else if this.length > 1
			return this.first!.visible!

		el = this
		while el.length
			if (el.css \display) == \none || (el.css \visibility) == \hidden || (el.css \opacity) == 0 
				return false
			el = el.parent!
	$.fn.hidden = ->
		return not this.visible!
	#== fix $.fn.text to support linebreaks ==
	$.fn.text_fixed_br = (text) ->
		@html ($span.text text) .html!.replace(/\n/g, "<br>")

	#onChangeStr := "input propertychange" #"keyup input change"
	$.fn.input = let events = (if $span.0.oninput? then "propertychange keyup change" else "input")
		(eventData, handler) ->
			$this = $ this
			if &length > 0
				if typeof eventData == \function && not handler?
					handler = eventData
					eventData = void
				lastValue = @val!
				@on events/*, null, eventData*/
					,->
						$this = $ this
						val = $this.val!
						if lastValue != val
							lastValue = val
							handler ...
			else
				@trigger name

	#= Easing =
	$.easing.easeInQuad := (p) ->
		return p ^ 2

	$.easing.easeOutQuad := (p) ->
		return 1-(1-p)^2

	# MicroEvent (+ .once)
	MicroEvent := class MicroEvent_
		bind: (e, handler) ->
			@{}_events.[][e].push handler

		unbind: (e, handler) ->
			if e of @{}_events
				@_events[e].splice @_events[e].indexOf(handler), 1

		once: (e, handler) ->
			emitter = this
			handler.once = true
			@bind e, handler

		trigger: (e, ...data) ->
			return if e not of @_events

			oneTimeHandlers = []
			#for (i$=0; i$ < @_events[e].length; i$++)
			for handler in @_events[e]
				#note: using i$ to force-enable mutating it (otherwise LiveScript creates a shadow, so i-- will not cause the loop to re-iterate)
				handler = @_events[e][i$]
				handler.apply this, data
				if handler.once
					oneTimeHandlers ++= handler

			for handler in oneTimeHandlers
				@unbind e, handler

		@mixin = (dest) ->
			dest ::= prototype


	#== Math helpers ==
	isNum := -> !isNaN it
	randomNum := (max) ->
		return Math.floor Math.random! * max

	throttle := let fnToString = Function.prototype.toString
		(timeout, fn) ->
			throtte = &callee
			return ->
				fnStr = fnToString.apply fn
				i = throttle.keys.indexOf fnStr
				if i == -1
					i = throttle.keys.length
					throttle.keys.push fnStr

				clearTimeout throttle.timeouts[i]
				throttle.timeouts[i] = setTimeout fn.bind this, timeout
		<<<<
			keys: []
			timeouts: []

	# timeout Deferreds
	# (set to Object prototype because jQuery doesn't use prototypes for Deferreds <_<)
	Object::define \timeoutDeferred, (time, fn) ->
		if \always not of this
			throw TypeError "timeoutDeferred can only be called on Deferreds!"

		if typeof time == \function
			fn = time
			time = 1_000ms

		timeout = setTimeout fn, time
		@always ->
			clearTimeout timeout

		return this

	#== String auxiliaries ==
	safeToString := let fnToString = Function.prototype.toString, objToString = Object.prototype.toString
		->
			if typeof it == \function
				return fnToString.apply it
			else if typeof it == \object
				return objToString.apply it
			else if typeof it in <[ string number boolean ]>
				return it+''
			return ''


	#== Object auxiliaries ==
	Object::define \isEmptyObject, ->
		for a of this
			return false
		return true

	#== Array auxiliaries ==
	if \filter not of Array::
		Array::define \filter, (fn, thisArg) ->
			res = []
			return [
				for item, i in this
					if fn.call thisArg, item, i, this
						item
			]
	Array::define \contains, ->
		return @indexOf(it) != -1
	Array::define \remove, ->
		index = @indexOf it
		if index != -1
			return @splice index, 1
	Array::define \removeItem, ->
		return @remove it
	Array::define \sans, ->
		index = @indexOf it
		if index != -1
			return (@slice 0, index) ++ (@slice index + 1)
		else
			return this

	# @FROM http://jsperf.com/shuffle110609
	# NOTE: this alternes the original array!
	Array::define \shuffle, ->
		m = @length

		# While there remain elements to shuffle…
		while m
			i = randomNum m
			t = @[--m]
			@[m] = @[i]
			@[i] = t

		return this


	Array::define \random, ->
		return this[Math.floor Math.random!*@length]

	Array::define \randomUnused, (used, attrKey) ->
		possibleValues = []<<<<this # `^^this` would be more appropriate, but is buggy with Arrays
		for usedObj in used
			#if usedObj[attrKey] in possibleValues # included in .remove
			possibleValues.removeItem usedObj[attrKey]

		if possibleValues.length == 0
			return null
		else
			return possibleValues.random!


	#== icedCoffee ==
	# easy await-deferred implementation inspired by IcedCoffeeScript
	# use with loops (use for-loops with the `let` keyword) with `(defer) <- await` before the main loop-body
	/* e.g.:
			<- icedCoffee (await) ->
				for let otherPlayer in board.players
					if otherPlayer != player
						(defer) <- await
						player.giveBitsTo otherPlayer, 10bits, defer
			# finally
			board.endTurn!
		or
			<- icedCoffee (await) ->
				if !player.creditor # creditor is the Bank
					for let otherField in transferredFields
						(defer) <- await
						otherField.auction defer
			# finally
			board.endTurn!
	*/
	# note the two arrows!
	icedCoffee := (loopFn, finallyFn) ->
		i = 0
		callbacks = []
		res = []

		await = (cb) ->
			callbacks ++= cb

		defer = (...args) ->
				if args.length > 1
					res[i] = args
				else
					res[i] = args.0

				i++
				if i < callbacks.length
					callbacks[i]? defer
				else
					finallyFn res

		# generate callbacks
		loopFn await

		# run first callback
		if callbacks.length
			callbacks.0 defer
		else
			finallyFn []


#== GAME ==
setLanguage \en-US

Monopony := class Board implements MicroEvent::
	(boardDiv, players=[]) !~>
		if !boardDiv
			throw new TypeError "missing arguments"

		board = this

		# fix arrays and objects in the prototype (I don't even…)
		for i,attr of board when typeof attr == \object && attr?
			board[i] = clone attr



		# set up HTML
		board.boardDiv = boardDiv

		board <<<< {[k, board.boardDiv.find v] for k,v of do
			newPlayerDiv: \.statusBar-newPlayer
			ownershipTokenContainer: \.ownershipToken-container
			statusBar: \.statusBar
			buttonsText: \.buttons-text
			buttonsField: \.buttons
			inputFieldError: \.input-error-text
			avatarPicker: \.avatarPicker
			avatarPickerTitle: \.avatarPicker-title
			avatarPickerImgWrapper: \.avatarPicker-img-wrapper
			# avatarPickerImg: \.avatarPicker-img # empty
			avatarPickerCustomBtn: \.avatarPicker-custom-btn
			avatarPickerCustomInput: \.avatarPicker-custom-input
			consoleWrapper: \.console-wrapper
			console: \.console
			coins: \.coin
			card: \.card
			cardTitle: \.card-title
			cardImage: \.card-image
			cardText: \.card-text
			cardButton: \.card-button
			floatingCard: \.mini-card-floating
			cloakDivs: \.cloak
			#inputFieldWrapper: \.inputField-wrapper
			#inputField: \.inputField
			#inputFieldError: \.inputField-error-message
			#inputFieldButtonsWrapper: \.inputField-buttons-wrapper
			businessMenu: \.business-menu
		} # /obj-comprehension
		board.avatarPickerImg = $!

		board.boardDiv.addClass \setup

		# set field._board property
		for field in board.fields
			field._board = board

		# set up players
		for player in players || []
			board.addPlayer player

		# if there is still no player (manely because nopony was passed as an argument)
		if !board.players.length
			board.addPlayer!

		if board.players.length <= 2
			board.boardDiv.addClass \two-players

		# set up card decks
		board.shuffleDeck \chance
		board.shuffleDeck \communityChest


		# UI - bind events
		#board.cardButton.click ->
		#	board.cardButtonCallback!
		#- StatusBar -
		board.newPlayerDiv.click ->
			if board.setup
				board.boardDiv.removeClass \two-players

				board.addPlayer!
					.statusName.select!
				if board.players.length >= 6
					board.statusBar.stop!.animate do
						scrollTop: 80px*board.players.length/2 - 160px
						,200ms

		#= AvatarPicker =
		_ = @avatarPickerCache
		board.avatarPicker
			.click ->
				if _.cancelAvatarPicker
					# cancel avatar picker
					board.hideAvatarPicker!
				else
					_.cancelAvatarPicker = true

		board.avatarPickerCustomInput
			.click ->
				_.cancelAvatarPicker = false
			.input throttle 500ms, ->
				avatar = board.avatarPickerCustomInput.val!
				if avatar in Monopony.customAvatars
					url = Monopony.getAvatarUrl avatar
					customAvatar = true
				else
					# <a> to automatically parse the url
					{href: url, host} = $ \<a>
						.prop \href, avatar
						.0

				if customAvatar || host != location.host
					board.avatarPickerCustomInput .removeClass \input-incorrect
					board.avatarPickerCustomBtn
						.prop \disabled, true
						.text "loading"
					_.newAvatar.remove!
					_.newAvatar = $ \<img>
						.prop \src, url
						.load ->
							board.avatarPickerImg.remove!
							board.avatarPickerImg = _.newAvatar
								.addClass \avatar
							board.avatarPickerCustomBtn
								.prop \disabled, false
								.text "Apply"
							_.newAvatar = $!
						.appendTo board.avatarPickerImgWrapper
				else
					board.avatarPickerCustomInput .addClass \input-incorrect
					console.warn "[invalid avatar]", host, url

		board.avatarPickerCustomBtn.click ->
			_.cancelAvatarPicker = false
			if not board.avatarPicker.hasClass \customAvatar
				board.avatarPicker .addClass \customAvatar
				board.avatarPickerCustomBtn .prop \disabled, true
				board.avatarPickerCustomBtn .text "Apply"
				board.avatarPickerCustomInput .focus!
			else
				url = board.avatarPickerCustomInput.val!
				if url in Monopony.customAvatars
					url = Monopony.getAvatarUrl url
				else
					url = board.avatarPickerCustomInput.val!
				_.player.changeAvatar url, true
				board.hideAvatarPicker!

		#- name datalist -
		if !Monopony.nameDatalist
			Monopony.nameDatalist = true
			dl = $ \<datalist>
			dl.prop \id, \monopony_names_datalist
			for name in Monopony.defaultNames
				dl.append do
					$ \<option> .val name
			dl.appendTo \body

		#- FieldMenu -
		$ \body
			.bind \mouseup, (e) ->
				Monopony.FieldMenu.mouseup board, e
			.bind \mousemove, (e) ->
				Monopony.FieldMenu.mousemove board, e

		board.reconnect!
		#board.startGame!

	#= attributes =
	setup: true
	players: []
	bankruptPlayers: []
	currentPlayer: null
	currentPlayerNum: 0
	chanceCards: []
	communityChestCards: []
	currentDice: []
	gameEnded: false
	fields: []
	fieldGroups: {}
	businessMenus: {}
	slidin: null
	sliderFieldMap: {}
	highlightedPlayer: null
	avatarPickerCache: {}

	#= settings =
	animationspeed: 150ms
	bailout: 50bits
	startBits: 1_500bits # default amount if not passed to constructor

	#= html =
	boardDiv: null
	newPlayerDiv: null
	ownershipTokenContainer: null
	statusBar: null
	buttonsText: null
	buttonsField: null
	consoleWrapper: null
	console: null
	coins: null
	card: null
	cardTitle: null
	cardImage: null
	cardText: null
	cardButton: null
	cardButtonCallback: ->
	floatingCard: null
	#msgBox: null
	#inputFieldWrapper: null
	#inputField: null
	#inputFieldError: null
	#inputFieldButtonsWrapper: null
	businessMenu: null
	avatarPickerCache: {}

	scale: 1x
	rotation: 0deg

	#= multiplayer =
	isConnected: false
	multiplayer: false
	multiplayerDeferred: null
	socket: null
	room: null
	rooms: {}
	isHost: false
	multiplayerCallback: null
	reqs: {}
	reqNum: 0
	multiplayerStack: {}



	#= meta functions =
	startMenu: (dontClearConsole) ->
		board = this

		if !dontClearConsole
			board.console.html ""

		board.log "Please choose your name." # and avatar

		board.buttons "Please select a Gamemode", do
			"SinglePlayer": ->
				$ \body .animate do
					scrollTop: $ \#game .offset!.top
					,'slow'
				board.addPlayer!
				board.newPlayerDiv.fadeIn!
				board.players[board.players.length-1].statusName.select!

				board.buttons "Start Game": ->
						board.startGame!

			"Test Multiplayer": -> # Test Multiplayer #debug remove btn==1
				$ \body .animate do
					scrollTop: $ \#game .offset!.top
					,'slow'
				board.initMultiplayer!
					.timeoutDeferred 500ms, ->
						board.log "loading..."
					.then (socket, emit) ->
						board.gotoLobby!
					.fail (err) ->
						board.log "An error occured while trying to connect to the multiplayer server."
						board.log "Maybe the server is down?"
						board.log "\n===================\n"
						board.startMenu true
			"#{window.debug.title}": window.debug.fn

	startGame: ->
		board = this

		# check for errorneous player names
		errors = board.checkForErrorneousNames!
		if errors
			if errors.length > 1
				errorTxt = "some Errors occured:\n#{list errors}"
			else
				errorTxt = errors.0

			board.msgBox errorTxt
			board.buttons errorTxt, do
				"Start Game": ->
						board.startGame!
			return


		# prepare game
		for player in board.players
			player.bits = board.startBits
			if board.setup && !player.remote
				#player = player.statusName.val!
				player.statusName.remove!
				player.statusName = $ \<div>
					.addClass \statusBar-playerName
					.text player.name
					.insertBefore player.statusBits

			player.status.removeClass \active

		board.currentPlayer = board.players.0
		board.currentPlayer.status.addClass \active

		board.setup = false
		board.boardDiv.removeClass \setup
		board.newPlayerDiv.fadeOut!

		# start game
		board.trigger \newGame, board
		board.startTurn!
		board.update!

	update: ->
		board = this
		#scale = board.scale
		#board.statusCurrentPlayer.text(board.currentPlayer.name)
		for player in board.players
			#board.players[i].draw!

			player.statusBits.text "#{plural player.bits, 'bit'}"
			player.statusLocation.text "(#{board.fields[player.position].name})"

	cleanUp: ->
		board = this

		board.gameEnded = false

		#board.boardDiv.find ".ownershipToken-wrapper"
		#	.remove!*

		for field in board.fields
			field.cleanUp!

		playerHelper = board.players ++ board.bankruptPlayers
		board.players = []
		for nameSpan in board.boardDiv.find \.statusBar-playerName
			for player in playerHelper
				if player.name == $ nameSpan .text()
					board.players ++= player
					break

		for player in board.players
			player.cleanUp!

		board.update!

	gameEnd: ->
		player = board.players.0

		board.gameEnded = true
		board.msgBox """
			#{player.name} WON THE GAME!
		"""

		#ToDo fancy animation
		<- board.buttons "Back to Start Menu"
		board.startMenu!

	checkForErrorneousNames: (player) ->
		board = this

		playersWithSameName = []
		playersWithErrorneousName = []
		errors = {short: [], long: []}
		takenNames = board.players.map (.name)

		if player
			players = [player]
		else
			players = board.players

		for player in players
			if player.name == ""
				errors.short ++= "Enter a name!"
				errors.long ++= "Please give the #{xth i} player a name!"
			else if (["bank", "the bank", "(the) bank"].filter (b) -> strCompare_i b, player.name).length != 0
				errors.short ++= "Disallowed name!"
				errors.long ++= "The #{xth i} player may not be named '(The) Bank'!"
			#else if player.name in takenNames
			else if player.name.length >= 15
				errors.short ++= "Name too long!"
				errors.long ++= "#{player.name}'s name is too long. Only 14 characters are allowed."
			else if (takenNames.filter (otherName) -> strCompare_i otherName, player.name).length > 1
				playersWithSameName ++= player
			else
				continue

			player.status .addClass \error
			playersWithErrorneousName ++= player

		if playersWithSameName.length
			for let player in playersWithSameName
				player.statusName .one \change, ->
					for otherPlayer in playersWithSameName
						otherPlayer.status.removeClass \error

			errors.short ++= "Not a unique name!"
			errors.long ++= """
				There are some players with the name #{list playersWithSameName.map -> '"' + it.name + '"'}.
				Each player has to have a unique name!
			""" # well, not necessarily... but avoiding confusion sounds like a good thing to do

		if errors.short.length
			for let player in playersWithErrorneousName
				player.status .addClass \error
				player.statusName .one \change, ->
						player.status.removeClass \error

			if player
				return errors.short
			else
				return errors.long
		else
			return false



	#= setup functions =
	addPlayer: (options, /* optional */ avatar) ->
		board = this

		if typeof options == \string
			options =
				name: options
				avatar: avatar

		player = new Monopony.Player this, options

		board.players.push player
		return player

	removePlayer: (player, noAnimation) ->
		board = this

		board.players.splice board.players.indexOf player, 1
		player.status.fadeOut (if noAnimation then 0 else \slow), ->
			player.image.remove!
			player.status.remove!

		if board.players.length <= 2 && !board.multiplayer
			board.boardDiv.addClass \two-players

	applyOptions: (options) ->
		board = this

		if options.startBits
			board.startBits = options.startBits


	#= game functions =
	nextPlayer: ->
		board = this
		player = board.players[board.currentPlayerNum]
		# note: player refers to the player who is about to END his/her round


		board.currentPlayerNum = (board.currentPlayerNum + 1) % board.players.length
		player = board.currentPlayer = board.players[board.currentPlayerNum]
		# note: from here on, `player` refers to the player who is about to BEGIN his/her round

		player.status.addClass \active

		board.statusBar.stop!.animate do
			scrollTop: 80px*board.currentPlayerNum/2 - 160px # player.status.position!.top
			,200ms

		board.log """
			=============
			Now it's #{player.name}'s turn.
		"""

		board.trigger \nextTurn, board, player
		board.startTurn!

	startTurn: (autoRollDice) ->
		board = this
		player = @currentPlayer

		board.update!

		if board.gameEnded
			return

		if player.isParking
			player.isParking = false
			board.log "#{player.name} is still parking."

			return board.endTurn!


		else if player.isOnTheMoon
			hasCard = if player.returnFromTheMoonCards > 0 then "" else "#"

			return board.buttons do
				"Try to roll doubles": ->
					player.rollDice (board, die) ->
						board.log "#{player.name} rolled #{die.0} and #{die.1}"
						if die.0 == die.1
							board.log "#{player.name} comes back from the moon and moves #{die.sum} fields."
							player.isOnTheMoon = 0
							<- board.buttons "Move #{plural die.sum, 'field'}"
							board.log "#{player.name} moved #{plural die.sum, 'field'}."
							# note: The power of rolling doubles has been used up to free from jail, so the player may not roll again
							player.move die.sum
						else if player.isOnTheMoon++ == 3 #note: player.isOnTheMoon gets coerced from boolean to number if necessary
							board.log "#{player.name} is charged with #{plural board.bailout, 'bit'}."
							<- board.buttons "Pay #{plural board.bailout, 'bit'}."
							<- player.pay board.bailout
							board.log "#{player.name} pays the bailout of #{plural board.bailout, 'bit'} and comes back from the moon"
							player.isOnTheMoon = 0
							board.endTurn!
						else
							#<- board.buttons "Continue"
							board.endTurn!

				"Pay #{plural board.bailout, 'bit'} Bailout": ->
					board.log "#{player.name} pays the bailout of #{plural board.bailout, 'bit'} and comes back from the moon"
					<- player.pay board.bailout
					player.isOnTheMoon = 0
					board.endTurn!


				"#hasCard Use Return-From-the-Moon Card": ->
					board.log "#{player.name} used a Return-From-the-Moon card to come back from the moon"
					player.returnFromTheMoonCards--
					player.isOnTheMoon = 0
					board.startTurn!

			#board.log "Celestia allows #{board.currentPlayer.name} to come back from the moon"

		helper = ->
			(,dice) <- player.rollDice
			board.currentDice = dice
			board.log "#{player.name} rolled a #{number dice.0} and a #{number dice.1}"

			if dice.0 == dice.1
				player.doubles++
			else
				player.doubles = 0

			#ToDo: [fix] on the third consecutive double, the player could collect the 200 bits from GO first, and THEN go to jail
			if player.doubles == 3
				#ToDo: that sounds stupid… but kinda funny
				board.log "#{player.name} rolled three consecutive doubles. Due to breaking Monopony law, #{player.name} has to go to jail."
				player.doubles = 0
				<- player.buttons "Go to Jail"
				player.toTheMoon!
				board.endTurn!
			else
				<- player.move dice.0 + dice.1
				player.processField!

		if autoRollDice
			helper!
		else
			player.buttons "Roll the Dice", helper

	endTurn: ->
		board = this
		player = @currentPlayer


		if board.gameEnded
			board.buttons "Back to Start Menu", ->
				board.cleanUp!
				board.startMenu!
		else if player.lost
			board.nextPlayer!
		else
			if player.doubles # note: going to jail after rolling doubles 3 times is handled in Player::startTurn()
				board.log """
					=============
					#{player.name} rolled doubles and thus may roll again.
				"""
				player.buttons do
					"Roll Dice Again": ->
						board.startTurn true
					"Business": -> #ToDo choose a better name for this >.<
						board.openBusinessMenu!

			else
				player.buttons do
					"End Turn": ->
						# remove .active class from the CURRENT player (the one that just ended his/her round)
						board.socket.emit \endTurn
						player.status.removeClass \active
						board.nextPlayer!
					"Business": -> #ToDo choose a better name for this >.<
						board.openBusinessMenu!

	#= BusinessMenu & Auctioning =
	openBusinessMenu: (player /*=board.currentPlayer*/, /*for repaying debt:*/ callback=&0 || -> ) ->
		#ToDo add support for multiplayer
		Monopony = @@
		board = this

		if !player || player not in board.players
			player = board.currentPlayer


		#ToDo the UI needs a huge work-over
		# * cloak the board except where there are fields owned by the player
		# * proper slider etc
		<- sleep 1 # to fix the click event being immediately being triggered #ToDo


		# check if any player holds cards (in vanilla only Return-From-the-Moon card are holdable)
		if board.players.filter (.returnFromTheMoonCards) .length
			btnTradeCards = ""
		else
			btnTradeCards = \#

		# The case of no fields being trade-able is negletable
		canceled = false
		fieldSelCallback = (e) ->
			return if canceled
			canceled := true

			field = board.getFieldByPos e, true

			if !field || !field.buyable
				if not $ e.target .is \button
					#ToDo: use .unbind instead of the `cancel` variable
					#	instead of re-showing the menu, simply ignore clicking anywhere but on a field/button
					board.hideBusinessMenu!
					board.openBusinessMenu player, callback
				return



			# show info for whole group (even if owned by other players)
			field.reveal!

			# if field.owner != player
			#	board.msgBox "You don't own this field!"

			otherFields = [] <<<< board.fieldGroups[field.group] # no ^^ here because of bugs when cloning Arrays

			# if field is on the bottom or left
			if field.index < board.fields.length
				# reverse order, so that the menus for the fields ordered intuitively
				# i.e. those for the fields to the left/top are shown first
				otherFields .= reverse!

			board.businessMenu.show!
			for otherField in otherFields
				board.businessMenus[otherField.index] = new Monopony.FieldMenu otherField, player, (otherField == field)


			board.buttons "Back", ->
				board.reloadBusinessMenu!

			return


		btnRepayDebt = \#
		btnGiveUp = \#
		btnBack = \#
		if player.owes
			#note: watch out that if the bank is the creditor, creditor is null.
			#	be careful no to crash the game when accessing properties or passing it as to other functions
			if typeof callback != \function
				callback = ->
					board.endTurn!

			# aliases
			debtor = player
			creditor = debtor.creditor
			bank = creditor == null # whether creditor is the bank or not


			if debtor.bits >= debtor.owes
				btnRepayDebt = ""
			else
				btnGiveUp = ""
		else
			btnBack = ""

		board.buttons "click on the field you want to work with", do
			$always: ->
				board.boardDiv.unbind \click, fieldSelCallback
				canceled := true

			"#btnRepayDebt Repay Debt": ->
				if bank
					board.log "#{debtor.name} pays the Bank #{plural debtor.owes, 'bit'}"
					board.uncloak!
					<- debtor.pay debtor.owes
					debtor.owes = 0
					callback!
				else
					board.log "#{debtor.name} pays #{creditor.name} #{plural debtor.owes, 'bit'}"
					board.uncloak!
					<- debtor.giveBitsTo creditor, debtor.owes
					debtor.owes = 0
					debtor.creditor = null
					callback!

			"#btnGiveUp Give Everything to Creditor": ->
				board.uncloak!
				# monkey patching to not show a message each time a house is sold
				log_ = board.log
				ui_ = board.ui
				board.log = board.ui = ->

				# autosell properties to creditor
				transferredFields = []
				for otherField in board.fields
					if otherField.owner == debtor
						if !otherField.utility && field.houses > 0
							field.setHouses 0

						transferredFields ++= field

				if !bank # creditor is a player
					for otherField in transferredFields
						#ToDo: should the creditor pay 10% to The Bank if the field is mortgaged?
						field.changeOwner creditor

				# reversing monkey patches
				board.log = log_
				board.ui = ui_

				# give bits to creditor
				if creditor && debtor.bits
					board.log "#{debtor.name} gives #{plural debtor.bits, 'bit'} and #{list transferredFields.map (.name)} to #{creditor.name}"
					debtor.giveBitsTo creditor, debtor.bits
				else
					board.log "#{debtor.name} gives #{plural debtor.bits, 'bit'} and #{list transferredFields.map (.name)} to the Bank"
					debtor.pay debtor.bits

				# gameover for debtor
				<- debtor.gameover!

				# if game didn't end (there are players left)
				<- icedCoffee (await) ->
					if bank # creditor is the Bank
						for let otherField in transferredFields
							(defer) <- await
							console.log "field", otherField
							pos = otherField.getPos!
							board.cloak pos.0, pos.1, pos.2, pos.3
							board.buttons "The Bank auctions #{otherField.name}", "Continue"
							board.auctionField otherField, defer

				board.uncloak!
				board.update!
				callback!

			"#btnTradeCards Trade Cards": ->
				do helperSelPlayer = ->
					(otherPlayer) <- board.selectPlayerForTrade player

					if otherPlayer.returnFromTheMoonCards
						btnBuyCards = ""
					else
						btnBuyCards = \%

					if player.returnFromTheMoonCards
						btnSellCards = ""
					else
						btnSellCards = \%

					board.buttons do
						"#btnBuyCards Buy Cards": ->
							<- board.tradeCard otherPlayer, player, false
							board.reloadBusinessMenu!
						"#btnSellCards Sell Cards": ->
							<- board.tradeCard player, otherPlayer, false
							board.reloadBusinessMenu!
						"Back": ->
							helperSelPlayer!

			"#btnBack Back": ->
				board.hideBusinessMenu!
				board.nextPlayer!

		board.boardDiv.one \click, fieldSelCallback
		return

	hideBusinessMenu: ->
		board.uncloak!
		for ,otherMenu of board.businessMenus
			otherMenu.remove?!
		board.businessMenu.hide!
		#board.openBusinessMenu!

	reloadBusinessMenu: ->
		board.hideBusinessMenu!
		board.openBusinessMenu!

	auctionField: (field, callback) ->
		board = this

		callback ?= ->
			board.endTurn!

		# bitting starts
		board.log "#{field.name} is up for auction"
		price = 0bit # 1bit will be added to the next bet
		playerBitmap = {} # a bitmap showing which players cannot bit anymore
		playerBitmapLength = board.players.length # amount of players who still can bid


		#ToDo make this multiplayer compatible
		#ToDo add player.input( type, buttons, options{default, validate}, callback(board, player, value, btn) )

		#ToDo: async bidding (in multiplayer, allow all player to bid at the same time)
		len = board.players.length
		i = board.currentPlayerNum
		var bidder
		do helper = ->
			i := (i+1) % len
			bidder := board.players[i]


			if playerBitmapLength <= 1
				alert "auction ended" #DEBUG
				# = bidding ended =
				if price == 0bits # if nopony bid (yet)
					if bidder.bits
						bidder.input \number, ["Buy", "Don't Buy"], do
							text: "#{bidder.name .toUpperCase!}: what do you want to pay for this field?"
							default: 1bit
							validate: (value) ->
								# only bidding higher than the current price is allowed
								if value > player.bits
									return "You don't even have #{plural value, 'bit'}!"
								else if value < 1bit
									return "You have to pay at least #{plural 1, 'bit'}"
								else
									return true

							callback: (board, value, btn) ->
								bidder.unhighlight!
								if btn == 0
									board.log """
										#{bidder.name} won the auction.
										#{bidder.name} pays #{plural value, 'bit'} for #{field.name}.
									"""
									field.buy bidder, value
									callback!
									return

								else # btn == 1
									board.log "The auction ended. Nopony wanted to buy #{field.name}."
									callback!
									return
					else # bidder.bits == 0bits
						board.log """
							#{bidder.name} doesn't have enough bits to buy #{field.name}.
							The auction ended. #{field.name} remains unowned.
						"""
						callback!
						return

				else
					bidder.unhighlight!
					board.log """
						#{bidder.name} won the auction.
						#{bidder.name} pays #{plural price, 'bit'} for #{field.name}.
					"""
					field.buy bidder, price
					callback!
					return


			else if playerBitmap[i]
				board.log "#{bidder.name} may not bid anymore"
				#ToDo make this text more understandable. Players who didn't pay attention should see WHY the bidder may not bid anymore
				# maybe remove this? what if Player A changes his/her mind about whether to bid again or not?
			else if bidder.bits <= price
				board.log "#{bidder.name} has not enough bits to place a bid"
				playerBitmap[i] = true
				playerBitmapLength--
			else
				bidder.highlight!

				bidder.input \number, ["Bid", "Don't Bid"], do
					text: "#{bidder.name .toUpperCase!}: Enter your bid:"
					default: price + 1bit
					validate: (value) ->
						if value > player.bits
							return "You don't even have #{plural value, 'bit'}!"
						else if value <= price
							return "You have to bid higher than #{plural price, 'bit'}!"
						else
							return true

					callback: (board, value, btn) ->
						bidder.unhighlight!
						if btn == 0
							price := value
							board.log "#{bidder.name} bid #{plural price, 'bit'}."

						else # btn == 1
							playerBitmap[i] = true
							playerBitmapLength--
							board.log "#{bidder.name} passes." # is this ok?

						helper!

	#= AvatarPicker =
	showAvatarPicker: (player) ->
		Monopony = @@
		board = this
		_ = @avatarPickerCache

		_.player = player


		#- helper -

		# cancel the avatar picker on click event,
		# unless something else that got clicked sets cancelAvatarPicker to false
		_.cancelAvatarPicker = true

		if !board.setup
			return
		#===================
		#== Avatar Picker ==
		#===================
		_.avatars := $!
		_.newAvatar := $!


		#- show avatar container -
		board.avatarPickerImg = $ \<img>
			.addClass \avatar
		if player.avatarIsCustom
			board.avatarPickerImg .prop \src, player.avatar
		else
			board.avatarPickerImg .prop \src, Monopony.getAvatarUrl player.avatar
		board.avatarPickerImg .appendTo board.avatarPickerImgWrapper

		for let name in Monopony.defaultNames
			_.avatars .= add do
				$ \<figure>
					.addClass \avatarPicker-avatar
					.append do
						$ \<img>
							.addClass \avatar
							.prop \src, Monopony.getAvatarUrl name
					.append do
						$ \<figcaption>
							.text name
					.appendTo board.avatarPicker
					.click ->
						_.cancelAvatarPicker = false
						#- set avatar -
						player.changeAvatar name
						board.hideAvatarPicker!


		board.avatarPicker .fadeIn!

	hideAvatarPicker: ->
		board = this
		_ = @avatarPickerCache

		<- board.avatarPicker .fadeOut!
		_.avatars .remove!
		board.avatarPicker .removeClass \customAvatar
		board.avatarPickerCustomBtn
			.text "Use custom Avatar"
			.prop \disabled, false
		_.newAvatar .remove!
		board.avatarPickerImg .remove!

	#= auxiliaries =
	getFieldByPos: (pos, /*[y],*/ absolute) ->
		Monopony = @@
		board = this

		# parse arguments
		if typeof pos == \object && pos != null
			{x, y} = pos
			{pageX: x, pageY: y} ?= pos
		else if not isNaN &0 and not isNaN &1
			x = &0
			y = &1
			absolute = &2
		else
			throw new TypeError """
				invalid arguments (could not get coordinates)
				arguments can be passed as (x, y) or ({x: x, y: y}) or ({pageX: x, pageY: y, …})
			"""

		# auxilliary constants
		{fieldHeight, fieldWidth, fieldOffset, boardWidth} = Monopony

		# adjust coordinates to relative to the board
		if absolute
			board.boardDiv.offset!
				x -= ..left
				y -= ..top

		console.log "[getFbP]", x, y
		# return null if the coordinates are out of ranges
		if not (0 < x < boardWidth) || not (0 < y < boardWidth)
			return

		# adjust coordinates relative to the board's scale
		x /= board.scale
		y /= board.scale

		if y <= fieldHeight
			if x <= fieldHeight
				# top-left
				f = 20

			else if x >= fieldOffset
				# top-right
				f = 30

			else
				# top
				f = 20  +  Math.ceil (x - fieldHeight) / fieldWidth

		else if y > fieldOffset
			if x <= fieldHeight
				# bottom-left
				f = 10

			else if x >= fieldOffset
				# bottom-right
				f = 0

			else
				# bottom
				f = 0  +  Math.ceil (fieldOffset - x) / fieldWidth

		else if x <= fieldHeight
			# left
			f = 10  +  Math.ceil (fieldOffset - y) / fieldWidth

		else if x >= fieldOffset
			# right
			f = 40  -  Math.ceil (fieldOffset - y) / fieldWidth

		return board.fields[f]

	rollDice: (callback) ->
		board = this
		dice = [Math.ceil(Math.random!*6), Math.ceil(Math.random!*6)]
		dice.sum = dice.0+dice.1
		return callback this, dice

	shuffleDeck: (deck) ->
		# `deck` can either be \chance or \communityChest
		board = this

		board["#{deck}Cards"] = [] <<<< Monopony["#{deck}Cards"] # `^^this` would be more appropriate, but is buggy with Arrays
		board["#{deck}Cards"].shuffle!

	#= debugging auxiliaries (not internally used) =
	getPlayer: (nameOrNumOrPlayer) ->
		board = this

		if board.players.length > +nameOrNumOrPlayer && !isNaN nameOrNumOrPlayer
			return board.players[+nameOrNumOrPlayer]
		else if typeof nameOrNumOrPlayer == \string
			for player in board.players
				if player.name == nameOrNumOrPlayer
					return player
		else if nameOrNumOrPlayer in board.players
			return nameOrNumOrPlayer

	getField: (nameOrNumOrField) ->
		board = this

		if board.fields.length > +nameOrNumOrField && !isNaN nameOrNumOrField
			return board.fields[+nameOrNumOrField]
		else if typeof nameOrNumOrField == \string
			for field in board.fields
				if strCompare_i field.name, $.trim nameOrNumOrField
					return field
		else if nameOrNumOrField in board.fields
			return nameOrNumOrField


	#= UI =
	# shows some buttons under the board
	buttons: (/* [String text,] (String btn, Function fn | Object btns [,Function callback]) */) ->
		board = this

		if typeof &0 == \object
			text = ""
			btns = &0
			callback = &1

		else if typeof &0 == \string && typeof &1 == \string /*&& typeof &2 == \function*/
			text = &0
			btns = {"#{&1}": &2}
			callback = &3

		else if typeof &0 == \string && typeof &1 == \object
			text = &0
			btns = &1
			callback = &2

		else if typeof &0 == \string && typeof &1 == \function
			text = ""
			btns = {"#{&0}": &1}
			callback = &2

		/*! special triggers: (need to be the first char of the btn's key)
			% -> disabled
			# -> hidden
			$ -> special
				$always -> callback that gets called after any button
				$noAnimation -> buttons don't get faded in
				$async?
		*/
		board.buttonsText.text text

		board.buttonsField.find \button
			.remove!

		if !btns
			return

		always = callback || btns.$always
		noAnimation = btns.$noAnimation
		i_ = 0
		for let btn, callback of btns
			i = i_
			if btn.0 in <[ $ # ]>
				return # continue

			if btn.0 == \%
				btnEl = $ \<button>
					.text btn.substring 2
					.attr \disabled, true
			else
				btnEl = $ \<button>
					.text btn
					.click ->
						# index = $(this).index!
						board.buttonsField.html ""
						callback board, btn, i
						always? board, btn, i
			btnEl
				.hide!
				.appendTo board.buttonsField
			if !noAnimation
				btnEl.fadeIn!
			else
				btnEl.show!

			i_++

		board.trigger \buttons

	input: (type, btns, {default:defaultArg, text, validate, callback = ->}) ->
		board = this
		type = safeToString type .trim! .toLowerCase!

		# if type == \button
		#	throw new Error "type 'button' is not allowed for .input; srsly use .buttons() instead <_<"

		if (not) type in <[ text password search email url tel number range date month week time datetime datetime-local color ]>
			throw new Error "unknown type for <input>"

		wasIncorrect = false
		validateWrapper = (input) ->
			if type == \number
				input = +input
				if isNaN input
					return "Please enter a valid number!"
				else if input % 1 /* != 0*/
					board.boardDiv.addClass \input-incorrect
					# assuming number inputs are always for bits (…oh gosh I can see this failing somewhere)
					board.inputFieldError.text "Splitting bits in half is an Equestrian federal crime!"
					# otherwise
					# board.inputFieldError.text "Please enter an integer!"
					isIncorrect = true

			if typeof validation == \string
				board.boardDiv.addClass \input-incorrect
				board.inputFieldError.text validation
				isIncorrect = true
			else if validate? input
				validation = that
				if typeof validation == \string
					board.inputFieldError.text validation || ""
					board.boardDiv.addClass \input-incorrect
					isIncorrect = true
				else if !validation
					board.boardDiv.addClass \input-incorrect
					isIncorrect = true
				else
					board.boardDiv.removeClass \input-incorrect
					isIncorrect = false
			else
				board.boardDiv.removeClass \input-incorrect
				isIncorrect = false

			if !wasIncorrect && isIncorrect
				for $btn in btnsReqVal
					$btn.attr \disabled, true
			else if wasIncorrect && !isIncorrect
				for $btn in btnsReqVal
					$btn.removeAttr \disabled

			wasIncorrect := isIncorrect
			return !isIncorrect


		board.buttonsField.find \button
			.remove!

		board.buttonsText.text text || ""
		board.inputField = $ "<input type='#{type}'>"
			.addClass \inputField
			.val defaultArg
			.input throttle 100, ->
				input = board.inputField.val!
				validateWrapper input
			.appendTo board.buttonsField
		#board.inputField.replaceWith newInputField

		btnsReqVal = []
		for let btnText, btn in btns
			requiresValidity = btnText.charAt(0) == \§
			if requiresValidity
				btnText = btnText.substring 2
			$btn = $ \<button>
				.text btnText
				.click ->
					input = board.inputField.val!
					if type == \number
						input = +input

					if requiresValidity && not validateWrapper input
						board.inputField .trigger \shake
					else
						#board.inputFieldButtonsWrapper.html ""
						#board.boardDiv.removeClass \showInputField
						board.buttonsField.html ""
						callback board, input, btn
				.hide!
				.appendTo board.buttonsField
				.fadeIn!
			if requiresValidity
				btnsReqVal ++= $btn


		board.boardDiv.addClass \showInputField

	selectPlayer: (players=@players, text, callback)->
		board = this

		pos = board.statusBar.offset!
		pos{left, top} -= board.boardDiv.offset!{left, top}
		board.cloak pos.left, pos.top, board.statusBar.width!, board.statusBar.height!


		if players.length == 1
			callback players.0
		else if players.length == 0
			callback false

		canceled = false
		playerSelCallback = (otherPlayer) ->
			return if canceled
			canceled := true

			board.uncloak!
			callback otherPlayer


		board.buttons "Click on the player who you want trade with", do
			"Cancel": ->
				canceled := true
				board.unbind \playerClicked, playerSelCallback

				board.uncloak!
				callback false

		board.once \playerClicked, playerSelCallback

	selectPlayerForTrade: (sellerOrPlayers, callback) ->
		# This is a shorthand for selecting either any player but `sellerOrPlayers` OR any player in `sellerOrPlayers`
		# if selection is canceled, return to businessMenu
		if $.isArray sellerOrPlayers
			players = sellerOrPlayers
		else
			players = board.players.sans sellerOrPlayers

		(otherPlayer) <- board.selectPlayer players, "Click on the player who you want trade with"
		if otherPlayer
			callback otherPlayer
		else
			board.reloadBusinessMenu!



	log: (text, callback, button) ->
		if typeof text != \string
			text = "#text"

		board = this
		board.console
			.append do
				$ \<div>
					.html text.replace(/\n/g, "<br>")

		board.consoleWrapper.stop!.animate do
			scrollTop: board.console.height!
			,1_000ms

		if typeof callback == \function
			callback!

	# shows a message-box on top of the board
	msgBox: (text, callback, /*optional*/ button) ->
		board.log text
		alert text #.replace(/\n/g, "<br>")
		#ToDo


	cloak: (x, y, w, h) ->
		board = this

		boardW = board.boardDiv.width!
		boardH = board.boardDiv.height!
		board.cloakDivs.eq(0).css do
			left: 0
			top: 0
			width: boardW
			height: y

		board.cloakDivs.eq(1).css do
			left: x + w
			top: y
			width: boardW - x
			height: h

		board.cloakDivs.eq(2).css do
			left: 0
			top: y
			width: x
			height: h

		board.cloakDivs.eq(3).css do
			left: 0
			top: y + h
			width: boardW
			height: boardH - y - h

		board.cloakDivs.animate do
			opacity: 1
			,400ms

	uncloak: ->
		board = this

		<- board.cloakDivs.animate do
				opacity: 0
				,400ms
		board.cloakDivs.css do
			top: 0px
			left: 0px
			width: 0px
			height: 0px


	ui: (type /*, options…*/) ->
		board = this
		player = board.currentPlayer

		switch type
		when \drawCard then
			deck = &1
			card = &2

			otherDeck = (if deck == \chance then \communityChest else \chance)

			board.log "#{player.name} drew the card '#{card.title}'."
			board.log card.text

			board.cardTitle.text card.title
			board.cardImage.attr \src, "images/cards/#{card.image}.png"
			board.cardText.text_fixed_br card.text

			board.floatingCard.removeClass "mini-card-#{otherDeck}Card"
				.addClass "mini-card-#{deck}Card"
				.css do
					if deck == \chance then
						left: 542px
					else
						left: 175px

			# animation - card floating away off deck
			board.floatingCard
				.stop!.animate do
					if deck == \chance then
						left: 894px # board.width
					else
						left: -175px # -card.borderBox-width
					,->
						# animation - card with details back into screen
						board.card
							.css do
								if deck == \chance then
									left: 894px # board.width
								else
									left: -230px # -card.borderBox-width
							.stop!.animate do
								left: 332px # center = (board.width - card.borderBox-width) / 2

		when \hideCard then
			deck = &1
			card = &2
			callback = &3

			board.card.stop!.animate do
				left: 894px  # board.width
				,callback

		when \updateCarddeck then
			deck = &1
			#ToDo

		when \bits then
			# `amount` is bitsNew - bitsOld
			#	 i.e. if the player lost bits it's negative; if he got bits, it's positive
			player = &1
			amount = &2
			receiver = &3

			if !amount
				return

			board.update!
			if player.bits > 0
				board.log "#{player.name} now has #{plural player.bits, 'bit'}."
			steps = 1 + Math.floor Math.abs amount/100bits  # 1 coin per 100 bits
			helper = (offset, amount, start_index) ->
				for let i from start_index to start_index + steps
					coin = board.coins.eq(i)
					if !coin
						coin = board.coins.append $ \div
							.addClass \coin

					if amount > 0bits # pay bits
						coin
							.css do
								top: offset.top - 40px
								opacity: 1
								left: offset.left + 110px
						sleep 300ms*i, ->
							board.coins.eq(i)
								.stop!.animate do
									top: offset.top
									,300ms
								.animate do
									opacity: 0
									,500ms
					else if amount < 0bits # receive bits
						coin
							.css do
								top: offset.top
								opacity: 1
								left: offset.left + 110px
						sleep 300ms*i, ->
							board.coins.eq(i)
								.stop!.animate do
									top: offset.top - 40px
									,300ms
								.animate do
									opacity: 0
									,500ms

			helper player.status.offset!, amount, 0

			if receiver
				helper receiver.status.offset!, -amount, steps

	trade: (seller, buyer, isSelling, subjectName, {defaultPrice=1, validate}:options={}, callback) ->
		board = this
		args = [].slice.call arguments
		minimum = 1bit

		# helper functions
		endTrading = ->
			board.boardDiv.removeClass \trading
			board.reloadBusinessMenu!


		inputFn = (isFirst) ->
			# note: the § indicates, that the input needs to be valid or else the button is disabled
			if isSelling
				btns = ["§ Demand", "Cancel"]
				if isFirst then btns ++= "Let #{buyer.name} offer a price"
				seller.input \number, btns, do
					text: "#{seller.name .toUpperCase!}: how much do you demand for #{subjectName}?"
					default: defaultPrice || 1
					validate: validateFn
					callback: callbackFn
			else
				btns = ["§ Offer", "Cancel"]
				if isFirst then btns ++= "Let #{seller.name} demand a price"
				buyer.input \number, btns, do
					text: "#{buyer.name .toUpperCase!}: Enter your price offer for #{subjectName}"
					default: defaultPrice || 1
					validate: validateFn
					callback: callbackFn

		validateFn = (value) ->
			if value > buyer.bits
				return "You don't even have #{plural value, 'bit'}!"
			else if value < minimum
				return "You have to pay at least #{plural minimum, 'bit'}!"
			else if typeof validate == \function
				return validate value
			else
				return true
		callbackFn = (board, value, btn) ->
			buyer.unhighlight!
			if btn == 0 # "Offer" or "Demand"
				#ToDo: add Multiplayer support
				if isSelling # btn is "Demand"
					buyer.highlight!
					buyer.buttons "#{buyer.name .toUpperCase!}: Do you want to buy #{subjectName} from #{seller.name} for #{plural value, 'bit'}?", do
						"Yes, Buy for #{plural value, 'bit'}": ->
							# TRADING happens here
							buyer.giveBitsTo seller, value
							endTrading!
							callback value, seller, buyer

						"Counteroffer": ->
							buyer.input \number, ["§ Offer", "Cancel"], do
								text: "#{buyer.name .toUpperCase!}: How much do you offer for #{subjectName}?"
								default: defaultPrice || 1
								validate: validateFn
								callback: (board, value2, btn2) ->
									if btn2 == 0 # "Offer"
										minimum = value2
										helper!
									else # btn == 1 # "Cancel"
										callbackFn board, value, btn

						"Don't Buy": ->
							options.defaultPrice >?= value
							helper!
				else # btn is "Offer"
					seller.highlight!
					seller.buttons "#{seller.name .toUpperCase!}: Do you want to sell #{subjectName} to #{seller.name} for #{plural value, 'bit'}?", do
						"Yes, Sell for #{plural value, 'bit'}": ->
							# TRADING happens here
							buyer.giveBitsTo seller, value
							endTrading!
							callback value, seller, buyer

						"Don't Sell": ->
							options.defaultPrice >?= value
							helper!

			else if btn == 1 # "Cancel"
				endTrading!
				callback false
			else # btn == 2 # "Let XXX offer a price"
				inputFn true



		if not buyer? || seller == buyer
			(otherPlayer) <- board.selectPlayerForTrade seller
			options.buyer = otherPlayer
			buyer.highlight!
			board.uncloak!
			inputFn false
		else
			buyer.highlight!
			board.uncloak!
			inputFn false

	tradeField: (field, buyer, callback= ->) ->
		board = this
		seller = field.owner

		if seller.owes
			if seller.creditor
				creditorName = seller.creditor.name
			else
				creditorName = "The Bank"
			minPrice = field.price
		else
			minPrice = 1


		(value, seller, buyer) <- board.trade field.owner, buyer, false, field.name, do
			defaultPrice: minPrice
			validate: (value) ->
				# if the buyer is indebted, only paying higher than the current price is allowed
				if buyer.owes && value < field.price
					return "You have to pay at least #{plural field.price, 'bit'} to not cheat #{creditorName}!"
				else
					return true

		if value
			# onTrade
			if field.isMortgaged
				buyer.buttons ""
			else
				field.setHouses 0
			field.changeOwner buyer
		callback ...

	tradeCard: (seller, buyer, isSelling, callback= ->) ->
		board = this

		(value) <- board.trade seller, buyer, isSelling, "Return-From-the-Moon card", null

		if value
			# onTrade
			seller.returnFromTheMoonCards--
			buyer.returnFromTheMoonCards++

		callback ...


	#= events =
	_events:
		error: [
			(err) ->
				console.error err.stack
				console.error "---------------"
				throw err
		]
		newGame: []
		nextTurn: []
		playerLostGame: []
		playerMoved: []
		playerBitsChanged: []

		buttons: []

	#= Constants =
	@@fieldHeight = 126px # assuming a vertical field
	@@fieldWidth  =  72px # assuming a vertical field
	@@fieldOffset = 774px # = fieldHeight + fieldWidth * 9
	@@boardWidth  = 900px # = fieldOffset + fieldHeight

	@@Board = constructor
	@@nameDatalistID = ""


#== Constructors ==
#= Player =
class Monopony.Player implements MicroEvent::
	(@_board, {@name, @avatar, @color, @position=0, @id, @playerController="singleplayer", avatar}={}) !~>
		Monopony = @_board@@
		board = @_board
		player = this

		if !board.setup
			player.bits = board.startBits

		player.lastPosition = @position

		# multiplayer
		/*
			player.id = data.id
			if data.playerController
				player.playerController = data.playerController
		*/
		player.name ?= Monopony.defaultNames.randomUnused(board.players, \name) || ""

		if !player.avatar
			# monkeypatching to allow running Player::changeAvatar without <img>s
			player.image = player.statusImage = {attr: ->}
			if not player.autoChangeAvatar!
				player.avatar = Monopony.defaultNames.random!

		#ToDo: add prefixes so colors (like "dark-" or "light-")
		player.color ?= Monopony.defaultColors.randomUnused(board.players, \color) || Monopony.defaultColors.random!




		#- HTML -
		player.status = $ \<div>
			.addClass \statusBar-player
			.data \player, player
			.addClass player.playerController
			.click (e) ->
				player.trigger \playerClicked, e
		player.statusImage = $ \<img>
			.addClass \statusBar-avatar
			#.attr \src "images/avatars/#{player.avatar}.png"
			.appendTo player.status
			.click ->
				board.showAvatarPicker player



		kickBtn = $ \<span>
			.addClass \statusBar-remove-player
		if player.playerController == \singleplayer || player.playerController == \local
				if board.setup
					nameHasError = false
					player.statusName = $ \<input>
						.val player.name
						.attr \list, \monopony_names_datalist
						.input ->
							newName = @value
							player.rename newName
							player.autoChangeAvatar newName

							# check for errorneous player names
							errors = board.checkForErrorneousNames player
							if errors
								player.statusLocation.text errors.0
								if !nameHasError
									player.status.addClass \errorneousName
									nameHasError := true
							else if nameHasError
								player.status.removeClass \errorneousName
								player.statusLocation.text ""
								nameHasError := false
				else
					player.statusName = $ \<span>
						.text player.name

				player.statusName
					.addClass \statusBar-playerName
					.appendTo player.status

				if board.room
					kickBtn.text "leave"
				else
					kickBtn.text "remove"
		else
			player.statusName = $ \<span>
				.addClass \statusBar-playerName
				.text player.name
				.appendTo player.status

			kickBtn.text "kick"

		kickBtn
			.appendTo player.status


		player.statusBits = $ \<div>
			.addClass \statusBar-bits
			.appendTo player.status
		player.statusLocation = $ \<div>
			.addClass \statusBar-location
			.appendTo player.status

		if board.players.length == 3
			board.boardDiv.removeClass \two-players


		# set up DOM event listeners
		/*nameChangeTimeout = null
		player.statusName.input ->
			clearTimeout nameChangeTimeout
			newName = @value
			nameChangeTimeout = sleep 500ms, ->
		*/

		kickBtn.click (e) ->
			if not board.room?.isHost
				board.log "[Error] only hosts can kick player"
				return

			if board.multiplayer && player.playerController == \local
				isOnlyLocal = true
				for player in board.players
					if player != player && player.playerController == \local
						isOnlyLocal = false

				if isOnlyLocal
					return board.gotoLobby!

			if board.players.length > 2 || board.multiplayer
				if player.playerController == \remote
					return board.socket.emit \kick, player.id
				board.removePlayer player
				#player = $(this).parent!
				#board.players[player.index!-1].remove!

			#if board.players.length <= 2
			#	board.boardDiv.addClass("two-players")
			return false


		# show status
		player.status
			.hide! # for fading in
			.insertBefore board.newPlayerDiv
			.fadeIn \slow

		# show player on board
		pos = Monopony.spaces[player.position]
		scale = board.scale
		player.image = $ \<img>
			.addClass \player
			.css do
				left: pos.x * scale
				top: pos.y * scale
			.appendTo do
				$ \<div>
					.addClass \position-wrapper
					.appendTo board.boardDiv

		player.changeAvatar player.avatar
		player.draw ->, true

	#= attributes =
	_board: null
	id: null
	name: ""
	avatar: ""
	position: 0
	lastPosition: 0
	bits: 0bits
	playerController: \singleplayer
	returnFromTheMoonCards: 0cards
	doubles: 0
	color: null
	avatarIsCustom: false

	#= states =
	isParking: false
	isOnTheMoon: false
	lost: false

	#= html =
	status: null
	statusName: null
	statusBits: null
	statusLocation: null
	statusImage: null
	image: null

	#= multiplayer =
	remote: false

	#= auxillaries =
	getTotalAssets: -> #ToDo: fix
		player = this

		assets = player.bits
		for field in board.fields
			if field.owner == player
				assets += field.calcValue!
				#assets += field.price
				#assets += field.housePrice * field.houses

		return assets


	#= meta functions =
	draw: (callback, moveDirectly) ->
		board = @_board
		player = this

		callback ||= ->
			board.update!
			player.processField!

		scale = board.scale
		pos = Monopony.spaces[player.position]
		if player.position == 10 # The Moon
			if player.isOnTheMoon
				pos.x +=  30px
				pos.y += -30px
			else
				pos.x += -10px
				pos.y +=   5px


		animatePlayer = (easing, speed_=speed) ->
			<- player.image.animate do
				left: pos.x * scale
				top: pos.y * scale
				,board.animationspeed*speed_, easing
			callback board, player
		animatePlayerToEdge = (easing, speed_=speed) ->
			player.image.animate do
				left: posEdge.x * scale
				top: posEdge.y * scale
				,board.animationspeed*speed_, easing

		player.image.stop!

		# walking around an edge
		side = Math.floor player.position / 10
		sideOld = Math.floor player.lastPosition / 10
		if side == sideOld
			speed = player.position - player.lastPosition
			if speed < 0px_per_ms
				speed += 40px_per_ms
			# console.log "[animating player position]", "speed: #speed", "pos: #{player.lastPosition}", "newPos: #{player.position}"
			animatePlayer \swing


		#else if player.position == 10px && player.isOnTheMoon
			# if the player was send to the Moon
		else if moveDirectly
			# console.log "[animating player position directly]", "speed: #{board.animationspeed*14}", "pos: #{player.lastPosition}", "newPos: #{player.position}"
			animatePlayer \swing, 14ms


		else
			sideOld++
			sideOld %= 4

			# go to next edge
			posEdge = Monopony.spaces[sideOld*10]
			speed = sideOld*10 - player.lastPosition
			if speed < 0px_per_ms
				speed += 40px_per_ms
			# player.image.addClass("no-easing")
			# console.log "[animating player position]", "speed: #speed", "pos: #{player.lastPosition}", "newPos: #{player.position}", "sideOld: #sideOld", "posOld: #posOld"
			animatePlayerToEdge \easeInQuad
			while sideOld != side
				sideOld++
				sideOld %= 4
				posEdge = Monopony.spaces[sideOld*10]
				animatePlayerToEdge \linear, 10ms

			speed = player.position - sideOld*10
			if speed < 0px_per_ms
				speed += 40px_per_ms
			animatePlayer \easeOutQuad

	remove: (noAnimation) ->
		board.removePlayer this, noAnimation

	reset: ->
		this <<<<
			position: 0
			lastPosition: 0
			bits: board.startBits
			assets: 0
			isParking: false
			onTheMoon: false
			lost: false

	cleanUp: ->
		player = this
		board = @_board

		player.bits = board.startBits
		player.isParking = false
		player.isOnTheMoon = false
		player.lost = false
		player.returnFromTheMoonCards = 0
		player.position = 0
		player.lastPosition = 0

		player.status.removeClass "gameover"
		player.image.removeClass "gameover"




	#= game functions =
	rename: (newName) ->
		player = this

		if newName != player.name
			player.name = newName

			if board.multiplayer
				if player.id == board.id
					board.socket.emit \changeName, player.name
				else
					player.statusName.text player.name

	autoChangeAvatar: ->
		board = @_board
		player = this

		newAvatar = player.name.toLowerCase!
			.replace(/ /g, "_")
			.replace(/\s+/g, " ")
			.replace(/^Prince(ss)? /, "")
		for otherAvatar in Monopony.defaultNames
			otherAvatarLC = otherAvatar.toLowerCase!
			if newAvatar == otherAvatarLC
				|| newAvatar.length == 3 && newAvatar == otherAvatarLC.substr(0, 3)
				|| newAvatar == otherAvatarLC.replace(/ .*/, "")
				|| newAvatar == otherAvatarLC.replace(/ /g, "_")
				|| newAvatar == otherAvatarLC.replace(/ /g, "")
					player.changeAvatar otherAvatar
					return true
		return false

	changeAvatar: (newAvatar, isUrl) ->
		Monopony = @_board@@
		board = @_board
		player = this

		if !isUrl
			if newAvatar not in Monopony.defaultNames
				console.warn "[!change Avatar] unknown avatar", newAvatar
				return false

			path = Monopony.getAvatarUrl newAvatar
			player.avatarIsCustom = false
		else
			path = newAvatar
			player.avatarIsCustom = true

		player.avatar = newAvatar
		player.image.attr \src, path
		player.statusImage.attr \src, path

		player.trigger \avatarChanged, board, newAvatar

	highlight: ->
		board = @_board
		player = this

		if board.highlightedPlayer? && board.highlightedPlayer != player
			board.highlightedPlayer.unhighlight!

		board.boardDiv .addClass \highlighting-player
		board.highlightedPlayer = player
		player.status .addClass \highlight

	unhighlight: ->
		board = @_board
		player = this

		if board.highlightedPlayer == player
			board.boardDiv .removeClass \highlighting-player
			player.status .removeClass \highlight
			board.highlightedPlayer = null


	gameover: (callback= -> ) ->
		board = @_board
		player = this

		#ToDo: allow taking loans

		player.lost = true
		#…
		#board.removePlayer player
		board.players.removeItem player
		board.bankruptPlayers.push player
		player.status.addClass \gameover
		player.image.addClass \gameover
		player.trigger \gameover, board

		player.statusBits.text "#{plural 0, 'bit'}"
		player.statusLocation.text "game over"

		#ToDo do whatever is done to a bankrupt player's properties


		if board.players.length == 1
			board.gameEnd!
		else
			callback!

	moveTo: (newPos=0, callback) ->
		board = @_board
		player = this

		if player.position < newPos
			player.move newPos - player.position, callback
		else
			player.move board.fields.length - player.position + newPos, callback

	moveDirectlyTo: (newPos=0, callback) ->
		player = this

		# assuming The Moon is field #10
		if player.isOnTheMoon && newPos != 10 # for whatever reason this is happening. dem haxx0rs <_<
			debugLog "Player #{player.name} moved whilst being on the Moon.", player

			board.log
			player.isOnTheMoon = 0

		player.lastPosition = player.position
		player.position = newPos
		player.draw callback, true

	move: (i=1, callback) ->
		player = this
		board = @_board
		player.lastPosition = oldPosition = player.position
		player.position += i

		if player.position < 0
			player.position = player.position %% board.fields.length

		if player.isOnTheMoon # for whatever reason this is happening. dem haxx0rs <_<
			player.isOnTheMoon = 0

		if player.position  >= board.fields.length
			player.position -= board.fields.length
			player.receiveBits 200bits
			board.log "#{player.name} recieved 200 bits for passing GO!"

		player.draw callback


	pay: (amount, /*optional*/ callback = -> ) ->
		# note: `amount` should generally be a POSITIVE number (e.g. you pay 200 bits -> `player.pay 200bits`)
		# this function is async if the player does not have enough bits and needs to mortgage properties / sell houses to be able to pay
		player = this
		board = @_board

		if !amount
			return

		if player.bits < amount
			/*
			board.msgBox """
				#{player.name} ran out of money.
				Game over, buddy.
				Note: taking loans from the bank by mortaging properties is currently not implemented, sorry
			"""
			player.gameover!
			*/
			player.owes = amount
			player.creditor = null
			board.msgBox "#{player.name} doesn't have enough bits and needs to sell houses and/or mortgage properties."
			<- board.openBusinessMenu amount
			callback!
			return

		else
			player.bits -= amount
			player.trigger \bitsChanged, board, player, -amount
			board.ui \bits, player, -amount
			board.update!
			callback!

	receiveBits: (amount) ->
		# note: `amount` should generally be a POSITIVE number (e.g. you receive 200 bits -> `player.receive 200bits`)
		board = @_board
		player = this

		if !amount
			return

		player.bits += amount
		player.trigger \bitsChanged, board, this, amount

		board.ui \bits, player, amount
		board.update!

	giveBitsTo: (receiver, amount, /*optional*/ callback = -> ) ->
		# note: amount should generally be a POSITIVE number (e.g. p1 gives 200 bits to p2 -> `p1.giveBitsTo 200bits, p2`)
		board = @_board
		player = this

		if !amount
			return

		receiver = board.getPlayer receiver
		if !receiver
			throw new TypeError "in .giveBitsTo: unknown receiver"

		if player.bits < amount
			/*
			board.msgBox """
				#{player.name} ran out of money.
				Game over, buddy.
				Note: taking loans from the bank by mortaging properties is currently not implemented, sorry
			"""
			player.gameover!
			*/
			board.msgBox "#{player.name} doesn't have enough bits and needs to sell houses and/or mortgage properties."
			player.owes = amount
			player.creditor = receiver
			(lastBits) <- board.openBusinessMenu amount
			if lastBits >= amount
				player.giveBitsTo receiver, amount, callback
			else
				callback!
		else
			player.bits -= amount
			receiver.bits += amount
			board.ui \bits player, -amount, receiver
			board.update!
			callback!


	toTheMoon: ->
		board = @_board
		player = this

		player.doubles = 0 # would be kinda awkward otherwise

		board.boardDiv.addClass \to-the-MOOOOOOOONAAAAAAAA

		<- sleep 4000ms
		board.boardDiv.removeClass \to-the-MOOOOOOOONAAAAAAAA
		board.log "#{player.name} was sent to the moon"
		player.isOnTheMoon = 1

		# assuming the Moon is field #10 (counting from 0)
		<- player.moveDirectlyTo 10
		board.endTurn!


	#= playerController=
	buttons: (btns, callback) ->
		board = @_board
		player = this
		return Monopony.playerController[player.playerController].buttons board, btns, callback

	msgBox: (text, callback) ->
		board = @_board
		player = this
		return Monopony.playerController[player.playerController].msgBox board, text, callback

	input: (type, btns, options) ->
		board = @_board
		player = this
		return Monopony.playerController[player.playerController].input board, type, btns, options

	rollDice: (callback) ->
		return Monopony.playerController[player.playerController].rollDice board, callback



	#= turns =
	processField: ->
		board = @_board
		player = this

		field = board.fields[player.position]
		board.log "#{player.name} landed on #{field.name}."
		if field.buyable
			if not field.owner
				btnHasNotEnoughBits = if field.price > player.bits then "%" else ""
				if btnHasNotEnoughBits
					board.log "#{field.name} has no owner, but sadly #{player.name} has NOT enough bits to buy it. It costs #{plural field.price, 'bit'}."
				else
					board.log "#{field.name} has no owner, #{player.name} may buy it for #{plural field.price, 'bit'}."

				player.buttons do
					"#btnHasNotEnoughBits Buy Property": ->
						board.log "*#{player.name} buys #{field.name}*"
						field.buy player
						board.endTurn!

					"Auction": ->
						<- board.auctionField field
						board.endTurn!
			else if field.owner == player
				board.log """
					#{field.name} belongs to #{field.owner.name}.
					#{player.name} is just passing through.
				"""

				board.endTurn!
			else if field.isMortgaged
				board.log """
					#{field.name} is currently mortgaged, thus no rent has to be paid.
					#{player.name} is just passing through.
				"""

				return board.endTurn!
			else
				if field.utility
					# note: the case of landing on a utility field which is unowned is covered before (`if field.buyable … if not field.owner`)
					if field.owner == board.fields[12].owner == board.fields[28].owner
						utilityRent = board.currentDice.sum * 10bits
						board.log """
							#{field.owner.name} owns Apple Harvest and Weather Station.
							#{player.name} has to pay #{field.owner.name} #{plural utilityRent, 'bit'} (10 bits \u00D7 sum of dice).
						"""

						<- board.buttons "Pay #{plural utilityRent, 'bit'}"
						console.log "*#{player.name} pays #{field.owner.name}*"
						<- player.giveBitsTo field.owner, utilityRent
						return board.endTurn!
					else
						utilityRent = board.currentDice.sum * 4bits
						board.log "#{player.name} has to pay #{field.owner.name} #{plural utilityRent, 'bit'} (4 bits \u00D7 sum of dice)."
						<- board.buttons "Pay #{plural utilityRent, 'bit'}"
						console.log "*#{player.name} pays #{field.owner.name}*"

						<- player.giveBitsTo field.owner, utilityRent
						return board.endTurn!

				else if field.station
					stationRent = field.calcRent!

					board.log "#{player.name} has to pay #{field.owner.name} #{plural stationRent, 'bit'}."
					<- board.buttons "Pay #{plural stationRent, 'bit'}"
					console.log "*#{player.name} pays #{field.owner.name}*"

					<- player.giveBitsTo field.owner, stationRent
					return board.endTurn!
				else
					rent = field.calcRent!
					board.log """
						#{field.name} belongs to #{field.owner.name}
						#{player.name} has to pay #{field.owner.name} #{plural rent, 'bit'}
					"""
					<- board.buttons "Pay #{plural rent, 'bit'}"
					console.log "*#{player.name} pays #{field.owner.name}*"

					<- field.payRent player
					board.endTurn!

		else # !field.buyable
			field.action(board, player, field)


	drawCard: (deck) ->
		# `deck` can either be \chance or \communityChest
		player = this
		board = player._board

		deckObj = board["#{deck}Cards"]
		card = deckObj.shift!

		hideCardCallback = ->
			if card.callback
				card.callback board, player, card
			else
				board.endTurn!


		# set buttons on the card
		if !card.returnFromTheMoon
			board.cardButton
				.text "continue"
				.one \click, ->
					if deckObj.length == 0
						# to fix some bugs* nopony cares about, do some filtering here
						# * i.e. more come-back-from-moon cards than usually possible
						board.log "The card deck got refilled and shuffled"
						board.shuffleDeck deck
						board.ui \hideCard, deck, card, ->
							board.ui \updateCarddeck, deck
							hideCardCallback!
					else
						board.ui \hideCard, deck, card, hideCardCallback

					if card.bits > 0
						player.receiveBits card.bits
					else if card.bits < 0
						player.pay -card.bits

					return

		else
			board.cardButton
				.text "save for later"
				.one \click, ->
					player.returnFromTheMoonCards++
					board.ui \hideCard, deck, card, hideCardCallback

		# show card
		board.ui \drawCard, deck, card


	#= events =
	_events:
		error: [
			(err) ->
				# elevate
				err.message = "error on player #{@name} -  #{err.message}"
				@_board.trigger \error, board, this, err
			],
		lose: [
			(player) ->
				# elevate
				@_board.trigger \playerLostGame, board, this
			],
		bitsChanged: [
			(board, player, amount) -> #ToDo remove (or update) this
				# elevate
				board.trigger \playerBitsChanged, board, player, amount
		]
		avatarChanged: []
		playerClicked: [
			(event) ->
				# elevate
				player = this
				board = player._board

				board.trigger \playerClicked, player, event
		]



#= Field =
class Monopony.Field
	!~>
	_board: null

	name: ""
	index: 0
	buyable: false
	utility: false
	station: false

	cleanUp: ->
		field = this

		if field.buyable
			field.ownershipTokenWrapper?.remove!
			field.houses = 0
			field.isMortgaged = false
			field.owner = null

	getPos: ->
		board = @_board
		field = this

		# auxilliary constants
		{fieldHeight: h, fieldWidth: w, fieldOffset: o} = Monopony
		f = field.index

		switch f
			# note: the fields on the edges are as wide as they are high, that's why width = h
			| 0 => # bottom-right
				return [o, o, h, h]
			| 10 => # bottom-left
				return [0, o, h, h]
			| 20 => # top-left
				return [0, 0, h, h]
			| 30 => # top-right
				return [o, 0, h, h]
			| otherwise =>
				switch Math.floor f / 10
				#			x					y					w, h
				| 0 => # bottom
					return [o - f * w, 		 	o, 					w, h]
				| 1 => # left
					return [0, 				 	o - (f - 10) * w, 	h, w]
				| 2 => # top
					return [(f - 21) * w + h, 	0, 					w, h]
				| 3 => # right
					return [o, 				 	o - (40 - f) * w,	h, w]

	reveal: ->
		board = @_board
		field = this

		pos = field.getPos!
		board.cloak pos.0, pos.1, pos.2, pos.3

#= ActionField =
class Monopony.ActionField extends Monopony.Field
	({@name, @action=->, @data}) !~>

	action: null
	data: null
	group: \action

#= UtilityField =
class Monopony.UtilityField extends Monopony.Field
	({@name, @price=@price}) !~>
	buyable: true
	utility: true

	owner: null
	price: 0bits
	group: \utility
	houses: 0

	calcValue: ->
		field = this

		if field.isMortgaged
			return field.price / 2 * 1.1
		else
			return field.price

	calcRent: ->
		field = this

		if field.isMortgaged
			return 0
		else
			return field.price

	isGroupComplete: ->
		field = this
		player = field.owner

		for otherField in board.fieldGroups[field.group]
			if otherField.owner != player
				return false
		return true


	# this is here and not in BuyableField, because it is used in FieldMenu independend of the Field type
	calcPriceForHouses: (amount, ^^fieldMap /*={}*/) ->
		# note: clone$ automatically makes `fieldMap` default to `{}`
		field = this
		player = @owner

		# A house may be built on a color group only after all properties in the group have four houses.
		# houses have to be distributed evenly within color group
		if not (-1 <= amount <= Monopony.stringMaps.houses_.length - 1)
			return false

		playerOwnsGroup = field.isGroupComplete!

		if not playerOwnsGroup
			if amount > 0
				return false

			price = 0
			fieldMap[field.index] = amount
			for otherField in board.fieldGroups[field.group]
				if field.owner == player
					fieldMap[otherField.index] ?= otherField.houses
					if amount == -1 && not otherField.isMortgaged
						price -= otherField.price / 2
					else if amount == 0 && otherField.isMortgaged
						price += otherField.price / 2 * 1.1

		else # if playerOwnsGroup
			fieldMap[field.index] = amount
			price = 0
			maxHouses = amount + 1
			minHouses = amount - 1
			if amount == -1
				maxHouses++
			if amount == 1
				minHouses--

			for otherField in board.fieldGroups[field.group]
				houses = fieldMap[otherField.index] || otherField.houses
				if not (maxHouses >= houses >= minHouses)
					if houses > maxHouses
						houses = maxHouses
					else if houses < minHouses
						houses = minHouses

				housesSansMortgage = houses
				if houses == -1 && otherField.houses != -1 # mortgaging properties
					price -= otherField.price / 2
					housesSansMortgage++
				else if otherField.houses == -1 && houses != -1 # repaying mortgage
					price += otherField.price / 2 * 1.1
					housesSansMortgage--

				if otherField.houses < housesSansMortgage # buying houses
					price += (housesSansMortgage - otherField.houses) * otherField.housePrice
				else if otherField.houses > housesSansMortgage # selling houses
					price -= (otherField.houses - housesSansMortgage) * otherField.housePrice / 2
				fieldMap[otherField.index] = houses

		return [price, fieldMap]

	buy: (player, /*optional*/ payPrincipal) -> # if `payPrincipal` is true, it will be demortgaged when bought
		field = this
		board = @_board
		price = field.price

		if field.isMortgaged
			price *= 1.1 # 10% interest on mortgaged properties
			if not payPrincipal?
				board.log """
					#{player.name} may pay the principal to de-mortgage the property
					note: de-mortgaging the property later will require an additional pay of 10% interest!
				"""
				board.buttons do
					"pay principal (total cost: #{plural price + field.mortgage, 'bit'})": ->
						field.buy player, true
					"don't pay principal": ->
						field.buy player, false
				return

			else if payPrincipal
				price += field.mortgage
				field.isMortgaged = false


		if player.bits >= price
			player.pay price
			field.owner = player

			#= place token =
			side = Math.floor field.index * 4 / board.fields.length
			switch side
			when 0 then # bottom
				x = 7px
				y = 71px
				dir = \horizontal

			when 1 then # left
				x = -30px
				y = 12px
				dir = \vertical

			when 2 then # top
				x = 5p
				y = -34px
				dir = \horizontal

			when 3 then # right
				x = 73px
				y = 13px
				dir = \vertical

			field.ownershipTokenWrapper = $ \<div>
					.addClass \ownershipToken-wrapper
					.append do
						field.ownershipToken = $ \<div>
							.addClass \ownershipToken
							.addClass "ownershipToken-#{dir}"
							.css do
								left: Monopony.spaces[field.index].x + x
								top: Monopony.spaces[field.index].y + y
								background: player.color
								#ToDo: add broader support
					.appendTo board.ownershipTokenContainer

			return true
		else
			#ToDo: is there anything else to consider?
			board.log "#{player.name} does NOT have enough bits to buy this property."
			return false

	changeOwner: (newOwner) ->
		field = this

		# it is assumed that this only gets called on already owned properties
		field.owner = newOwner
		if newOwner
			field.ownershipToken.css \background, newOwner.color
		else
			field.ownershipTokenWrapper.remove!

#= BuyableField =
class Monopony.BuyableField extends Monopony.UtilityField
	({@name, @group, @price, @rent, @house1, @house2, @house3, @house4, @hotel, @housePrice}) !~>
	buyable: true
	utility: false

	owner: null
	group: ""
	isMortgaged: false
	group: null

	ownershipToken: null
	ownershipTokenWrapper: null

	price: 0bits
	rent: 0bits
	house1: 0bits
	house2: 0bits
	house3: 0bits
	house4: 0bits
	hotel: 0bits
	housePrice: 0bits

	# auxilliary
	calcValue: ->
		field = this

		return super! + field.houses * field.housePrice

	calcRent: ->
		field = this
		board = @_board

		if field.isMortgaged
			return 0

		if field.houses == 5
			return field.hotel
		else if 1 <= field.houses <= 4
			return field["house#{field.houses}"]
		else # regular rent
			# double rent if all fields of the color group are owned
			for otherField in board.fieldGroups[field.group]
				if otherField.owner != field.owner
					return field.rent # normal rent if owner doesn't own all houses of group
			return field.rent*2

	# meta-functions
	update: ->
		field = this

		field.ownershipToken.text Monopony.stringMaps.housesShort field.houses

	# basic functions
	payRent: (player, callback) ->
		field = this
		if not field.isMortgaged
			player.giveBitsTo field.owner, field.calcRent!, callback

	# houses & mortgage
	setHouses: (amount, /*optional*/ fieldMapIn={}) ->
		field = this
		player = @owner

		if field.calcPriceForHouses amount, fieldMapIn
			[price, fieldMap] = that
			console.log "[setH]", fieldMapIn, fieldMap
		else
			return false

		if player.bits >= price
			player.pay price
			for index, houses of fieldMap
				if board.fields[index].owner == player
					board.fields[index].houses = houses
					if houses == -1
						board.fields[index]
							..isMortgaged = true
							..ownershipToken.addClass \mortgaged
					board.fields[index].update!

			return true
		else
			board.log "#{player.name} does NOT have enough bits to upgrade this property."
			return false

	mortgageField: (callback= -> ) ->
		#ToDo: check if a `callback` is ever passed at any point
		field = this
		player = @owner

		# property must be unimproved
		if field.isMortgaged
			throw "Can't morgage a property that is already mortgaged!"


		board.log """
			#{player.name} mortgaged #{field.name}.
			The Bank pays #{player.name} #{plural field.price, 'bit'}.
		"""
		field.setHouses -1

	repayMortgage: ->
		field = this
		player = @owner

		price = field.price / 2 * 1.1 # 10% interest rate
		board.log """
			#{player.name} pays the Bank #{plural price, 'bit'} to repay the mortgage for #{field.name}.
			The price includes the 10% interest rate #{player.name} has to pay the Bank.
		"""

		if player.bits >= price
			player.pay price
			field.isMortgaged = false
			field.ownershipToken.removeClass \mortgaged
		else
			board.log "#{player.name} does NOT have enough bits to repay the mortgage for this property."
			return false

#= StationField =
class Monopony.StationField extends Monopony.UtilityField
	({@name, @price=0}) !~>
	utility: false
	station: true
	group: \station

	buy: Monopony.BuyableField::buy
	calcRent: -> #ToDo: change this to cached RailroadList
		stationCounter =
			(field.owner == board.fields. 5.owner) +
			(field.owner == board.fields.15.owner) +
			(field.owner == board.fields.25.owner) +
			(field.owner == board.fields.35.owner)

		return
			switch stationCounter
			| 1 =>  25bits
			| 2 =>  50bits
			| 3 => 100bits
			| 4 => 200bits
			| otherwise => # this should never get called, but you never know dem haxx0rs. oh and custom maps <_<
				25bits * 2^stationCounter

	#ToDo change every access to `field.price` to check if it has to use .calcRent() instead to avoid getters/setters
	price:~ -> @calcRent ... #getter



#= FieldMenu =
class Monopony.FieldMenu
	(@field, @player, highlight/*=false*/) !~>
		# if the player is in debt, `creditor` refers to the player who the current player owes the bits to
		#	the player is not allowed to sell properties to other players but the creditor for prices lower than the original house price
		#	this is to avoid betraying the creditor
		menu = this
		board = field._board
		# player
		# field

		@_board = board
		#board.businessMenus[field.index] = menu

		isInDept = player.owes
		isOwned = (field.owner == player)

		groupIncomplete = !isOwned || field.utility || not field.isGroupComplete!

		menu.div = $ """
			<div class='business-field-menu
							#{if isOwned then \business-field-owned else \business-field-unowned}
							#{if highlight then \business-field-highlighted else ''}
							#{if groupIncomplete then \business-field-group-uncomplete else ''}
							'>
				<div class='business-field-icon'></div>
				<div class='business-field-name'></div>
				<div class='business-field-owner'></div>
				#{if isOwned
					'''
					<div class='business-field-slider-wrapper'>
						<div class='business-field-slider'>
							<div class='business-field-slider-thumb'></div>
						</div>
						<div class='business-field-slider-label business-field-slider-label-house'>hotel</div>
						<div class='business-field-slider-label business-field-slider-label-house'>4 houses</div>
						<div class='business-field-slider-label business-field-slider-label-house'>3 houses</div>
						<div class='business-field-slider-label business-field-slider-label-house'>2 houses</div>
						<div class='business-field-slider-label business-field-slider-label-house'>1 house</div>
						<div class='business-field-slider-label'>no houses</div>
						<div class='business-field-slider-label'>mortgaged</div>
					</div>
					'''
				else ''}
				#{if field.owner
					'''
					<button class='business-field-trade-btn'>Trade</button>
					'''
				else ''}
			</div>"""

		# set up attributes & find HTML elements
		menu <<<<
			icon:		menu.div.find \.business-field-icon
			owner:		menu.div.find \.business-field-owner
			sliderThumb:menu.div.find \.business-field-slider-thumb

			sliderCurrent: field.houses
			sliderNewVal: field.houses
			sliderMax: if groupIncomplete then 0houses else 5houses

		menu
			..icon.addClass "business-field-icon-#{field.houses}"
			..owner.text field.owner?.name || "unowned"
			..div.find \.business-field-name .text field.name
			..div.find \.business-field-trade-btn .click ->
				tradeBtn = $ this

				# fancy UI action
				posLeft = menu.div.position!.left
				for ,otherMenu of board.businessMenus
					otherMenu.div.css left: otherMenu.div.position!.left
				board.boardDiv.addClass \trading-fields

				for ,otherMenu of board.businessMenus when otherMenu != menu
					otherMenu.div.fadeOut!

				menu.div.animate left: 58px, \slow
				tradeBtn.fadeOut!

				# trade Field
				<- board.tradeField field, player
				for ,otherMenu of board.businessMenus when otherMenu != menu
					otherMenu.div.fadeIn
				<- menu.div.animate left: posLeft, \slow
				board.boardDiv.removeClass \trading-fields
			#..div.find \.business-field-housePrice .text "house price: #{plural field.housePrice, 'bit'}"

		# fix thumb's position
		menu.update!

		# bind event listeners
		menu.sliderThumb.bind \mousedown, (e) ->
				menu.mousedown menu, e
				console.log "[mousedown]", menu, field
				e.preventDefault!

		# finally append field-menu to board
		menu.div.appendTo board.businessMenu


	field: null
	player: null
	sliderStartY: null
	sliderCurrent: null
	sliderLineheight: 20px
	sliderMax: 5houses
	sliderThumb: null
	sliderBits: 0bits
	msg: null
	bitsMsg: null
	btn: null

	remove: ->
		menu = this
		field = @field
		board = field._board

		if board.sliderSlidin == menu
			board.sliderSlidin = null
		menu.div.fadeOut -> $ this .remove!
		delete! board.businessMenus[field.index]

	update: ->
		menu = this

		menu.sliderThumb.css \top, 0 - (menu.sliderNewVal + 2) * menu.sliderLineheight

	mousedown: (menu, e) ->
		board = @field._board
		#note: don't bind this directly to events.

		menu.sliderStartY = e.pageY
		menu.sliderNewVal = menu.sliderCurrent
		board.sliderSlidin = menu

		@@mousemove board, e

	@@mouseup = (board, e) ->
		menu = board.sliderSlidin
		#note: don't bind this directly to events.

		return if not board.sliderSlidin


		for fieldIndex, otherMenu of board.businessMenus
			otherMenu.sliderCurrent = otherMenu.sliderNewVal

		board.sliderSlidin = null

	@@mousemove = (board, e) ->
		return  if not board.sliderSlidin
		menu = board.sliderSlidin
		field = menu.field
		#note: don't bind this directly to events.


		oldNewVal = menu.sliderNewVal
		menu.sliderNewVal = menu.sliderCurrent - Math.floor (e.pageY - menu.sliderStartY) / menu.sliderLineheight
		menu.sliderNewVal = -1 >? menu.sliderNewVal <? menu.sliderMax #min-max

		if menu.sliderNewVal == field.houses
			noChange = true
			for index, houses of board.sliderFieldMap when menu.field.index != index
				if board.fields[index].houses != houses
					noChange = false
					break
			if noChange # nothing is bought or sold
				player.buttons do
					$noAnimation: true
					"Back": ->
						board.reloadBusinessMenu!
				return

		if field.calcPriceForHouses menu.sliderNewVal, board.sliderFieldMap
			[price, board.sliderFieldMap] = that
		else
			#board.msgBox "error: something went wrong, the combination of houses doesn't seem possible"
			player.buttons "Not possible!", do
				$noAnimation: true
				"Back": ->
					board.reloadBusinessMenu!
			return

		if price < 0
			btnText = "Receive: #{plural -price, 'bit'}"
		else
			btnText = "Price: #{plural price, 'bit'}"
		player.buttons do
			$noAnimation: true
			"Apply (#btnText)": ->
				changeLog = []
				for otherField in board.fieldGroups[field.group]
					newVal = board.sliderFieldMap[otherField.index]
					oldVal = Monopony.stringMaps.houses otherField.houses
					diff = newVal - oldVal
					if diff == 0
						void # do nothing
					else if oldVal == -1
						changeLog ++= "repayed the mortgage for #{otherField.name}"
					else if newVal == -1
						changeLog ++= "mortgaged #{otherField.name}"
					else if diff != 0
						changeLog ++= "#{if diff > 0 then 'up' else 'down'}graded #{otherField.name} to #{Monopony.stringMaps.houses newVal}"
				/*
				housesMap1 = {}
				housesMap2 = {}
				for houseType in Monopony.stringMaps.houses_
					housesMap1[houseType] = 0
					housesMap2[houseType] = 0

				for otherField in board.fieldGroups[field.group]
					houseTypeCurrent = Monopony.stringMaps.houses otherField.houses
					houseTypeNew = Monopony.stringMaps.houses board.sliderFieldMap[otherField.index]
					housesMap1[houseTypeCurrent]++
					housesMap2[houseTypeNew]++

				bs = {bought: [], sold: [], mortgaged: 0}
				for houseType, housesCurrent of housesMap1
					housesNew = housesMap2[houseType]
					diff = housesNew - housesCurrent
					if housesNew == -1  &&  diff < 0
						diff++
						bs.mortgaged++
					if houseType
						if diff > 0
							bs.bought ++= capitalize "#{plural diff, houseType}"
						else if diff < 0
							bs.sold ++= capitalize "#{plural diff, houseType}"

				housesStr = []
				if bs.bought.length
					housesStr ++= "Bought #{list bs.bought}"
				if bs.sold.length
					housesStr ++= "Sold #{list bs.sold}"
				if bs.mortgaged
					housesStr ++= "Mortgaged #{plural bs.mortgaged, 'property', 'properties'}"
				*/

				changeLog = (list changeLog) || "did nothing"
				# note: `price` is still cached from `@@mousemove`
				if price >= 0
					board.log "#{player.name} #{changeLog} for a total of #{plural price, 'bit'}"
				else if price < 0
					board.log "#{player.name} #{changeLog} and got #{plural -price, 'bit'}"

				field.setHouses menu.sliderNewVal, board.sliderFieldMap
				board.reBusinessMenu!

			"Cancel": ->
				board.reloadBusinessMenu!

		for fieldIndex, houses of board.sliderFieldMap
			board.businessMenus[fieldIndex]
				..sliderNewVal = houses
				..update!


#== Data ==
#= playerController =
Monopony.playerController =
	/*
	"exampleBot":
		buttons: (board, player, btns, callback) ->
		roll_die: (board, player) ->
		onChat: (board, player, from, to, message) -> # optional
	*/
	"singleplayer":
		buttons: (board, btns, callback) ->
			board.buttons btns, callback
		msgBox: (board, text, callback) ->
			board.msgBox text, callback
		input: (board, type, btns, options) ->
			board.input type, btns, options
		rollDice: (board, callback) ->
			board.rollDice callback

	"local":
		buttons: (board, btns, callback) ->
			board.reqNum++
			#player = board.currentPlayer
			console.log "[> buttons]", "(#{board.reqNum})", btns, callback, new Error!.stack
			if board.multiplayerStack[board.reqNum]
				btn = board.multiplayerStack[board.reqNum]
				delete board.multiplayerStack[board.reqNum] #ToDo check if this really gets deleted
				return callback board, btn
			else
				board.multiplayerCallback = btns

				fn = (board, btn) ->
					board.emit \button, board.reqNum, btn, board.currentPlayerNum
					#board.multiplayerCallback(board, btn)
					#callback(board, btn)
				btns2 = {}
				for btn in btns
					btns2[btn] = fn

				return board.buttons btns2

		msgBox: (board, text, callback) ->
			board.msgBox text, callback

		rollDice: (board) ->
			board.reqNum++
			console.log "[> rollDice]", "(#{board.reqNum})", callback
			board.multiplayerCallback = callback
			if board.multiplayerStack[board.reqNum]
				delete board.multiplayerStack[board.reqNum] #ToDo check if this really gets deleted
				return callback board, board.multiplayerStack[board.reqNum]
			else if board.room.isHost
				board.emit \request_dice, board.reqNum

	"remote":
		buttons: (board, btns, callback) ->
			board.reqNum++
			#player = board.currentPlayer
			console.log "[> buttons]", "(#{board.reqNum})", btns
			if board.multiplayerStack[board.reqNum]
				btn = board.multiplayerStack[board.reqNum]
				delete board.multiplayerStack[board.reqNum] #ToDo check if this really gets deleted
				return callback board, btn
			else
				board.multiplayerCallback = callback

		msgBox: (board, text, callback) ->
			...
			callback board

		rollDice: (board, callback) ->
			board.reqNum++
			console.log "[> rollDice]", "(#{board.reqNum})", callback
			board.multiplayerCallback = callback
			if board.multiplayerStack[board.reqNum]
				dice = board.multiplayerStack[board.reqNum]
				delete board.multiplayerStack[board.reqNum] #ToDo check if this really gets deleted
				return callback board, dice
			else if board.room.isHost
					board.emit \request_dice, board.reqNum

	"botSimple":
		buttons: (board, btns, callback) ->
			callback board, 0
		msgBox: (board, text, callback) ->
			callback board
		rollDice: (board, callback) ->
			callback board


#= Cards =
Monopony.chanceCards = [
	{
		title: "Advance to Ponyville Station"
		text: """
			Take a trip to Ponyville Station.

			If you pass Go collect 200 Bits.
		"""
		image: "train1"
		callback: (board, player) ->
			# assuming Ponyville Station is field #5 (counting from 0)
			/*
			if player.position > 5
				#board.log "#{player.name} passed GO bla bla" #ToDo
				player.receiveBits 200bits
			*/
			player.moveTo 5
	}
	{
		title: "Advance to Las Pegasus"
		text: """
			Advance to Las Pegasus.

			If you pass Go collect 200 Bits.
		"""
		image: "las-pegasus"
		callback: (board, player) ->
			# assuming Las Pegasus is field #11 (counting from 0)
			if player.position > 11
				#board.log("#{player.name} passed GO bla bla") #ToDo
				player.receiveBits 200bits
			player.moveTo 11
	}
	{
		title: "Building and Loan matures"
		text: """
			Your building and loan matures

			collect 150 Bits.
		"""
		image: "bits"
		bits: 150bits
	}
	{
		title: "Advance to next Railroad"
		_amount: 2
		text: """
			Advance token to the next railroad and pay owner twice the rental to which he is otherwise entitled.

			If the railroad is UNOWNED, you may buy it from the bank.
		"""
		image: "train2"
		callback: (board, player) ->
			# I assume this "advance to the nearest" means "advance to the next"
			for i from 1 to l=board.fields.length
				field = board.fields[ (player.position+i) % l ]
				if field.station
					if field.owner && field.owner != player
						stationRent = field.calcRent!
						stationRent *= 2 # magic happens here

						<- player.moveTo field.index
						board.log "#{player.name} has to pay #{field.owner.name} #{plural stationRent, 'bit'}"

						<- board.buttons "Pay"
						# note: the reason why the correct `field` is remembered without having `let` in the for-loop is, because the loop gets terminated (using `return`)
						board.log "*#{player.name} pays #{field.owner.name}*"

						<- player.giveBitsTo field.owner, stationRent
						board.endTurn!
					else
						player.moveTo field.index

					return

			# this should never get called because the function terminates as soon as the next railroad is found
			board.log "[ERROR] next railroad not found :C"
			board.endTurn!
	}
	{
		title: "Go back 3 spaces"
		text: "Go back 3 spaces."
		image: "celestia1"
		callback: (board, player) -> # does this trigger the field?
			player.move -3
			#ToDo: fix that
	}
	{
		title: "Poor Tax"
		text: "Pay Poor Tax of 15 bits."
		# text: "Pay earth pony tax of 15 bits."
		image: "bits"
		bits: -15bits
	}
	{
		title: "Return from the Moon"
		_amount: 3
		text: """
			Return from the Moon free.

			This card may be kept until needed or traded/sold.
		"""
		image: "theMoon"
		returnFromTheMoon: true
	}
	{
		title: "Canterlot Bank dividend"
		text: "Canterlot pays you dividend of 50 Bits."
		image: "bits"
		bits: 50bits
	}
	{
		title: "Advance to next Utility"
		text: """
			Advance token to the nearest utility. If unowned you may buy it from the bank.

			If owned, throw dice and pay owner a total ten \u00D7 the amount thrown.
		"""
		image: "wonderbolts"
		callback: (board, player) ->
			for i from 1 to l=board.fields.length
				field = board.fields[ (player.position+i) % l ]
				if field.utility
					# no `<-` because `return` wouldn't stop the loop
					player.move field.index - player.position, ->

						#ToDo await
						if field.owner == null
							player.processField!
						else if field.owner != player
							player.buttons "Throw dice": ->
								player.rollDice (board, die) ->
									#note: the reason why the correct `field` is remembered without having `let` in the for-loop is, because the loop gets terminated (using `return`)
									amount = die.0*10bits
									board.log "#{player.name} threw a #{die.0}."
									board.log "#{player.name} has to pay '#{field.owner.name}' #{plural amount, 'bit'}."
									player.buttons "Pay #{plural amount, 'bit'}": ->
										<- player.giveBitsTo field.owner, amount
										board.endTurn!
						else
							board.endTurn!

					return

			# this should never get called because the function terminates as soon as the next utility is found
			board.log "[ERROR] next utility field not found :C"
			board.endTurn!
	}
	{
		title: "Advance to Whitetail Wood"
		text: """
			Advance to Whitetail Wood.

			If you pass Go collect 200 Bits.
		"""
		image: "whitetail-wood"
		callback: (board, player) ->
			# assuming Whitetail Wood is field #24 (counting from 0)
			if player.position > 24
				#board.log("#{player.name} passed GO bla bla") #ToDo
				player.receiveBits 200bits

			player.moveTo 24
	}
	{
		title: "Mayor of Ponyville"
		text: """
			You have been elected mayor of Ponyville.
			Pay each player 50 Bits.
			(note: you do NOT own the field 'Ponyville' now)
		"""
		image: "mayor"
		callback: (board, player) ->
			amount = (board.players.length - 1) * 50bits
			if player.bits < amount
				player.owes amount
				player.creditor board.players.sans player
				<- board.openBusinessMenu
				board.endTurn!
			else
				<- icedCoffee (await) ->
					for let otherPlayer in board.players
						if otherPlayer != player
							(defer) <- await
							player.giveBitsTo otherPlayer, 50bits, defer
				board.endTurn!
	}
	{
		title: "Advance to Canterlot"
		text: "Take a chariot to Canterlot." # If you pass Go collect 200 Bits." # This. Doesn't. Make. Any. Sense. Canterlot is the last field before GO therefor you can't possibly pass GO.
		image: "canterlot"
		callback: (board, player) ->
			# assuming Canterlot is field #39 (counting from 0)
			if player.position > 39
				#board.log("#{player.name} passed GO bla bla") #ToDo
				player.receiveBits 200bits

			player.moveTo 39
	}
	{
		title: "Advance to Go"
		text: "Advance to Go. Collect 200 Bits"
		image: "go"
		callback: (board, player) ->
			player.moveTo 0
	}
	{
		title: "Repair costs"
		text: """
			Discord ravages Equestria.
			For each house pay 25 bits,
			for each hotel 100 bits.
		"""
		image: "discord"
		callback: (board, player) ->
			costs = 0
			hotels = 0
			houses = 0
			for field in board.fields
				if field.owner == player
					if field.hotel
						hotels++
					else
						houses++
					#ToDo: is this accurate?

			board.log "#{player.name} owns #{plural houses, 'house'} and #{plural hotels, 'hotel'} and thus has to pay #{plural hotels*100bits + houses*25bits, 'bit'}"
			player.pay hotels*100bits + houses*25bits
			board.endTurn!
	}
]
Monopony.communityChestCards = [
	{
		title: "Advance to Go"
		text: "Advance to Go (collect 200 bits)"
		# assuming Go is field #0 (counting from 0)
		image: "pinkie1"
		callback: (board, player) ->
			player.moveTo 0
	}
	{
		title: "Bank error in your favor"
		text: "collect 200 bits"
		image: "derpy"
		bits: 200bits
	}
	{
		title: "Hire DJ for party"
		text: "pay 50 bits"
		image: "vinyl"
		bits: -50bits
	}
	{
		title: "Get released from Moon early"
		text: "This card may be kept until needed or sold"
		image: "nightmare-moon-shrug"
		returnFromTheMoon: true
	}
	{
		title: "BANISHED!"
		text: """
			Go directly to the Moon

			Do NOT pass Go
			Do NOT collect 200 bits
		"""
		image: "celestia2"
		# assuming The Moon is field #10 (counting from 0)
		callback: (board, player) ->
			player.toTheMoon!
	}
	{
		title: "It's your birthday"
		text: "Collect 10 bits from each player"
		image: "pinkie2"
		callback: (board, player) ->
			<- icedCoffee (await) ->
				for let otherPlayer in board.players
					if otherPlayer != player
						(defer) <- await
						otherPlayer.giveBitsTo player, 10bits, defer
			board.endTurn!

	}
	{
		title: "Grand Galloping Gala"
		text: "Collect 50 bits from each player for ticket fees"
		image: "tickets"
		callback: (board, player) ->
			<- icedCoffee (await) ->
				for let otherPlayer in board.players
					if otherPlayer != player
						(defer) <- await
						otherPlayer.giveBitsTo player, 50bits, defer
			board.endTurn
	}
	{
		title: "Soarin buys a pie"
		text: "collect 20 bits"
		image: "soarin"
		bits: 20bits
	}
	{
		title: "Life insurance matures"
		text: """
			Life insurance matures.
			Collect 100 bits
		"""
		image: "old-pony"
		bits: 100bits
	}
	{
		title: "Flying accident"
		text: "pay 100 bits for hospital fees"
		image: "rainbow-dash"
		bits: -100bits
	}
	{
		title: "School fee"
		text: "Pay 50 bits"
		image: "cheerilee"
		bits: -50bits
	}
	{
		title: "Parasprites invade"
		text: """
			Pay 40 bits per house
			and 115 bits per hotel
		"""
		image: "parasprite"
		callback: (board, player) ->
			costs = 0
			hotels = 0
			houses = 0
			for field in board.fields
				if field.owner == player
					if field.hotel
						hotels++
					else
						houses++
			board.log "#{player.name} owns #{plural houses, 'house'} and #{plural hotels, 'hotel'} and thus has to pay #{plural hotels*115bits + houses*40bits, 'bit'} repair costs"

			player.pay hotels*115bits + houses*40bits
			board.endTurn!
	}
	{
		title: "Win first price in a beauty contest"
		text: "Collect 100 bits"
		image: "rarity"
		bits: 100bits
	}
	{
		title: "Win second price in a beauty contest"
		text: "Collect 10 bits"
		image: "twilight-sparkle2"
		bits: 10bits
	}
	{
		title: "Sale of cider"
		text: "From sale of cider you receive 50 bits"
		image: "cider"
		bits: 50bits
	}
	{
		title: "Organize wedding"
		text: "Collect 100 bits payment"
		image: "twilight-sparkle1"
		bits: 100bits
	}
	{
		title: "Sell cherry to Fluttershy"
		text: "collect 25 bits"
		image: "cherry"
		bits: 25bits
	}
]
# clone cards with `_amount` attribute
for deck in Monopony[\chanceCards, \communityChestCards]
	for card in deck
		for from 1 to card._amount
			deck.push card
		delete card._amount



#= Default Data & Field Actions =
Monopony <<<<
	#= auxiliaries =
	generateID: ->
		return ( Math.random!*0x1_0000_0000 ).toString 16 # 0x00000000 - 0xFFFFFFFF

	getAvatarUrl: (avatar) ->
		return "images/avatars/#{avatar.replace(/ /g, "_")}.png"

	#= game data =
	defaultColors:
		* \maroon
		* \red
		* \pink
		* \khaki
		* \yellow
		* \lightgreen
		#* \green
		* \lime
		* \cyan
		* \blue
		* \fuchsia
		#* \indigo

	defaultNames:
		#- Mane Ponies -
		* "Twilight" # "Twilight Sparkle" is too long
		* "Pinkie Pie"
		* "Applejack"
		* "Rainbow Dash"
		* "Rarity"
		* "Fluttershy"

		#- Other Characters -
		* "Princess Luna"
		* "Spike"
		* "Gummy"
		* "Derpy"
		* "Colgate"

		#- OCs -
	/*
		* "Alptraum Mond"
		* "Brinkie Pie"
		* "Canpan"
		* "Cookie"
		* "Ryan"
		* "Swift"
		* "Thermal Cake"
		* "TropicDash"
	*/

	customAvatars:
		* "Alptraum Mond"
		* "Brinkie Pie"
		* "Canpan"
		* "Cookie"
		* "Ryan"
		* "Swift"
		* "Thermal Cake"
		* "TropicDash"
		* "Death Mint"
		* "MrSleepyguy"

	/*
		#- OCs - #ToDo: remove when out of beta
		* "Brinkie Pie"
		* "Thermal Cake"
		* "Colgate"
		* "Canpan"
		* "Swift"
		* "Alptraum Mond"
		* "Ryan"
		* "Cookie"
		* "TropicDash"
	*/

	spaces:
		* x:816px, y:816px
		* x:710px, y:816px
		* x:638px, y:816px
		* x:566px, y:816px
		* x:494px, y:816px
		* x:422px, y:816px
		* x:350px, y:816px
		* x:278px, y:816px
		* x:206px, y:816px
		* x:134px, y:816px
		* x: 30px, y:816px
		* x: 30px, y:710px
		* x: 30px, y:638px
		* x: 30px, y:566px
		* x: 30px, y:494px
		* x: 30px, y:422px
		* x: 30px, y:350px
		* x: 30px, y:278px
		* x: 30px, y:206px
		* x: 30px, y:134px
		* x: 30px, y: 30px
		* x:134px, y: 30px
		* x:206px, y: 30px
		* x:278px, y: 30px
		* x:350px, y: 30px
		* x:422px, y: 30px
		* x:494px, y: 30px
		* x:566px, y: 30px
		* x:638px, y: 30px
		* x:710px, y: 30px
		* x:816px, y: 30px
		* x:816px, y:134px
		* x:816px, y:206px
		* x:816px, y:278px
		* x:816px, y:350px
		* x:816px, y:422px
		* x:816px, y:494px
		* x:816px, y:566px
		* x:816px, y:638px
		* x:816px, y:710px


	actions:
		doNothing: (board, player, field) ->
			board.endTurn!
		/*
		trainStation: (board, player, field) ->
			board.log "#{player.name} stepped on the train station '#{field.name}'. #{player.name} may roll the die again."
			board.startTurn!
		*/
		chance: (board, player, field) ->
			board.log "#{player.name} draws a chance card."
			player.drawCard \chance

		communityChest: (board, player, field) ->
			board.log "#{player.name} draws a card from the community chest."
			player.drawCard \communityChest

		/*
		parking: (board, player, field) ->
			board.log "#{player.name} parks"
			player.isParking = true
			board.endTurn!
		*/


		visiteTheMoon: (board, player, field) ->
			board.log "#{player} is just visiting."
			board.endTurn!

		toTheMoon: (board, player, field) ->
			player.toTheMoon!

		incomeTax: (board, player, field) ->
			board.log "#{player.name} has to pay taxes! #{player.name} can choose between paying 10% of all assets possessed OR 200 bits."
			btnHasNotEnoughBits = if player.bits < 200bits then "%" else ""
			player.buttons do
				"Pay 10%": ->
					price = Math.ceil player.getTotalAssets! * 0.1
					board.log "#{player.name} payed 10% off all assets. (#{plural price, 'bit'})"
					player.pay price
					board.endTurn!

				"Pay 200 Bits": ->
					price = 200bits
					board.log "#{player.name} payed 200 bits."
					player.pay price
					board.endTurn!

		luxuryTax: (board, player, field) ->
			board.log "#{player.name} has to pay 75 bits luruxy tax"
			<- player.buttons "pay 75 bits luruxy tax"
			board.log "#{player.name} payed 75 bits."
			player.pay 75bits
			board.endTurn!

#= Fields =
#NOTE: the mortage parameter is obsolete. it is still not deleted for future references while in alpha
#ToDo: remove the mortage parameter
#Note: when editing the map, please update the server as well, as it has a list of fields for logging
Monopony::fields =
	#== bottom row ==
	* new Monopony.ActionField	name: "GO", action: Monopony.actions.doNothing
	* new Monopony.BuyableField	name: "Rock Farm", group: 0, price: 60, rent: 2bits, house1: 10bits, house2: 30bits, house3: 90bits, house4: 160bits, hotel: 250bits, housePrice: 50bits, mortgage: 30bits
	* new Monopony.ActionField	name: "Community Chest", action: Monopony.actions.communityChest
	* new Monopony.BuyableField	name: "Ponyville", group: 0, price: 80, rent: 4bits, house1: 20bits, house2: 60bits, house3: 180bits, house4: 320bits, hotel: 450bits, housePrice: 50bits, mortgage: 30bits
	* new Monopony.ActionField	name: "Income Tax", action: Monopony.actions.incomeTax
	* new Monopony.StationField	name: "Ponyville Station", price: 200, mortgage: 100bits
	* new Monopony.BuyableField	name: "Fillydelphia", group: 1, price: 100, rent: 6bits, house1: 30bits, house2: 90bits, house3: 270bits, house4: 400bits, hotel: 550bits, housePrice: 50bits, mortgage: 50bits
	* new Monopony.ActionField	name: "Chance", action: Monopony.actions.chance
	* new Monopony.BuyableField	name: "Hoofington", group: 1, price: 100, rent: 6bits, house1: 30bits, house2: 90bits, house3: 270bits, house4: 400bits, hotel: 550bits, housePrice: 50bits, mortgage: 50bits
	* new Monopony.BuyableField	name: "Trottingham", group: 1, price: 120, rent: 8bits, house1: 40bits, house2: 100bits, house3: 300bits, house4: 450bits, hotel: 600bits, housePrice: 50bits, mortgage: 60bits
	#== left side ==
	* new Monopony.ActionField 	name: "The Moon", action: Monopony.actions.doNothing
	* new Monopony.BuyableField	name: "Las Pegasus", group: 2, price: 140, rent: 10bits, house1: 50bits, house2: 150bits, house3: 450bits, house4: 625bits, hotel: 750bits, housePrice: 100bits, mortgage: 70bits
	* new Monopony.UtilityField	name: "Apple Harvest", price: 150
	* new Monopony.BuyableField	name: "Baltimare", group: 2, price: 140, rent: 10bits, house1: 50bits, house2: 150bits, house3: 450bits, house4: 625bits, hotel: 750bits, housePrice: 100bits, mortgage: 70bits
	* new Monopony.BuyableField	name: "Manehattan", group: 2, price: 160, rent: 12bits, house1: 60bits, house2: 180bits, house3: 500bits, house4: 700bits, hotel: 900bits, housePrice: 100bits, mortgage: 80bits
	* new Monopony.StationField	name: "Appleloosa Station", price: 200, mortgage: 100bits
	* new Monopony.BuyableField	name: "Appleloosa", group: 3, price: 180, rent: 14bits, house1: 70bits, house2: 200bits, house3: 550bits, house4: 750bits, hotel: 950bits, housePrice: 100bits, mortgage: 90bits
	* new Monopony.ActionField	name: "Community Chest", action: Monopony.actions.communityChest
	* new Monopony.BuyableField	name: "Dodge Junction", group: 3, price: 180, rent: 14bits, house1: 70bits, house2: 200bits, house3: 550bits, house4: 750bits, hotel: 950bits, housePrice: 100bits, mortgage: 90bits
	* new Monopony.BuyableField	name: "Sweet Apple Acres", group: 3, price: 200, rent: 16bits, house1: 80bits, house2: 220bits, house3: 600bits, house4: 800bits, hotel: 1000bits, housePrice: 100bits, mortgage: 100bits
	* new Monopony.ActionField	name: "Free Parking", action: Monopony.actions.doNothing
	#== top row ==
	* new Monopony.BuyableField	name: "Canterlot Gardens", group: 4, price: 220, rent: 18bits, house1: 90bits, house2: 250bits, house3: 700bits, house4: 875bits, hotel: 1050bits, housePrice: 150bits, mortgage: 110bits
	* new Monopony.ActionField	name: "Chance", action: Monopony.actions.chance
	* new Monopony.BuyableField	name: "Ghastly Gorge", group: 4, price: 220, rent: 18bits, house1: 90bits, house2: 250bits, house3: 700bits, house4: 875bits, hotel: 1050bits, housePrice: 150bits, mortgage: 110bits
	* new Monopony.BuyableField	name: "Whitetail Wood", group: 4, price: 240, rent: 20bits, house1: 100bits, house2: 300bits, house3: 750bits, house4: 925bits, hotel: 1100bits, housePrice: 150bits, mortgage: 120bits
	* new Monopony.StationField	name: "Dodge Junction Station", price: 200, mortgage: 100bits
	* new Monopony.BuyableField	name: "The Everfree Forest", group: 5, price: 260, rent: 22bits, house1: 110bits, house2: 330bits, house3: 800bits, house4: 975bits, hotel: 1150bits, housePrice: 150bits, mortgage: 130bits
	* new Monopony.BuyableField	name: "Froggy Bottom Bog", group: 5, price: 260, rent: 22bits, house1: 110bits, house2: 330bits, house3: 800bits, house4: 975bits, hotel: 1150bits, housePrice: 150bits, mortgage: 130bits
	* new Monopony.UtilityField	name: "Weather Factory", price: 150
	* new Monopony.BuyableField	name: "Zecora's Hut", group: 5, price: 280, rent: 24bits, house1: 120bits, house2: 360bits, house3: 850bits, house4: 1025bits, hotel: 1200bits, housePrice: 150bits, mortgage: 140bits
	* new Monopony.ActionField	name: "Banished To The Moon", action: Monopony.actions.toTheMoon
	#== right side ==
	* new Monopony.BuyableField	name: "Sugarcube Corner", group: 6, price: 300, rent: 26bits, house1: 130bits, house2: 390bits, house3: 900bits, house4: 1100bits, hotel: 1275bits, housePrice: 200bits, mortgage: 150bits
	* new Monopony.BuyableField	name: "Carousel Boutique", group: 6, price: 300, rent: 26bits, house1: 130bits, house2: 390bits, house3: 900bits, house4: 1100bits, hotel: 1275bits, housePrice: 200bits, mortgage: 150bits
	* new Monopony.ActionField	name: "Community Chest", action: Monopony.actions.communityChest
	* new Monopony.BuyableField	name: "School House", group: 6, price: 320, rent: 28bits, house1: 150bits, house2: 450bits, house3: 1000bits, house4: 1200bits, hotel: 1400bits, housePrice: 200bits, mortgage: 160bits
	* new Monopony.StationField	name: "Canterlot Station", price: 200, mortgage: 100bits
	* new Monopony.ActionField	name: "Chance", action: Monopony.actions.chance
	* new Monopony.BuyableField	name: "Cloudsdale", group: 7, price: 350, rent: 35bits, house1: 175bits, house2: 500bits, house3: 1100bits, house4: 1300bits, hotel: 1500bits, housePrice: 200bits, mortgage: 175bits
	* new Monopony.ActionField	name: "Luxury Tax", action: Monopony.actions.luxuryTax #ToDo
	* new Monopony.BuyableField	name: "Canterlot", group: 7, price: 400, rent: 50bits, house1: 200bits, house2: 600bits, house3: 1400bits, house4: 1700bits, hotel: 2000bits, housePrice: 200bits, mortgage: 200bits
for field, i in Monopony::fields
	field.index = i
	if \group of field
		Monopony::fieldGroups.[][field.group].push field # note: due to a bug, autovivification and ++= don't work together


#= StringMaps =
Monopony.stringMaps =
	houses_:  [""] ++ <[ house house house house hotel ]>
	houses: (num) ->
		return @houses_[num] || "ERROR"

	housesShort_: (<[ X 1 2 3 4 H ]>) <<<< {(-1): "m", 0: ""}
	housesShort: (num) ->
		return @housesShort_[num] || "?"




#== Multiplayer ==
Monopony ::=
	MP_SERVER: "/"
	initMultiplayer: ->
		board = this

		if !board.socket && board.multiplayerDeferred.state! == \resolved
			return board.connect!

		if board.multiplayerDeferred.state! == \pending
			board.multiplayer = true

		return board.multiplayerDeferred.promise!

	reconnect: ->
		board = this

		board.multiplayerDeferred = $.getScript "#{board.MP_SERVER}socket.io/socket.io.js"
			.done ->
				board.boardDiv.addClass \serverOnline
				if board.multiplayer
					board.connect!

	connect: ->
		board = this


		socket = io.connect!
		board.socket = socket
		board.multiplayer = true
		board.boardDiv.addClass \multiplayer
		for player in board.players
			if player.playerController == \singleplayer
				player.playerController = \local

		board.reqs.0 = $.Deferred! .then (userid) ->
			board.players.0.id = board.id = userid


		socket.on \connect, ->
			console.log "[< connect]", arguments
			board.log "Connected to the Multiplayer Server"
			board.emit \changeName, board.players.0.name

		socket.on \disconnect, ->
			console.log "[< disconnect]", arguments
			board.log "WARNING: The server disconnected. all rooms are closed"
			board.gotoLobby!
			#for id of board.rooms
			#	delete board.rooms[id]
			board.rooms = {}


		socket.on \ok, (reqID, data) ->
			console.log "[< ok]", reqID, data
			board.reqs[reqID].resolve data
			delete board.reqs[reqID]

		socket.on \notOK, (reqID, reason) ->
			console.log "[< notOK]", reqID, reason
			board.reqs[reqID].reject reason
			delete board.reqs[reqID]



		socket.on \gameStarted, (id) ->
			console.log("[< gameStarted]", id)
			if id == board.room.id
				board.buttons!
				board.startGame!

		socket.on \updateOptions, (options) ->
			board.room.options = options
			board.applyOptions options



		socket.on \dice, (reqNum, dice1, dice2) ->
			console.log "[< dice]", "(#reqNum)", dice1, dice2
			if board.reqNum == reqNum
				board.multiplayerCallback board, board.currentPlayer, [dice1, dice2]
			else
				board.multiplayerStack[reqNum] = [dice1, dice2]
			#board.multiplayerCallback = FN

		socket.on \button, (reqNum, btn) ->
			console.log "[< button]", "(#reqNum)", btn
			if board.reqNum == reqNum
				board.multiplayerCallback[btn] board, board.currentPlayer, btn
			else
				board.multiplayerStack[reqNum] = btn

		socket.on \buttonCheck, (reqNum, btn, playerID) ->
			console.log "[< buttonCheck]", "(#reqNum)", btn
			#ToDo: do some waiting if reqNum > board.reqNum
			if board.currentPlayer.id == playerID
				#ToDo: check if `btn` it's a valid button
				board.emit "button", reqNum, btn
			else
				board.log "WARNING: #{board.room.players[playerID].name} tried to choose a button, but it's #{board.currentPlayer.name}'s turn!"


		socket.on \lobby, (roomList, userInLobby) ->
			console.log "[< lobby]", roomList, userInLobby
			board.rooms = roomList
			# void userInLobby
			#ToDo

		socket.on \roomCreated, (id, roomName) ->
			console.log "[< roomCreated]", id, roomName
			board.rooms[id] = roomName

		socket.on \roomClosed, (id) ->
			console.log "[< roomClosed]", id
			if board.room.id == id
				board.gotoLobby!
			delete board.rooms[id]



		socket.on \playerLeftRoom, (id, reason) ->
			console.log "[< playerLeftRoom]", id, reason
			board.removePlayer board.room.players[id]

		socket.on \playerJoinedRoom, (data) ->
			console.log "[< playerJoinedRoom]", data
			board.log "#{data.name} joined the room"

			board.room.players[data.id] = board.addPlayer data

		socket.on \kicked, (reason) ->
			console.log "[< kicked]", reason
			if reason
				reason = " (#{reason})"
			else
				reason = ""
			board.log "YOU GOT KICKED" +reason
			board.gotoLobby!


		socket.on \playerChangedName, (id, newName) ->
			player = board.room.players[id]
			console.log "[< playerChangedName]", id, newName, player
			player.name = newName
			player.status.trigger "nameChanged", player

		socket.on \playerChangedAvatar, (id, newAvatar) ->
			console.log "[< playerChangedAvatar]", id, newAvatar
			#ToDo



		socket.on \chat, (fromID, msg) ->
			console.log "[< chat]", fromID, msg
			board.log "[chat] #fromID: #msg"
			for player in board.players
				# run chat callback of all players (if present) so bots can do their thing...
				Monopony.playerController[player.playerController].onChat? board, this, message


		return board.multiplayerDeferred

	emit: (type, ...args) -> # (, param1, param2, ...)
		board = this

		if type in <[ joinRoom createRoom ]> # if the type requires a reqID
			reqID = Monopony.generateID!
			console.log "[> emit*]", reqID, type, args
			args = [type, reqID] ++ args
			board.socket `board.socket.emit.apply` args
			board.reqs[reqID] = $.Deferred!
			return board.reqs[reqID]
		else
			console.log "[> emit]", arguments
			return board.socket `board.socket.emit.apply` arguments

	gotoLobby: ->
		board = this
		socket = board.socket

		board.emit \gotoLobby
		if board.room
			#= leaving the current room =
			# remove all other players
			for player in board.players
				if player.playerController == \remote
					board.removePlayer player
				else
					player.reset!

			/* This is for allowing multiple players on one client
			for player in board.players
				board.removePlayer(player)
			*/


		board.buttons do
			"Start new Room": ->
				board.createRoom!

			"Join another Room": -> #ToDo check this
				rooms = ^^board.rooms
				roomIDs = []
				btns = {}
				for id, name of rooms
					btns[name] = ->
					roomIDs ++= id
				btns.$always = (board,btn,i) ->
					board.joinRoom roomIDs[i]
				/*rooms = {
					always: -> board.joinRoom Object.keys(rooms)[btn]
				} <<<< board.rooms*/
				board.buttons btns

	createRoom: ->
		board.room = {
			name: "#{board.players.0.name}'s Room"
			players: {}
			isHost: true
		}
		board.room[board.id] = board.players.0
		board.log "creating a room..."
		board.emit \createRoom, do
			name: board.room.name,
			startBits: board.startBits
		.then (roomID) ->
			board.room.id = roomID
			board.log "The room #{board.room.name} was created"
			board.buttons do
				"Start Game": ->
					board.gotoLobby!
				"Close Room": ->
					board.emit \startGame

	joinRoom: (roomID) ->
		board.emit \joinRoom, roomID
			.then (options) ->
				console.log "[joinRoom cb]", options, arguments
				board.room = {
					id: roomID
					name: board.rooms[roomID]
					players: {} # they'll be added later
					isHost: false
					options: options
				}
				board.log """
					You joined #{board.room.name}.
					Waiting for other players...
				"""
				#"Wait for the host to start the game.")

				# apply options
				board.startBits = options.startBits

				# clear player list so new list can be loaded
				for player in board.players
					board.removePlayer player, true

				for player in options.players
					if player.id == board.id
						player.playerController = \local
					board.room.players[player.id] = board.addPlayer player

				board.applyOptions options

				board.buttons "Leave the Room": ->
					board.gotoLobby!




#== Load Game ==
$ ->
	window.board = board := new Monopony $ \#game

	#== Game start ==
	board.startMenu!



#= Debugging functions =
$ ->
	player := board.players.0

	board.rollDice_ := board.rollDice
	forceDice := (num1, num2) !->
		if board.multiplayer
			console.warn "[warning] using this in multiplayer is likely to break the game!"

		if num1 && not num2?
			if 7 < num1 < 13
				num2 = num1 - 6
				num1 = 6
			else
				num1 = num1 - 1
				num2 = 1

		num1 = Math.floor num1
		num2 = Math.floor num2

		if not (1 <= num1 <= 6 || 1 <= num2 <= 6)
			console.warn "[warning]", "One or both of the die have unusual values (1-6 is considered 'usual'). This is generally no problem but don't rely on it!"
		if num1 + num2 > 80
			console.warn "[warning]", "You forced die with a sum >40! This WILL crash the game!"
		else if num1 + num2 > 40
			console.warn "[warning]", "You forced die with a sum >40! This might crash the game!"

		console.log "> going to roll a #{number num1} and a #{number num2} next time"
		if num1 == num2
			console.log "> NOTE: those are doubles, so the player might roll the dice again"

		board.rollDice = (callback) ->
			console.log "[forced die]", num1, num2
			board.rollDice = board.rollDice_
			dice = [num1, num2]
			dice.sum = num1 + num2
			return callback board, dice

	forceCard := (cardName, cardNum) ->
		decks = [\chance, \communityChest]
		for deck in decks
			for card, i in Monopony["#{deck}Cards"]
				if card.title == cardName
					console.log "[forceCard] got it. (deck: #{deck}Cards)"
					board["#{deck}Cards"].unshift card
					return card

		console.warn "\t>The specified card could not be found, trying in-text-search"

		re = RegExp cardName, \i
		matches = {}
		for deck in decks
			for card in Monopony["#{deck}Cards"]
				if re.test card.title and (not) card.title in matches
					if matches.length+1 == cardNum
						console.log "[forceCard] got it. (deck: #{deck}Cards)"
						board["#{deck}Cards"].unshift card
					else
						matches[][deck][*] = card

		window.m = ^^matches
		if not matches.isEmptyObject!
			for deck, matchesInDeck of matches
				for card, i in matchesInDeck
					console.log "> possible match in #{deck} \##{1+i}: #{card.title}"

				if not cardNum?
					console.log "[forceCard] forcing '#{card.title}' (deck: #{deck}Cards)"
					board["#{deck}Cards"].unshift card
		else
			throw new Error "Sorry, the specified card could not be found"

	clickBtnQue = []
	clickBtnListenerAttached = false
	clickBtn := (i=0, force) ->
		btns = board.buttonsField.find \button
		if btns.length && (force || !clickBtnQue.length)
			btns.eq(i) .click!
		else if i?
			clickBtnQue ++= i

		if clickBtnQue.length && !clickBtnListenerAttached
			clickBtnListenerAttached = true
			board.once \buttons, ->
				console.log "[BTNS]", clickBtnQue
				clickBtnListenerAttached = false
				clickBtn clickBtnQue.shift!, true

	checkUnusedPrototypeAttrs := ->
		for attr, i in board
			if typeof attr != \function && attr === Monopony.prototype[i]
				console.warn i, attr
			else if (not) i in Monopony.prototype
				console.error i
	showAllCards := ->
		for $card in Monopony.chanceCards.concat Monopony.communityChestCards
			card = board.card.clone!
			cardTitle = card.find \.card-title
			cardImage = card.find \.card-image
			cardText = card.find \.card-text

			cardTitle.text $card.title
			cardImage.attr \src, "images/cards/#{$card.image}.png"
			cardText.text $card.text

			card.appendTo \body



# debug check for game crash
<- (do)
/*
hasNoBtns = false
setInterval do
	->
		if board.boardDiv.find \button .filter ($ it .visible!) .length == 0
			sleep 5_000ms, ->
				board.buttons "did the game crash?", do
					"Yes": ->
						board.msgBox "I'm sorry =(\nplease let me know about this and how it happened."
						<- board.buttons "Restart game"
						board.cleanUp!
						board.startMenu!
					"No": ->
						board.msgBox "nvm =)\nkthxbye"
	, 5_000ms
	*/
window.debug =
	title: "debug (GameOver)"
	fn: ->
		board.addPlayer!
		board.addPlayer!
		board.startGame!
		board.fields[39].buy board.players.1
		board.players.1.bits = 1bit

		#<- board.once \nextTurn # player 1
		forceDice 1 # Rock Farm
		clickBtn 0 # Roll Dice
		clickBtn 0 # Buy
		clickBtn 0 # End Turn
		console.warn "[TEST1]", {a: []<<<<board._events.buttons}

		<- board.once \nextTurn # player 2
		forceDice 4 # Income Tax
		clickBtn 0 # Roll Dice
		console.warn "[TEST2]", {a: []<<<<board._events.buttons}

/*
	title: "debug (GameOver)"
	fn: ->
		board.addPlayer!
		board.startGame!
		board.fields[39].buy board.players.1
		board.players.1.bits = 1bit

		#<- board.once \nextTurn
		forceDice 1 # Rock Farm
		clickBtn 0 # Roll Dice
		clickBtn 0 # Buy
		clickBtn 0 # End Turn

		<- board.once \nextTurn
		forceDice 1 # Rock Farm
		clickBtn 0 # Roll Dice
		clickBtn 0 # Pay
*/
/*
	title: "debug (openBusinessMenu 2)"
	fn: ->
		board.addPlayer!
		board.startGame!
		player.bits = 50_000bits

		#<- board.once \nextTurn
		forceDice 1, 0 # Rock Farm
		clickBtn 0 # Roll Dice
		clickBtn 0 # Buy
		clickBtn 0 # End Turn

		<- board.once \nextTurn
		forceDice 1, 0 # Rock Farm
		clickBtn 0 # Roll Dice
		clickBtn 0 # Pay
		clickBtn 0 # End Turn

		<- board.once \nextTurn
		forceDice 2, 0 # Ponyville
		clickBtn 0 # Roll Dice
		clickBtn 0 # Buy
		clickBtn 1 # Do Business

/*
	title: "debug (openBusinessMenu)"
	fn: ->
		board.addPlayer!
		board.startGame!
		forceDice 1, 2
		<- sleep 1_000ms
		clickBtn 0 # roll dice
		clickBtn 0 # buy
		clickBtn 1 # openBusinessMenu
*/
/*
	title: "debug (gameover)"
	fn: ->
		board.addPlayer!
		board.startGame!

		player.bits = 10e5
		board.players.1.bits = 100
		for field in board.fields
			if field.buy
				field.buy player

		for field in board.fields
			if field.buy
				while field.buyHouse && field.houses < 5
					field.buyHouse true

		board.endTurn!
		forceDice 1, 2

		<- sleep 1_000ms
		clickBtn 0 # roll dice
		clickBtn 0 # pay 450 bits
		clickBtn 0 # start menu
*/

/*
	title: "debug (doubles)"
	fn: ->
		board.addPlayer!
		board.startGame!
		forceDice 2, 2
		clickBtn 0 # roll dice
*/
/*
	title: "debug (autoplay)"
	fn: ->
		board.addPlayer!
		board.bind \buttons, ->
			board.buttonsField.find \button
				.eq(0) .click!
		board.startGame!
*/
/*
	title: "debug (auctioning)"
	fn: ->
		board.addPlayer!
		board.addPlayer!
		board.addPlayer!
		board.startGame!
		forceDice 1, 2 # Field #3 = Ponyville
		clickBtn 0 # roll dice
		clickBtn 1 # don't buy
*/
/*
	title: "debug (start w/ 50bits)"
	fn: ->
		board.addPlayer!
		board.startBits = 50bits
		board.startGame!
*/