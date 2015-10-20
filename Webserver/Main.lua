﻿#!/bin/luajit

local Require = require

-------------------------------------
--Add library paths
-------------------------------------
package.cpath = package.cpath .. ";../../Webserver/?.dll;../../Webserver/?.so"
package.path = package.path .. ";../../Webserver/?.lua"

-------------------------------------
--Request required libraries
-------------------------------------
				Require("Libraries/Wrap/Wrap")
				Require("Libraries/Table/Table")
InitialEnvironment = Table.Clone(_G)
				Require("Libraries/String/String")
Class = 		Require("Libraries/Class/Class")
FileSystem2 = 	Require("Libraries/FileSystem2/FileSystem2")

Require("socket")

-------------------------------------
--Webserver
-------------------------------------

Webserver = {}
Webserver.Name = "LuaWebserver"
Webserver.Version = {Major = 2, Minor = 0, Revision = 0}

Require("Config")

-------------------------------------
--Webserver Cache
-------------------------------------
Webserver.Cache = {} --cache de arquivos

--Webserver.LineHeaderTimeout = 0.1 --seconds, the max time to wait for a incoming header

-------------------------------------
--Request required classes
-------------------------------------
Language = 		Require("Source/Language")
MIME = 			Require("Source/MIME")
HTTP = 			Require("Source/HTTP")
Connection = 	Require("Source/Connection")
Utilities = 	Require("Source/Utilities")
Template = 		Require("Source/Template")
HTML = 			Require("Source/HTML")
Applications = 	Require("Source/Applications")

GET = 	Require("Source/Methods/GET")

-------------------------------------
--Local variables for this file (faster for Lua)
-------------------------------------
local Socket = socket
local Webserver = Webserver

-------------------------------------
--Initialize Socket
-------------------------------------
Log(String.Format(Language[Webserver.Language][5], ToString(Webserver.Port)))

local Trying = true

local ServerTCP = Socket.tcp()

while ToString(ServerTCP):Substring(1, 3) ~= "tcp" or not ProtectedCall(function() ServerTCP:accept() end) do
	ServerTCP = Socket.tcp()
	ServerTCP:bind('*', Webserver.Port)
	ServerTCP:settimeout(0)
	ServerTCP:listen(Webserver.MaximumWaitingConnections)
end

Log(String.Format(Language[Webserver.Language][6], Webserver.Port))

-------------------------------------
--Webserver
-------------------------------------
Webserver.ServerTCP = ServerTCP
Webserver.Connections = {}

function Webserver.Update(...)
	
	-------------------------------------
	--Receive incoming client connections and put in a Connection object.
	-------------------------------------
	local ClientTCP = ServerTCP:accept()
	
	if ClientTCP then
		ClientTCP:settimeout(0)
		
		local ClientConnection = Connection.New(ClientTCP)
		ClientConnection.Reading = true
		
		local IP, Port = ClientTCP:getpeername()
		Log(String.Format(Language[Webserver.Language][1], ClientConnection:GetID(), ToString(IP), ToString(Port)))
	end
	
	local TimeNow = Socket.gettime()
	
	-------------------------------------
	--Process each Connection object in Webserver.Connections table.
	-------------------------------------
	for Key, ClientConnection in Pairs(Webserver.Connections) do
		
		--Receive incoming data from connection
		do
			local Data, Closed = ClientConnection.ClientTCP:receive("*l")
			
			--If that received any data,
			if Data then
				--When a HTTP header ends, it sends a \n\n, so the incoming data in this case is "", means that the HTTP header
				--was received. As we are reading every incoming line from socket, that will be "".
				--So here, if we did receive the HTTP header,
				if Data == "" then
					
					for Key, Value in IteratePairs(ClientConnection.IncomingData) do
						--print(Value)
					end
					
					--If that HEADER is a GET method.
					if ClientConnection.IncomingData[1]:Substring(1, 3):Trim() == "GET" then
						GET(ClientConnection)
						ClientConnection.IncomingData = {}
					end
				else
				--Else, it's just one more line and we need to add that to incoming data.
					ClientConnection.IncomingData[#ClientConnection.IncomingData + 1] = Data
				end
			end
			
			if Closed == "closed" then
				local IP, Port = ClientConnection.ClientTCP:getpeername()
				Log(String.Format(Language[Webserver.Language][2], ClientConnection:GetID(), ToString(IP), ToString(Port), Closed))
				ClientConnection:Destroy()
				
			elseif Webserver.Timeout > 0 and TimeNow - ClientConnection.CreateTime > Webserver.Timeout then
				--local IP, Port = ClientConnection.ClientTCP:getpeername()
				--Log(String.Format(Language[Webserver.Language][2], ClientConnection:GetID(), ToString(IP), ToString(Port), "server timeout"))
				--ClientConnection:Destroy()
			end
		end
		
		--Send the information from "Send data queue" to client.
		do
			if ClientConnection.Queue[1] then
				local Queue = ClientConnection.Queue[1]
				
				if not Queue.BlockData or ClientConnection.Queue[1].SentBytes == #Queue.BlockData then
					if Type(Queue.Data) == "string" then
						Queue.BlockData = Queue.Data:Substring(Queue.BlockIndex * Webserver.SplitPacketSize + 1, Math.Minimum(Queue.BlockIndex * Webserver.SplitPacketSize + Webserver.SplitPacketSize, Queue.DataSize))
						Queue.BlockIndex = Queue.BlockIndex + 1
					else
						Queue.BlockData = Queue.Data:read(Webserver.SplitPacketSize)
						Queue.BlockIndex = Queue.BlockIndex + 1
					end
					
					ClientConnection.Queue[1].SentBytes = 0
				end
				
				if Queue.BlockData then
					local SentBytes, Err = ClientConnection.ClientTCP:send(Queue.BlockData:Substring(ClientConnection.Queue[1].SentBytes, #Queue.BlockData))
					
					if SentBytes then
						ClientConnection.Queue[1].SentBytes = ClientConnection.Queue[1].SentBytes + SentBytes
						ClientConnection.Queue[1].TotalSentBytes = ClientConnection.Queue[1].TotalSentBytes + SentBytes
					elseif SentBytes == 0 then
						--if it is not sending any bytes, then the client is timing out
					else
						--nil, the client timed out or something else happened.
					end
				end
				
				if not Queue.BlockData or ClientConnection.Queue[1].SentBytes == #Queue.BlockData and Queue.BlockIndex >= Math.Ceil(Queue.DataSize / Webserver.SplitPacketSize) then
					--sometimes the data we are sending from queue is not a string, it might be streaming from a file, so we need to close it.
					if Type(ClientConnection.Queue[1].Data) ~= "string" then
						ClientConnection.Queue[1].Data:close()
					end
					
					--We did finish that item from queue.
					Table.Remove(ClientConnection.Queue, 1)
				end
			end
		end
	end
end

while true do
	Webserver.Update()
end