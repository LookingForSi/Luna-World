--!strict
local RunRules=require(script.Parent.DungeonRunRules)
local Config=require(script.Parent.DungeonConfig)
local Rules={}
function Rules.validate(contract:any, now:number, destination:string, userId:number):(boolean,string?)
	if typeof(contract)~="table" or contract.schemaVersion~=Config.SchemaVersion then return false,"InvalidSchema" end
	if typeof(contract.runId)~="string" or #contract.runId<8 or typeof(contract.nonce)~="string" or #contract.nonce<16 then return false,"Malformed" end
	if contract.destinationRole~=destination then return false,"WrongDestination" end
	if typeof(contract.expiresAt)~="number" or contract.expiresAt~=contract.expiresAt or contract.expiresAt<now then return false,"Expired" end
	local ok,reason=RunRules.validateParticipants(contract.memberUserIds,contract.leaderUserId); if not ok then return false,reason end
	for _,id in contract.memberUserIds do if id==userId then return true,nil end end
	return false,"NotParticipant"
end
return table.freeze(Rules)
