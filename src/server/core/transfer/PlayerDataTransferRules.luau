--!strict

local Rules = {}

function Rules.canMutate(state: string): boolean
	return state == "AccountReady" or state == "CharacterReady"
end

function Rules.canAutosave(state: string): boolean
	return state == "AccountReady" or state == "CharacterReady"
end

function Rules.isCurrentOperation(currentOperationId: number, completedOperationId: number): boolean
	return currentOperationId == completedOperationId
end

return table.freeze(Rules)
