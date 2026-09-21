--!strict
local TeleportService = game:GetService("TeleportService")
local Gateway = {}; Gateway.__index = Gateway
function Gateway.new() return setmetatable({}, Gateway) end
function Gateway:teleport(placeId: number, players: {Player}, payload: any): (boolean, string?)
	local options=Instance.new("TeleportOptions"); options:SetTeleportData(payload)
	local ok, reason=pcall(function() TeleportService:TeleportAsync(placeId, players, options) end)
	return ok, if ok then nil else tostring(reason)
end
return Gateway
