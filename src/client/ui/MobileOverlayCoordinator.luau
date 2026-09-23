--!strict

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local MobileOverlayCoordinator = {}
local openWorkspaces: { [Instance]: boolean } = {}
local savedEnabled: { [ScreenGui]: boolean } = {}
local HUD_NAMES = { CombatHud = true, CombatActionBar = true, CombatLog = true, StudioTestPanel = true }
local childAddedConnection: RBXScriptConnection? = nil
local touchConnection: RBXScriptConnection? = nil


local function workspaceDepth(): number
	local depth = 0
	for _ in openWorkspaces do depth += 1 end
	return depth
end

local refresh: () -> ()

refresh = function(): ()
	local hidden = UserInputService.TouchEnabled and next(openWorkspaces) ~= nil
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then return end
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") and HUD_NAMES[child.Name] then
			if hidden then
				if savedEnabled[child] == nil then savedEnabled[child] = child.Enabled end
				child.Enabled = false
			elseif savedEnabled[child] ~= nil then
				child.Enabled = savedEnabled[child]
				savedEnabled[child] = nil
			end
		end
	end
end

local function ensureObservation(): ()
	if touchConnection == nil then
		touchConnection = UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(refresh)
	end
	if childAddedConnection == nil then
		local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if playerGui ~= nil then
			childAddedConnection = playerGui.ChildAdded:Connect(function(child: Instance)
				if child:IsA("ScreenGui") and HUD_NAMES[child.Name] then task.defer(refresh) end
			end)
		end
	end
end

function MobileOverlayCoordinator.setWorkspaceOpen(owner: Instance, isOpen: boolean): ()
	ensureObservation()
	if isOpen then openWorkspaces[owner] = true else openWorkspaces[owner] = nil end
	refresh()
end

function MobileOverlayCoordinator.release(owner: Instance): ()
	ensureObservation()
	openWorkspaces[owner] = nil
	refresh()
end

function MobileOverlayCoordinator.reset(): ()
	table.clear(openWorkspaces)
	refresh()
end

function MobileOverlayCoordinator.getWorkspaceDepth(): number
	return workspaceDepth()
end

return MobileOverlayCoordinator
