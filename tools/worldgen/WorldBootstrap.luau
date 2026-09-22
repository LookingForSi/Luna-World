--!strict

local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local PlayableWorldBlockout = require(script.Parent.Moonfall.PlayableWorldBlockout)

local WorldBootstrap = {}
local started = false

local function traversalRecovery()
	local server = ServerScriptService:WaitForChild("Server")
	local world = server:WaitForChild("world")
	return require(world:WaitForChild("TraversalRecovery"))
end

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
	traversalRecovery().start(root, spawn)
	started = true
end

function WorldBootstrap.stop(): ()
	if not started then
		return
	end
	started = false
	traversalRecovery().stop()
end

return WorldBootstrap
