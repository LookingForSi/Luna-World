--!strict

local ServerScriptService = game:GetService("ServerScriptService")

-- This Script is mapped only by world.project.json. Production Place projects
-- never map the Worldgen folder or this auto-running preview entrypoint.
local WorldBootstrap = require(ServerScriptService.Worldgen.WorldBootstrap)

WorldBootstrap.start()
game:BindToClose(WorldBootstrap.stop)
