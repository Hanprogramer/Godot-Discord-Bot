extends Node2D
class_name Discord
signal on_message(message)
signal on_direct_message(message)

var heartbeat = 0
var heartbeat_interval = -1
var current_heartbeat_interval = -1
var heartbeat_last_key = null
var hearbeat_started = false

var verbose = false # log every packets

var logged_in = false
var timer = Timer.new()
var connected = false

# Our WebSocketClient instance
var _client = WebSocketClient.new()
var _HTTPRequest = HTTPRequest.new()

# The URL we will connect to
export var websocket_url = "wss://gateway.discord.gg/?v=9&encoding=json"

class Message:
	var content
	var channel_id
	var message_id
	var guild_id
	
	func _init(_content, _channel_id, _id, _guild_id):
		self.content = _content
		self.channel_id = _channel_id
		self.message_id = _id
		self.guild_id = _guild_id

func _ready():
	add_child(_HTTPRequest)
	add_child(timer)
	_HTTPRequest.connect("request_completed", self, "_on_request_completed")
	_HTTPRequest.request("https://discord.com/api/v9/gateway")
	timer.connect("timeout", self, "_on_Timer_timeout")


func _process(_delta):
	# Call this in _process or _physics_process. Data transfer, and signals
	# emission will only happen when calling this function.
	_client.poll()

func _on_request_completed(result, response_code, _headers, body):
	print("result")
	print(response_code,result)
	var json = JSON.parse(body.get_string_from_utf8())
	print(json.result)

	if not connected:
		# Connect base signals to get notified of connection open, close, and errors.
		_client.connect("connection_closed", self, "_closed")
		_client.connect("connection_error", self, "_closed")
		_client.connect("connection_established", self, "_connected")
		_client.connect("server_close_request", self, "_close_req")
		# This signal is emitted when not using the Multiplayer API every time
		# a full packet is received.
		# Alternatively, you could check get_peer(1).get_available_packets() in a loop.
		_client.connect("data_received", self, "_on_data")

		# Initiate connection to the given URL.
		var err = _client.connect_to_url(websocket_url)
		if err != OK:
			print("Unable to connect")
			set_process(false)
		else:
			connected = true

func _closed(was_clean = false):
	# was_clean will tell you if the disconnection was correctly notified
	# by the remote peer before closing the socket.
	print("Closed, clean: ", was_clean)
	set_process(false)

func _connected(proto = ""):
	# This is called on connection, "proto" will be the selected WebSocket
	# sub-protocol (which is optional)
	print("Connected with protocol: ", proto)
	# You MUST always use get_peer(1).put_packet to send data to server,
	# and not put_packet directly when not using the MultiplayerAPI.

func _close_req(code : int, reason: String):
	print("Close request: ",code,reason)

func _on_data():
	# Print the received packet, you MUST always use get_peer(1).get_packet
	# to receive data from server, and not get_packet directly when not
	# using the MultiplayerAPI.
	var raw = _client.get_peer(1).get_packet().get_string_from_utf8()
	var json = JSON.parse(raw).result
	if verbose: print("Got data from server: ", raw)
	
	if json["op"] == 10:
		print("Initial heartbeat received")
		hearbeat_started = true
		heartbeat_interval = json["d"]["heartbeat_interval"]
		current_heartbeat_interval = int(heartbeat_interval * randf()) / 2.0
		heartbeat = current_heartbeat_interval - 20
		timer.wait_time = 30 # interval shouldn't be set this way, 
		timer.start()
		if not logged_in:
			send_login()
#	if json["op"] == 11: # Hearbeat feedback
	if json["op"] == 0: # Events
		if json["t"] == "READY":
			print("Logged in as: ",json["d"]["user"]["username"])
			logged_in = true
		elif json["t"] == "MESSAGE_CREATE":
			var guild_id = null
			if "guild_id" in json["d"]:
				guild_id = json["d"]["guild_id"]
			var message = Message.new(
				json["d"]["content"],
				json["d"]["channel_id"],
				json["d"]["id"],
				guild_id
			)
			if guild_id != null:
				emit_signal("on_message", message)
			else:
				emit_signal("on_direct_message", message)


func send_heartbeat_pulse():
	# Send a pulse
	var data = {
		"op" : 1,
		"d" : null
	}
	var message = to_json(data).to_utf8()
	var err = _client.get_peer(1).put_packet(message)
	if err != OK:
		print("Error: failed to send heartbeat pulse")

func send_login():
	# Send a pulse
	var data = {
		"op": 2,
		"d": {
			"token": Dotenv.ENV["TOKEN"],
			"intents": 4609,
			"properties": {
				"$os": "linux",
				"$browser": "my_library",
				"$device": "my_library"
			}
		}
	}
	_client.get_peer(1).put_packet(to_json(data).to_utf8())
	print("Logging in...")


func _on_Timer_timeout():
	# Tell discord the bot is alive
	if logged_in:
		send_heartbeat_pulse()


func send_message(channel_id : String, content : String):
	# Perform a POST request. The URL below returns JSON as of writing.
	# Note: Don't make simultaneous requests using a single HTTPRequest node.
	# The snippet below is provided for reference only.
	var body = to_json({
		"content": content,
		"tts": false,
		"embeds": [{
			"title": "Hello, Embed!",
			"description": "This is an embedded message."
		}]
	})
	var headers = [
		"Content-Type: application/json",
		"Authorization: Bot " + Dotenv.ENV["TOKEN"]
	]
	var error = _HTTPRequest.request("https://discord.com/api/v9/channels/%s/messages" % channel_id, headers, true, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
