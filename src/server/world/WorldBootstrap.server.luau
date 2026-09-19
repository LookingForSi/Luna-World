--!strict

local Workspace = game:GetService("Workspace")

local PlayableWorldBlockout = require(script.Parent.PlayableWorldBlockout)
local TraversalRecovery = require(script.Parent.TraversalRecovery)

local function suppressTemplateBaseplate()
	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate ~= nil and baseplate:IsA("BasePart") then
		-- World preview is designed to run from a clean Baseplate template as well.
		-- Keep the object intact, but prevent it from showing through river/terrain
		-- depressions or catching a player underneath the authored world.
		baseplate.Transparency = 1
		baseplate.CanCollide = false
		baseplate.CanTouch = false
		baseplate.CanQuery = false
	end
end

suppressTemplateBaseplate()

local root, spawn = PlayableWorldBlockout.rebuild()

TraversalRecovery.start(root, spawn)
