--!strict

local ArrivalReadyGate = {}
ArrivalReadyGate.__index = ArrivalReadyGate

export type Gate = typeof(setmetatable(
	{} :: {
		characterReady: boolean,
		arrivalReady: boolean,
		opened: boolean,
		destroyed: boolean,
		onOpen: (() -> ())?,
	},
	ArrivalReadyGate
))

function ArrivalReadyGate.new(onOpen: () -> ()): Gate
	return setmetatable({
		characterReady = false,
		arrivalReady = false,
		opened = false,
		destroyed = false,
		onOpen = onOpen,
	}, ArrivalReadyGate)
end

function ArrivalReadyGate._tryOpen(self: Gate): ()
	if self.destroyed or self.opened or not self.characterReady or not self.arrivalReady then
		return
	end
	self.opened = true
	local onOpen = self.onOpen
	if onOpen ~= nil then
		onOpen()
	end
end

function ArrivalReadyGate.setCharacterReady(self: Gate, ready: boolean): ()
	self.characterReady = ready
	self:_tryOpen()
end

function ArrivalReadyGate.setArrivalReady(self: Gate, ready: boolean): ()
	self.arrivalReady = ready
	self:_tryOpen()
end

function ArrivalReadyGate.isOpen(self: Gate): boolean
	return self.opened
end

function ArrivalReadyGate.destroy(self: Gate): ()
	self.destroyed = true
	self.onOpen = nil
end

return ArrivalReadyGate
