local path, useHTML =  ...
local logDataChannel = love.thread.getChannel "logData"
local signal_shutdown = "__SHUTTING_DOWN__"

print "Ent logWriter thread started"

while true do
	local str = logDataChannel:demand()
	
	if str == signal_shutdown then
		print "Ent logWriter thread shutting down"
		break
	end

	love.filesystem.append(path, str)
end