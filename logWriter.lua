local path, useHTML =  ...
local logDataChannel = love.thread.getChannel "logData"
local signal_shutdown = "__SHUTTING_DOWN__"
local signal_init = "__MANAGE_OLD_LOGS__"
local signal_create = "__CREATE_NEW_LOG__"
local format = string.format

print "Ent logWriter thread started"

function createNewLog(logPath)
	love.filesystem.write(logPath, "")
	print("Created log file at " .. logPath)
end

function manageOldLogs(title, ext, outputPath, maxOldLogs)
	-- move old logs
	local nameStr = "%s.%i." .. ext
	for n = maxOldLogs - 1, 0, -1 do
		local name = format(nameStr, title, n)
		local path = format("%s/%s", outputPath, name)

		if love.filesystem.getInfo(path, "file") then
			local oldLog = love.filesystem.read(path)
			local newName = format(nameStr, title, n + 1)
			love.filesystem.write(format("%s/%s", outputPath, newName), oldLog)
		end
	end

	-- delete oldest log
	local name = format(nameStr, title, maxOldLogs)
	if love.filesystem.remove(format("%s/%s", outputPath, name)) then
		-- local outputf = ent.info or _print
		print("Removed old log file " .. name)
	end
end

while true do
	local str = logDataChannel:demand()
	
	if str == signal_shutdown then
		print "Ent logWriter thread shutting down"
		break

	elseif str == signal_init then
		manageOldLogs(unpack(logDataChannel:demand()))

	elseif str == signal_create then
		createNewLog(logDataChannel:demand())

	else
		love.filesystem.append(path, str)
	end
end