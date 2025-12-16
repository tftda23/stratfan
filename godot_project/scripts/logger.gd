class_name LoggerScript
extends Node

enum LogLevel { INFO, WARNING, ERROR }

const LOG_FILE_PATH = "res://game.log"
var log_file

func _ready():
	log_file = FileAccess.open(LOG_FILE_PATH, FileAccess.WRITE)
	if log_file == null:
		push_error("Failed to open log file for writing.")

func _log_message(level: LogLevel, message: String):
	var level_str = ""
	match level:
		LogLevel.INFO:
			level_str = "[INFO]"
		LogLevel.WARNING:
			level_str = "[WARNING]"
		LogLevel.ERROR:
			level_str = "[ERROR]"
	
	var timestamp = Time.get_datetime_string_from_system()
	var log_message = "%s %s: %s" % [timestamp, level_str, message]
	
	print(log_message)
	
	if log_file:
		log_file.store_line(log_message)
		log_file.flush()

func log_info(message: String):
	_log_message(LogLevel.INFO, message)

func log_warning(message: String):
	_log_message(LogLevel.WARNING, message)

func log_error(message: String):
	_log_message(LogLevel.ERROR, message)

func _exit_tree():
	if log_file:
		log_info("Logger shutting down.")
		log_file.close()
