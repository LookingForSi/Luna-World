--!strict

-- This Script exists only in world.project.json. Production/default mapping does
-- not include this directory, so runtime world generation cannot auto-run there.
local WorldBootstrap = require(script.Parent.World.WorldBootstrap)

WorldBootstrap.start()
game:BindToClose(WorldBootstrap.stop)
