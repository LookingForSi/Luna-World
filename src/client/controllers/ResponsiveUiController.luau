--!strict

local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")

local ResponsiveLayout = require(script.Parent.Parent.ui.ResponsiveLayout)
local HudLayout = require(script.Parent.Parent.ui.HudLayout)

local ResponsiveUiController = {}
local stopObserving: (() -> ())? = nil
local descendantConnection: RBXScriptConnection? = nil

local function frame(gui: Instance, name: string): Frame?
	local value = gui:FindFirstChild(name, true)
	return if value ~= nil and value:IsA("Frame") then value else nil
end

local function applyHud(playerGui: PlayerGui, metrics: ResponsiveLayout.Metrics): ()
	-- The HUD owns the full physical viewport on phones. Device/CoreUI insets are
	-- sampled only to protect the edge anchors that can actually meet a cutout;
	-- they never become a second global shrinking canvas.
	local topLeftInset, bottomRightInset = GuiService:GetGuiInset()
	local leftEdge = math.max(HudLayout.MobileEdgeMargin, topLeftInset.X + HudLayout.MobileEdgeMargin)
	local rightEdge = math.max(HudLayout.MobileEdgeMargin, bottomRightInset.X + HudLayout.MobileEdgeMargin)

	local hud = playerGui:FindFirstChild("CombatHud")
	if hud ~= nil then
		local playerPanel = frame(hud, "PlayerStatusFrame")
		local target = frame(hud, "TargetFrame")
		if ResponsiveLayout.isSmallTouch(metrics) and hud:GetAttribute("CompactMobile") == true then
			if playerPanel ~= nil then
				playerPanel.AnchorPoint = Vector2.new(1, 0)
				playerPanel.Position = UDim2.new(1, -rightEdge, 0, HudLayout.MobileEdgeMargin)
				playerPanel.Size = UDim2.fromOffset(HudLayout.MobilePlayerStatusSize.X, HudLayout.MobilePlayerStatusSize.Y)
			end
			if target ~= nil then
				target.Position = UDim2.new(0.5, 0, 0, HudLayout.MobileEdgeMargin)
				target.Size = UDim2.fromOffset(HudLayout.MobileTargetSize.X, HudLayout.MobileTargetSize.Y)
			end
		else
			if playerPanel ~= nil then
				playerPanel.AnchorPoint = Vector2.new(1, 0)
				playerPanel.Position = UDim2.new(1, -24, 0, 24)
				playerPanel.Size = UDim2.fromOffset(260, 190)
			end
			if target ~= nil then target.Position = UDim2.new(0.5, 0, 0, 24); target.Size = UDim2.fromOffset(280, 86) end
		end
	end

	local logGui = playerGui:FindFirstChild("CombatLog")
	local log = if logGui ~= nil then frame(logGui, "CombatLogFrame") else nil
	if log ~= nil and logGui ~= nil and ResponsiveLayout.isSmallTouch(metrics) and logGui:GetAttribute("CompactMobile") == true then
		log.Position = UDim2.new(0, math.max(HudLayout.MobileCombatLogJoystickClearance, leftEdge), 1, -HudLayout.MobileEdgeMargin)
		log.Size = UDim2.fromOffset(HudLayout.MobileCombatLogCollapsedSize.X, HudLayout.MobileCombatLogCollapsedSize.Y)
		local entries = log:FindFirstChild("Entries")
		if entries ~= nil and entries:IsA("GuiObject") then entries.Visible = false end
	end

	local actionsGui = playerGui:FindFirstChild("CombatActionBar")
	if actionsGui ~= nil then
		local actions = frame(actionsGui, "PrimaryActions")
		local skills = frame(actionsGui, "SkillBar")
		if ResponsiveLayout.isSmallTouch(metrics) and actionsGui:GetAttribute("CompactMobile") == true then
			if actions ~= nil then
				actions.Position = UDim2.new(1, -rightEdge, 1, -HudLayout.MobileEdgeMargin)
				actions.Size = UDim2.fromOffset(HudLayout.MobileActionBarSize.X, HudLayout.MobileActionBarSize.Y)
				local constraint = actions:FindFirstChildOfClass("UISizeConstraint")
				if constraint ~= nil then
					-- UISizeConstraint has no Enabled property. Writing it used to throw
					-- during touch startup, aborting GameplayClientRuntime after the HUD
					-- had mounted; ClientApplication then correctly cleaned the HUD up.
					constraint.MinSize = Vector2.zero
					constraint.MaxSize = Vector2.new(10000, 10000)
				end
			end
			if skills ~= nil then
				skills.Position = UDim2.new(0.5, 0, 1, -HudLayout.MobileEdgeMargin)
				skills.AnchorPoint = Vector2.new(0.5, 1)
				skills.Size = UDim2.fromOffset(HudLayout.MobileSkillBarSize.X, HudLayout.MobileSkillBarSize.Y)
			end
		end
	end
end

local function apply(metrics: ResponsiveLayout.Metrics): ()
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui == nil then return end
	applyHud(playerGui, metrics)
end

function ResponsiveUiController.start(): ()
	ResponsiveUiController.stop()
	stopObserving = ResponsiveLayout.observe(apply)
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	descendantConnection = playerGui.DescendantAdded:Connect(function()
		task.defer(function() apply(ResponsiveLayout.metrics(workspace.CurrentCamera)) end)
	end)
end

function ResponsiveUiController.stop(): ()
	if stopObserving ~= nil then stopObserving(); stopObserving = nil end
	if descendantConnection ~= nil then descendantConnection:Disconnect(); descendantConnection = nil end
end

return ResponsiveUiController
