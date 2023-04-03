local reqVersion = "11.3"
assert(love.isVersionCompatible(reqVersion), "Ent requires Love version " .. reqVersion .. " or greater.")

local ent = {}
local insert, concat = table.insert, table.concat
local format = string.format
local getTime = love.timer.getTime
local osDate = os.date

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------
local config
local defaultConfig = 
{
	-- log levels: identifier = {pretty string, HTML colour}
	-- a function will be created for each log level using the provided identifier
	-- e.g. log.echo("messge")
	logLevels = 
	{
		echo   = {"Echo", "#aaaaaa"},
		info   = {"Info", "#2288dd"},
		warn   = {"Warning", "#dddd22"},
		error  = {"Error!", "#ff44aa"},
		edit   = {"Editor", "#88ddbb"},
		client = {"NetClient", "#aaaaaa"},
		server = {"NetServer", "#aaaaaa"},
	},

	-- if false, log files will be plaintext
	useHTML = true,

	-- automatically delete old logs. Disables deletion if set to 0
	maxOldLogs = 10,

	-- directory to save logs
	outputPath = "logs",

	-- custom log title
	title = love.filesystem.getIdentity(),

	-- print function
	print = print,

	-- number of non-breaking-spaces to replace tabs with in HTML output
	htmlTabWidth = 4

}

-------------------------------------------------------------------------------
-- Setup
-------------------------------------------------------------------------------
-- paths
local srcPath = (...):gsub("%.", "/")
local writerPath = srcPath .. "/logWriter.lua"
local templatePath = srcPath .. "/template.html"

-- thread
local logWriter = love.thread.newThread(writerPath)
local logWriterChannel = love.thread.getChannel "logData"
local signal_shutdown = "__SHUTTING_DOWN__"
local signal_init = "__MANAGE_OLD_LOGS__"
local signal_create = "__CREATE_NEW_LOG__"

-- misc
local initTime = getTime()
local hasInit
local templateTail, bodyIndent
local _print

-------------------------------------------------------------------------------
-- File I/O
-------------------------------------------------------------------------------
local function generateStyleCSS(indent)
	local output = {}
	local logLevelCSS =
	{
		indent .. ".%s",
		"{",
		"\tcolor: %s;",
		"}\n\n"
	}
	local css = concat(logLevelCSS, "\n" .. indent)
	for k, level in pairs(config.logLevels) do
		insert(output, css:format(k, level[2]))
	end

	return concat(output)
end

local function loadTemplate(logName, logPath)
	local head, tail = {}, {}
	local output = head
	local bodyIndent
	local sections = 
	{
		{"{style}", function(indent) return generateStyleCSS(indent) end},
		{"{title}",  function(indent) return format("%s<title>%s</title>", indent, logName) end},
		{"{header", function(indent) return format("%s<h1>Ent Log: %s</h1>", indent, logName) end},
		{"{body}", function(indent) bodyIndent = indent output = tail return indent .. "<!-- Start of Log -->\n" end}
	}
	
	local currentSection = 1
	for line in love.filesystem.lines(templatePath) do
		if output == head and line:match(sections[currentSection][1]) then
			-- for clean output, copy indentation to prepend to output
			local indent = line:match "(%s+){"

			-- generate the content
			insert(output, sections[currentSection][2](indent))
			currentSection = currentSection + 1
		else
			insert(output, line)
		end
	end

	return head, tail, bodyIndent
end

local function createLog(logName, logPath)
	logWriterChannel:push(signal_create)
	logWriterChannel:push(logPath)

	if config.useHTML then
		local head, tail, indent = loadTemplate(logName)
		logWriterChannel:push(concat(head, "\n"))
		-- these values are needed later
		templateTail = concat(tail, "\n")
		bodyIndent = indent
	end
end

local function manageOldLogs(title, ext)
	if config.maxOldLogs < 1 then
		return
	end

	logWriterChannel:push(signal_init)
	logWriterChannel:push {title, ext, config.outputPath, config.maxOldLogs}
end

-------------------------------------------------------------------------------
-- API
-------------------------------------------------------------------------------

function ent.init(inConfig)
	assert(not hasInit, "Attempt to re-initialise log.")
	hasInit = true

	-- create config
	config = inConfig and setmetatable(inConfig, {__index = defaultConfig}) or defaultConfig
	
	-- ensure sane config
	assert(type(config.print) == "function", "Log config error: print must be a function")
	_print = config.print

	local numLevels = 0
	for _ in pairs(config.logLevels) do
		numLevels = numLevels + 1
	end
	if numLevels < 1 then
		_print "Log config warning: no log levels in config"
	end

	if config.title:match("[/<>:\"\\|%?%*%c]") then
		_print "Log config warning: log title contains characters that may be unsupported on some systems (probably Windows NTFS)"
	end

	if config.maxOldLogs == 1 then
		_print "Log config warning: maxOldLogs set to 1"
	end

	-- remove trailing slash from logPath
	config.outputPath = config.outputPath:match "^(.-)/?$"
	
	-- create log level functions
	for id, level in pairs(config.logLevels) do
		ent[id] = function(str, ...)
			return ent.print(id, level[1], str, ...)
		end
	end

	-- generate log name
	local ext = config.useHTML and "html" or "log"
	local logName = format("%s.0.%s", config.title, ext)
	local logPath = format("%s/%s", config.outputPath, logName)

	-- ensure that the ouput dir exists
	local dirInfo = love.filesystem.getInfo(config.outputPath, "directory")
	if not dirInfo then
		assert(love.filesystem.createDirectory(config.outputPath), "Error creating log output directory")
		_print "Created log output directory"
	end
	
	-- boot up the thread
	logWriter:start(logPath)

	--create the file
	manageOldLogs(config.title, ext)
	createLog(logName, logPath)
end

function ent.hasInit()
	return hasInit
end

function ent.print(levelid, level, str, ...)
	str = format(tostring(str), ...)
	
	local time = getTime() - initTime
	local timeStr = osDate("%H:%M:%S:", time)
	local nanoSecs = (time * 1000) % 1000
	local logStr = string.format("[%s%03d] (%s) %s", timeStr, nanoSecs, level, str)
	_print(logStr)

	if config.useHTML then
		logStr = format('%s<p>\n%s\t<span class="time">[%s%03d]</span>&nbsp;<span class="%s">(%s)&nbsp;%s</span>\n%s</p>\n', 
		bodyIndent,
		bodyIndent,
		timeStr,
		nanoSecs,
		levelid,
		level,
		str:gsub("\t", string.rep("&nbsp;", config.htmlTabWidth)),
		bodyIndent)
	else
		logStr = logStr .. "\n"
	end

	logWriterChannel:push(logStr)
	return logStr
end

function ent.close()
	if config.useHTML then
		logWriterChannel:push(templateTail)
	end

	logWriterChannel:push(signal_shutdown)
	logWriter:wait()
	logWriter:release()
end

return ent