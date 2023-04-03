# Ent
Threaded logging library for [LÖVE](https://love2d.org/).

Ent is designed to be easy to use, configurable, and appends to log files in its own thread, so disk I/O will not block your game code.

## Features
 * Minimal, simple API
 * Threaded to prevent disk I/O lag spikes
 * Outputs to HTML or plaintext
 * Automatically removes old log files (configurable)
 * Customisable log levels
 * Easy to integrate

## Quickstart

Example code:
```lua
-- main.lua
ent = require "ent"

function love.load()
	-- create the logfile & writer thread
	ent.init()
end

function love.keypressed(key)
	-- log keypresses from the player
	ent.echo(key)
end

function love.quit()
	-- close the logfile & writer thread
	ent.close()
end
```
The above will create a HTML log file named after the game's identity string in `[saveDirectory]/logs/` which will also be created if it doesn't exist.

A configuration table can be passed to `ent.init` (see below for options), and 7 log levels are available by default :

 * `ent.echo`
 * `ent.info`
 * `ent.warn`
 * `ent.error`
 * `ent.edit`
 * `ent.client`
 * `ent.server`

 These output functions use the same signature as `string.format` and will format the string accordingly, returning the string that was printed to the log file and console.

## Log Filenames

Log files are saved using the format `name.x.ext`.

The name is provided from the init config (defaults to the game identity string), and the extension is either "log" or "html".

The `x` is substituted with a number. The latest log file will always use `0`, allowing you to simply refresh your editor/browser tab to view the latest log file.

Log management & removal is done in the writer thread, minimising startup cost.

## Love Error Screen

Whilst developing your game you will often encounter crashes and be presented with the Love error screen. The crash screen is actually overridable, via the [love.errorhandler](https://love2d.org/wiki/love.errorhandler) callback.

It is recommended to override this function (using the default implementation of the previously linked page is fine), adding a call to `ent.close` in the handler. This will ensure that ent shuts down properly in the event of a crash (i.e. the HTML footer written, threads closed, etc).

It is also recommended to log the error message with ent before calling `ent.close`.

# API

## `ent.init(config)`
 ### Args
 * `config` (table) : configuration options
 ### Returns
 * `nil`

Intialises the module; creates the writer thread, the log file and its directory, and removes any old log files. 

This function can only be called once - Ent can create a single log file per session.

See below for configuration options.

---

## `ent.close()`
 ### Args
 * none
 ### Returns
 * `nil`

Closes the writer thread and writes any pending data (such as the HTML footer).

It is recommended to call this function in `love.quit` and `love.errorhandler`.

---

## `ent.hasInit()`
 ### Args
 * none
 ### Returns
 * `hasInit` (bool) : whether the system has been initiated already

This function is useful if you implement a soft reset and have a call to `ent.init` in the reset routine.

---

## `output = ent.echo(str, ...)`
 ### Args
 * `str` (string) : string to output, may be formatted by `...`
 * `...` (vararg) : format variables for `str`
 ### Returns
 * `ouput` (string) : the string output to the logfile and console

Outputs the string `str` formatted by `...` to the log file and stdout.
A timestamp and the log level will be prepended to the output.

This function and its cousins are created dynamically from the log levels configuration. Seven variations are available with the default configuration:

 * `ent.echo`
 * `ent.info`
 * `ent.warn`
 * `ent.error`
 * `ent.edit`
 * `ent.client`
 * `ent.server`

 # Configuration

 ## Example config
A configuration table can be passed to `ent.init`
```lua
ent.init {title = "myAwesomeGame", useHTML = true, maxOldLogs = 5}
```

---

## `useHTML` 
Type: bool

Default: `true`

Sets whether to output to HTML or plaintext files.

---

## `outputPath`
Type: string

Default: `"logs"`

Directory where log files will be stored.

---

## `maxOldLogs`
Type: numbers

Default: `10`

Sets the number of logs to keep. Logs in excess of this number will be removed, oldest first.

Set to `0` to disable the auto removal feature.

---

## `title`
Type: string

Default: `love.filesystem.getIdentity()`

Sets the log file title. Avoid using characters that are illegal on some filesystems (such as NTFS).

---

## `print`
Type: function

Default `print`

Sets the function used to output to the console. This is useful if your game uses a custom print function e.g. one that prints to the screen in-game.

---

## `logLevels`
Type: table

Default:
```lua
logLevels = 
{
	echo = {"Echo", "#aaaaaa"},
	info = {"Info", "#2288dd"},
	warn = {"Warning", "#dddd22"},
	error = {"Error!", "#ff44aa"},
	edit = {"Editor", "#88ddbb"},
	client = {"NetClient", "#aaaaaa"},
	server = {"NetServer", "#aaaaaa"},
},
```
Specifies the log levels and their formatting.

Each level entry should be formatted as follows:

`levelID = {prettyString, htmlColour}`

The `levelID` will be used as the identifier for the output function. For example, to make the function `ent.love` that outputs a log level `<3` in pink text:

```lua
ent.init {
	logLevels = 
	{
		love = {"<3", "#ee33aa"}
	}
}
```