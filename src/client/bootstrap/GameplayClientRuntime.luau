--!strict

local Components = require(script.Parent.adapters.ExistingClientComponents)

local GameplayClientRuntime = {}
GameplayClientRuntime.__index = GameplayClientRuntime

export type Runtime = typeof(setmetatable({
	stopStockHealth = nil :: (() -> ())?,
	stopGameplay = nil :: (() -> ())?,
}, GameplayClientRuntime))

function GameplayClientRuntime.new(): Runtime
	return setmetatable({ stopStockHealth = nil, stopGameplay = nil }, GameplayClientRuntime)
end

function GameplayClientRuntime.start(self: Runtime): ()
	if self.stopGameplay ~= nil then
		return
	end
	local stockHealth = Components.stockHealthGui()
	local gameplay = Components.gameplay()
	self.stopStockHealth = stockHealth.stop
	self.stopGameplay = gameplay.stop
	stockHealth.start()
	gameplay.start()
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
end

return GameplayClientRuntime
