--!strict
local FeatureRuntime = {}
FeatureRuntime.__index = FeatureRuntime
export type Component = { name: string, start: () -> (), stop: () -> () }
export type Runtime = typeof(setmetatable({} :: { components: { Component }, started: { Component }, running: boolean }, FeatureRuntime))
function FeatureRuntime.new(components: { Component }): Runtime return setmetatable({ components = components, started = {}, running = false }, FeatureRuntime) end
function FeatureRuntime.start(self: Runtime): (boolean, string?)
	if self.running then return true, nil end
	for _, item in self.components do
		local ok, reason = pcall(item.start)
		if not ok then
			for index = #self.started, 1, -1 do pcall(self.started[index].stop) end
			table.clear(self.started)
			return false, (`{item.name}: {tostring(reason)}`)
		end
		table.insert(self.started, item)
	end
	self.running = true
	return true, nil
end
function FeatureRuntime.stop(self: Runtime): ()
	for index = #self.started, 1, -1 do pcall(self.started[index].stop) end
	table.clear(self.started); self.running = false
end
return FeatureRuntime
