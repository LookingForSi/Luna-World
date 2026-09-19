--!strict

local LunaVillageGreybox = require(script.Parent.LunaVillageGreybox)
local LunaMeadowsGreybox = require(script.Parent.LunaMeadowsGreybox)
local MoonfallRoadGreybox = require(script.Parent.MoonfallRoadGreybox)
local GoblinCampGreybox = require(script.Parent.GoblinCampGreybox)
local SpiderHollowGreybox = require(script.Parent.SpiderHollowGreybox)

local MANAGED_ROOT_NAME = "LunaWorldGreybox"
local MANAGED_BY_ATTRIBUTE = "ManagedBy"
local MANAGED_BY_VALUE = "LunaWorldGreyboxBuilder"

local WorldGreyboxBuilder = {}

local function findManagedRoots(workspaceRoot: Instance): { Instance }
	local managedRoots = {}

	for _, child in ipairs(workspaceRoot:GetChildren()) do
		if child.Name == MANAGED_ROOT_NAME then
			local managedBy = child:GetAttribute(MANAGED_BY_ATTRIBUTE)
			if managedBy ~= MANAGED_BY_VALUE then
				error(string.format(
					"Cannot rebuild Luna World greybox: '%s' already contains '%s' with %s=%s. "
						.. "Rename or remove that object before rebuilding; no Workspace objects were deleted.",
					workspaceRoot:GetFullName(),
					MANAGED_ROOT_NAME,
					MANAGED_BY_ATTRIBUTE,
					tostring(managedBy)
				))
			end

			table.insert(managedRoots, child)
		end
	end

	return managedRoots
end

function WorldGreyboxBuilder.rebuild(workspaceRoot: Instance?): Model
	local targetRoot = workspaceRoot or workspace
	local existingManagedRoots = findManagedRoots(targetRoot)

	local replacement = Instance.new("Model")
	replacement.Name = MANAGED_ROOT_NAME
	replacement:SetAttribute(MANAGED_BY_ATTRIBUTE, MANAGED_BY_VALUE)

	LunaVillageGreybox.build(replacement)
	LunaMeadowsGreybox.build(replacement)
	MoonfallRoadGreybox.build(replacement)
	GoblinCampGreybox.build(replacement)
	SpiderHollowGreybox.build(replacement)

	replacement.Parent = targetRoot
	for _, managedRoot in ipairs(existingManagedRoots) do
		managedRoot:Destroy()
	end

	return replacement
end

return table.freeze(WorldGreyboxBuilder)
