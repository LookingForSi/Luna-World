--!strict

local Workspace = game:GetService("Workspace")

local PlayableWorldBlockout = require(script.Parent.PlayableWorldBlockout)
local TraversalRecovery = require(script.Parent.TraversalRecovery)

local WorldBootstrap = {}
local started = false

local function suppressTemplateBaseplate(): ()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate ~= nil and baseplate:IsA("BasePart") then
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		baseplate.CanTouch = false
		baseplate.CanQuery = false
	end
end

function WorldBootstrap.start(): ()
	if started then
		return
	end

	suppressTemplateBaseplate()
	local root, spawn = PlayableWorldBlockout.rebuild()
	TraversalRecovery.start(root, spawn)
	started = true
end

function WorldBootstrap.stop(): ()
	if not started then
		return
	end
	started = false
	TraversalRecovery.stop()
end

return WorldBootstrap
