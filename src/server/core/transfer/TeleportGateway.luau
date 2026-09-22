--!strict

local TeleportService = game:GetService("TeleportService")

local Gateway = {}
Gateway.__index = Gateway

function Gateway.new(): any
	return setmetatable({}, Gateway)
end

function Gateway:teleport(placeId: number, players: { Player }, payload: any): (boolean, string?)
	local options = Instance.new("TeleportOptions")
	options:SetTeleportData(payload)
	local ok, reason = pcall(function()
		TeleportService:TeleportAsync(placeId, players, options)
	end)
	return ok, if ok then nil else tostring(reason)
end

function Gateway:onInitFailed(callback: (Player, string, any?) -> ()): RBXScriptConnection
	return TeleportService.TeleportInitFailed:Connect(function(player, result, message, _placeId, options)
		local payload = nil
		if options ~= nil then
			pcall(function() payload = options:GetTeleportData() end)
		end
		callback(player, string.format("%s:%s", result.Name, message), payload)
	end)
end

return Gateway
