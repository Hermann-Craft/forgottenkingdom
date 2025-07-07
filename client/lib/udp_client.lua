local UdpClient = require(_G.libDir .. "middleclass")("UdpClient")
local socket = require("socket")
local Serializer = require(_G.libDir .. "serializer")

function UdpClient:initialize()
	-- 'Initialize' our variables
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
function UdpClient:createSocket()
	self.socket = socket.udp()
	self.socket:settimeout(0)
end

function UdpClient:_connect()
	-- We're connectionless,
	-- guaranteed success!
	return true
end

function UdpClient:_disconnect()
	-- Well, that's easy.
end

function UdpClient:_send(data)
	return self.socket:sendto(data, self.host, self.port)
end

function UdpClient:_receive()
	local data, ip, port = self.socket:receivefrom(65536)
	if ip == self.host and port == self.port then
		return data
	end
	return false, data and "Unknown remote sent data." or ip
end

function UdpClient:setOption(option, value)
	if option == "broadcast" then
		self.socket:setoption("broadcast", not not value)
	end
end

function UdpClient:setPing(enabled, time, msg)
	-- If ping is enabled, create a self.ping
	-- and set the time and the message in it,
	-- but most importantly, keep the time.
	-- If disabled, set self.ping to nil.
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

function UdpClient:connect(host, port, dns)
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
	-- Set it up for our new connection.
	self:createSocket()
	self.host = host
	self.port = tonumber(port)
    self.socket:setsockname(self.host, self.port)
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
        local test, state = self:send(self.handshake .. "+\n")
		local packet = _G.bitser.dumps({
			id = "connection",
			data = {
				email = _G.user.email,
				token = _G.user.token,
				characterName = _G.user.selectedCharacter
			}
		})
        local test, state = self:send(packet)
	end
	return true
end

function UdpClient:disconnect()
	if self.connected then
		self:send(self.handshake .. "-\n")
		local packet = _G.bitser.dumps({
			id = "disconnection",
			data = {
				email = _G.user.email
			}
		})
		self:send(packet)
		self:_disconnect()
		self.host = nil
		self.port = nil
		self.connected = false
	end
end

function UdpClient:send(data)
	-- Check if we're connected and pass it on.
    
	if not self.connected then
		return false, "Not connected"
	end
    return self:_send(data)
end

function UdpClient:receive()
	-- Check if we're connected and pass it on.
	if not self.connected then
		return false, "Not connected"
	end
	return self:_receive()
end

function UdpClient:update(dt)
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


return UdpClient
