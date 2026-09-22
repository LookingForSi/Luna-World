--!strict

local Components = require(script.Parent.adapters.ExistingClientComponents)
local RunService = game:GetService("RunService")
local MobileOverlayCoordinator = require(script.Parent.Parent.ui.MobileOverlayCoordinator)

local GameplayClientRuntime = {}
GameplayClientRuntime.__index = GameplayClientRuntime

export type Runtime = typeof(setmetatable({
	stopStockHealth = nil :: (() -> ())?,
	stopGameplay = nil :: (() -> ())?,
	diagnosticConnections = {} :: { RBXScriptConnection },
}, GameplayClientRuntime))

function GameplayClientRuntime.new(): Runtime
	return setmetatable({ stopStockHealth = nil, stopGameplay = nil, diagnosticConnections = {} }, GameplayClientRuntime)
end

local DIAGNOSTIC_HUDS = { CombatHud = true, CombatActionBar = true, CombatLog = true, QuestUi = true, InventoryUi = true }

local function observeHud(self: Runtime, gui: ScreenGui): ()
	if not RunService:IsStudio() or not DIAGNOSTIC_HUDS[gui.Name] then return end
	local function logEnabled(): ()
		print(string.format("[GameplayClientRuntime] %s Enabled=%s parent=%s", gui.Name, tostring(gui.Enabled), if gui.Parent ~= nil then gui.Parent:GetFullName() else "nil"))
	end
	logEnabled()
	table.insert(self.diagnosticConnections, gui:GetPropertyChangedSignal("Enabled"):Connect(logEnabled))
	table.insert(self.diagnosticConnections, gui.AncestryChanged:Connect(function()
		print(string.format("[GameplayClientRuntime] %s parent=%s", gui.Name, if gui.Parent ~= nil then gui.Parent:GetFullName() else "nil (cleanup)"))
	end))
	local function observeVisible(instance: Instance): ()
		if not instance:IsA("GuiObject") then return end
		table.insert(self.diagnosticConnections, instance:GetPropertyChangedSignal("Visible"):Connect(function()
			print(string.format("[GameplayClientRuntime] %s.%s Visible=%s", gui.Name, instance:GetFullName(), tostring(instance.Visible)))
		end))
	end
	for _, descendant in gui:GetDescendants() do observeVisible(descendant) end
	table.insert(self.diagnosticConnections, gui.DescendantAdded:Connect(observeVisible))
end

function GameplayClientRuntime.start(self: Runtime): ()
	if self.stopGameplay ~= nil then
		return
	end
	local stockHealth = Components.stockHealthGui()
	local gameplay = Components.gameplay()
	if RunService:IsStudio() then print("[GameplayClientRuntime] start begin") end
	-- The coordinator is process-scoped and outlives feature ScreenGuis in the
	-- DevCombined lobby-to-world transition. Start gameplay from a known depth;
	-- feature-owned workspaces will acquire ownership again when actually opened.
	MobileOverlayCoordinator.reset()
	if RunService:IsStudio() then
		local playerGui = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
		for _, child in playerGui:GetChildren() do if child:IsA("ScreenGui") then observeHud(self, child) end end
		table.insert(self.diagnosticConnections, playerGui.ChildAdded:Connect(function(child: Instance)
			if child:IsA("ScreenGui") then observeHud(self, child) end
		end))
	end
	self.stopStockHealth = stockHealth.stop
	self.stopGameplay = gameplay.stop
	stockHealth.start()
	gameplay.start()
	if RunService:IsStudio() then
		print(string.format("[GameplayClientRuntime] start end workspaceDepth=%d", MobileOverlayCoordinator.getWorkspaceDepth()))
	end
end

function GameplayClientRuntime.stop(self: Runtime): ()
	if self.stopGameplay ~= nil then
		self.stopGameplay()
		self.stopGameplay = nil
	end
	if self.stopStockHealth ~= nil then
		self.stopStockHealth()
		self.stopStockHealth = nil
	end
	for _, connection in self.diagnosticConnections do connection:Disconnect() end
	table.clear(self.diagnosticConnections)
end

return GameplayClientRuntime
