--!strict

local RuntimeComponent = require(script.Parent.RuntimeComponent)

local RuntimeManifest = {}

export type RuntimeManifest = {
	name: string,
	components: { RuntimeComponent.RuntimeComponent },
}

local function validateComponent(component: RuntimeComponent.RuntimeComponent, seen: { [string]: boolean }): ()
	assert(type(component.name) == "string" and component.name ~= "", "Runtime component requires a non-empty name")
	assert(type(component.start) == "function", string.format("Runtime component %s has no start()", component.name))
	assert(type(component.stop) == "function", string.format("Runtime component %s has no stop()", component.name))
	assert(not seen[component.name], string.format("Duplicate runtime component: %s", component.name))
	seen[component.name] = true
end

function RuntimeManifest.validate(manifest: RuntimeManifest): ()
	assert(type(manifest.name) == "string" and manifest.name ~= "", "Runtime manifest requires a name")
	assert(type(manifest.components) == "table", "Runtime manifest requires components")

	local seen: { [string]: boolean } = {}
	for _, component in manifest.components do
		validateComponent(component, seen)
	end
end

function RuntimeManifest.new(name: string, components: { RuntimeComponent.RuntimeComponent }): RuntimeManifest
	local manifest: RuntimeManifest = {
		name = name,
		components = components,
	}
	RuntimeManifest.validate(manifest)
	return manifest
end

function RuntimeManifest.start(manifest: RuntimeManifest): () -> ()
	RuntimeManifest.validate(manifest)

	local started: { RuntimeComponent.RuntimeComponent } = {}
	local stopped = false

	local function stop(): ()
		if stopped then
			return
		end
		stopped = true

		for index = #started, 1, -1 do
			local component = started[index]
			local ok, stopError = pcall(component.stop)
			if not ok then
				warn(string.format("Runtime component %s stop failed: %s", component.name, tostring(stopError)))
			end
		end
		table.clear(started)
	end

	for _, component in manifest.components do
		local ok, startError = pcall(component.start)
		if not ok then
			stop()
			error(
				string.format(
					"Runtime manifest %s failed while starting %s: %s",
					manifest.name,
					component.name,
					tostring(startError)
				),
				2
			)
		end
		table.insert(started, component)
	end

	return stop
end

return table.freeze(RuntimeManifest)
