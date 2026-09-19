--!strict

local PlayableWorldBlockout = require(script.Parent.PlayableWorldBlockout)
local TraversalRecovery = require(script.Parent.TraversalRecovery)

local root, spawn = PlayableWorldBlockout.rebuild()

TraversalRecovery.start(root, spawn)
