--!strict
local ArrivalReadyGate = {}
ArrivalReadyGate.__index = ArrivalReadyGate

export type Gate = typeof(setmetatable({} :: { characterReady: boolean, arrivalReady: boolean, opened: boolean, callback: (() -> ())? }, ArrivalReadyGate))

function ArrivalReadyGate.new(callback: () -> ()): Gate
	return setmetatable({ characterReady = false, arrivalReady = false, opened = false, callback = callback }, ArrivalReadyGate)
end

function ArrivalReadyGate.setCharacterReady(self: Gate, ready: boolean): () self.characterReady = ready; self:_tryOpen() end
function ArrivalReadyGate.setArrivalReady(self: Gate, ready: boolean): () self.arrivalReady = ready; self:_tryOpen() end
function ArrivalReadyGate._tryOpen(self: Gate): ()
	if not self.opened and self.characterReady and self.arrivalReady then self.opened = true; (self.callback :: () -> ())() end
end
function ArrivalReadyGate.isOpen(self: Gate): boolean return self.opened end
function ArrivalReadyGate.destroy(self: Gate): () self.callback = nil end
return ArrivalReadyGate
