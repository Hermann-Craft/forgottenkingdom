local TcpClient = require(_G.libDir .. "middleclass")("TcpClient")
local socket = require("socket")

function TcpClient:initialize()
	self.host = nil
	self.port = nil
	self.connected = false
	self.socket = nil
	self.callbacks = {
		recv = nil
	}
	self.handshake = "00000"
	self.ping = nil
end

function TcpClient:setPing(enabled, time, msg)
	if enabled then
		self.ping = {
			time = time,
			msg = msg,
			timer = time
		}
	else
		self.ping = nil
	end
end


function TcpClient:connect(host, port, dns)
	-- Verify our inputs.
	if not host or not port then
		return false, "Invalid arguments"
	end
	-- Resolve dns if needed (dns is true by default).
	if dns ~= false then
		local ip = socket.dns.toip(host)
		if not ip then
			return false, "DNS lookup failed for " .. host
		end
		host = ip
	end
	-- Set it up for ou00000r new connection.
	self:createSocket()
	self.host = host
	self.port = tonumber(port)
	-- Ask our implementation to actually connect.
	local success, err = self:_connect()
	if not success then
		self.host = nil
		self.port = nil
		return false, err
	end
	self.connected = true
	-- Send our handshake if we have one.
	if self.handshake then
		self:send(self.handshake .. "+\n")
	end
	return true
end

function TcpClient:disconnect()
	if self.connected then
		self:send(self.handshake .. "-\n")
		self:_disconnect()
		self.host = nil
		self.port = nil
		self.connected = false
	end
end

function TcpClient:send(data)
	-- Check if we're connected and pass it on.
	if not self.connected then
		return false, "Not connected"
	end
	return self:_send(data)
end

function TcpClient:receive()
	-- Check if we're connected and pass it on.
	if not self.connected then
		return false, "Not connected"
	end
	return self:_receive()
end

function TcpClient:update(dt)
	if not self.connected then return end
	assert(dt, "Update needs a dt!")
	-- First, let's handle ping messages.
	if self.ping then
		self.ping.timer = self.ping.timer + dt
		if self.ping.timer > self.ping.time then
			self:_send(self.ping.msg)
			self.ping.timer = 0
		end
	end
	-- If a recv callback is set, let's grab
	-- all incoming messages. If not, leave
	-- them in the queue.
	if self.callbacks.recv then
		local data, err = self:_receive()
		while data do
			self.callbacks.recv(data)
			data, err = self:_receive()
		end
	end
end


function TcpClient:createSocket()
	self.socket = socket.tcp()
	self.socket:settimeout(0)
end

function TcpClient:_connect()
	self.socket:settimeout(5)
	local success, err = self.socket:connect(self.host, self.port)
	self.socket:settimeout(0)
	return success, err
end

function TcpClient:_disconnect()
	-- Well, that's easy.
	self.socket:shutdown()
end

function TcpClient:_send(data)
	return self.socket:send(data)
end

function TcpClient:_receive()
	local packet = ""
	local data, _, partial = self.socket:receive(16384)
	self.socket:settimeout(0)
	while data do
		packet = packet .. data
		data, _, partial = self.socket:receive(16384)
		self.socket:settimeout(0)
	end
	if not data and partial then
		packet = packet .. partial
	end
	if packet ~= "" then
		return packet
	end
	return nil, "No messages"
end

function TcpClient:setOption(option, value)
	if option == "broadcast" then
		self.socket:setoption("broadcast", not not value)
	end
end

return TcpClient