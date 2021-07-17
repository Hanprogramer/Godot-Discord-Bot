extends Node2D

onready var discord : Discord = $Discord

func _on_Discord_on_message(message):
	print(message.content)
	discord.send_message(message.channel_id, message.content)
