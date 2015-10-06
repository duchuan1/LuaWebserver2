-------------------------------------
--LuaWebserver Configuration file
-------------------------------------

-------------------------------------
--Language
-------------------------------------

Webserver.Language = "pt"

-------------------------------------
--Connection
-------------------------------------

Webserver.Port = 9091

Webserver.MaximumWaitingConnections = 500

Webserver.KeepAlive = false

Webserver.SplitPacketSize = 1024 * 4 --bytes

Webserver.Timeout = 5 --seconds, 0 disables it

Webserver.Index = {"index.html", "index.htm", "index.lua"}

-------------------------------------
--Cache
-------------------------------------

Webserver.CacheFileMaximumSize = 1024 * 1024 * 8 --bytes

Webserver.CacheMaximumSize = 1024 * 1024 * 512 --bytes

-------------------------------------
--WWW
-------------------------------------

Webserver.WWW = "../../www/"