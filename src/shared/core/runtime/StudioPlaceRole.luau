--!strict

local PlaceRole = require(script.Parent.PlaceRole)

local StudioPlaceRole = {}

function StudioPlaceRole.read(container: Instance): PlaceRole.PlaceRole?
	local marker = container:FindFirstChild("StudioPlaceRole")
	if marker == nil then
		return nil
	end
	assert(marker:IsA("StringValue"), "StudioPlaceRole marker must be a StringValue")
	if marker.Value == "" then
		return nil
	end
	return PlaceRole.assertValid(marker.Value)
end

return table.freeze(StudioPlaceRole)
