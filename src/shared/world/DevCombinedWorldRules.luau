--!strict

local Contract = require(script.Parent.MoonfallAuthoringContract)

local Rules = {}

export type Mode = "Generate" | "ReuseAuthored"

function Rules.resolve(rootCount: number, managedBy: any): (Mode?, string?)
	if rootCount < 0 or rootCount % 1 ~= 0 then return nil, "InvalidRootCount" end
	if rootCount > 1 then return nil, "CompetingRoots" end
	if rootCount == 0 then return "Generate", nil end
	if managedBy == Contract.GeneratorManagedBy then return "Generate", nil end
	if managedBy == Contract.AuthoredManagedBy then return "ReuseAuthored", nil end
	return nil, "UnknownOwnership"
end

return table.freeze(Rules)
