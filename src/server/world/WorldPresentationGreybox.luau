--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.world.WorldLayout)

local PRESENTATION_MODEL_NAME = "Presentation"
local SPAWN_NAME = "WorldSpawn"
local ZONE_TRIGGER_FOLDER_NAME = "ZoneTriggers"

local WorldPresentationGreybox = {}

local function getPoiPosition(stableId: string): Vector3
	for _, definition in ipairs(WorldLayout.PointsOfInterest) do
		if definition.id == stableId then
			return definition.position
		end
	end

	error(string.format("World presentation requires WorldLayout POI '%s'", stableId))
end

local function createSpawn(parent: Instance)
	local squarePosition = getPoiPosition("poi_village_square")
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = SPAWN_NAME
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(squarePosition + Vector3.new(-18, 0.5, 12))
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn:SetAttribute("Purpose", "WorldPreviewSpawn")
	spawn:SetAttribute("ZoneId", "zone_luna_village")
	spawn.Parent = parent
end

local function createZoneTriggers(parent: Instance)
	local zonesById = {}
	for _, zone in ipairs(WorldLayout.Zones) do
		zonesById[zone.id] = zone
	end

	local folder = Instance.new("Folder")
	folder.Name = ZONE_TRIGGER_FOLDER_NAME
	folder.Parent = parent

	for _, volume in ipairs(WorldLayout.ZoneVolumes) do
		local zone = zonesById[volume.zoneId]
		assert(zone ~= nil, string.format("Missing zone definition for '%s'", volume.zoneId))

		local trigger = Instance.new("Part")
		trigger.Name = volume.zoneId
		trigger.Size = volume.size
		trigger.CFrame = CFrame.new(volume.center)
		trigger.Anchored = true
		trigger.CanCollide = false
		trigger.CanTouch = false
		trigger.CanQuery = false
		trigger.Transparency = 1
		trigger:SetAttribute("ZoneId", volume.zoneId)
		trigger:SetAttribute("DisplayName", zone.displayName)
		trigger:SetAttribute("Priority", volume.priority)
		trigger:SetAttribute("MinSafeY", volume.minSafeY)
		trigger.Parent = folder
	end
end

function WorldPresentationGreybox.build(parent: Instance): Model
	local presentation = Instance.new("Model")
	presentation.Name = PRESENTATION_MODEL_NAME
	presentation.Parent = parent

	createSpawn(presentation)
	createZoneTriggers(presentation)

	return presentation
end

return table.freeze(WorldPresentationGreybox)
