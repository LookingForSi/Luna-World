--!strict

local RuntimeComponent = {}

export type RuntimeComponent = {
	name: string,
	start: () -> (),
	stop: () -> (),
}

return table.freeze(RuntimeComponent)
