--!strict

-- Test-project-only adapter for the runtime contract's explicit target-removal cases.
--
-- The characterization script intentionally tests "target disappeared without dying".
-- Destroying the only Grey Wolf, however, bypasses MobService's normal Died/respawn
-- lifecycle and leaves the rest of the long runtime contract with no registered
-- Grey Wolf to reuse. For the test project we therefore model removal as a temporary
-- unparent/reparent: the target really leaves Workspace (so production cleanup paths
-- are exercised), but the same server-registered model can be reused by later phases.
-- Production gameplay code is not changed by this fixture.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CombatConfig = require(ReplicatedStorage.Shared.config.CombatConfig)
local MobService = require(ServerScriptService.Server.services.MobService)

local testRemotes = ReplicatedStorage:WaitForChild("TestRemotes")
local skillRuntimeCommand = testRemotes:WaitForChild("SkillRuntimeCommand") :: RemoteFunction
local autoAttackRuntimeCommand = testRemotes:WaitForChild("AutoAttackRuntimeCommand") :: RemoteFunction

local function wrapTemporaryRemoval(remote: RemoteFunction): ()
	task.spawn(function()
		local original: any = nil
		while remote.Parent ~= nil and original == nil do
			original = remote.OnServerInvoke
			if original == nil then task.wait() end
		end
		if original == nil then return end

		remote.OnServerInvoke = function(sender: Player, command: unknown, ...: any): any
			if command ~= "RemoveTarget" then
				return original(sender, command, ...)
			end

			local entityId = sender:GetAttribute(CombatConfig.SelectedTargetAttribute)
			assert(typeof(entityId) == "string", "RemoveTarget test command requires a selected mob")
			local model = MobService.getByEntityId(entityId)
			assert(model ~= nil and model.Parent ~= nil, "RemoveTarget test command requires a registered live mob")

			model.Parent = nil
			task.delay(0.5, function()
				if model.Parent == nil then
					model.Parent = workspace
				end
			end)
			return true
		end
	end)
end

wrapTemporaryRemoval(skillRuntimeCommand)
wrapTemporaryRemoval(autoAttackRuntimeCommand)
