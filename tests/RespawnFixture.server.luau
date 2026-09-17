--!strict

-- Test-only world interface. Production intentionally has no fabricated coordinate fallback;
-- the Luna Village world supplies the tagged anchor when that branch is integrated.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RespawnConfig = require(ReplicatedStorage.Shared.config.RespawnConfig)

if #CollectionService:GetTagged(RespawnConfig.AnchorTag) == 0 then
	local anchor = Instance.new("Part")
	anchor.Name = "TestLunaVillageRespawnAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(4, 1, 4)
	anchor.CFrame = CFrame.new(0, 5, 0)
	anchor:SetAttribute(RespawnConfig.AnchorIdAttribute, "test_luna_village")
	anchor:SetAttribute(RespawnConfig.SettlementIdAttribute, RespawnConfig.LunaVillageSettlementId)
	anchor.Parent = workspace
	CollectionService:AddTag(anchor, RespawnConfig.AnchorTag)
end
