--!strict
local RunRules=require(script.Parent.DungeonRunRules)
local Config=require(script.Parent.DungeonConfig)
local Rules={}
local kinds={DungeonEntry=true,DungeonReturn=true,DungeonRejoin=true}
function Rules.validate(contract:any,now:number,destination:string,userId:number):(boolean,string?)
	if typeof(contract)~="table" or contract.schemaVersion~=Config.SchemaVersion then return false,"InvalidSchema" end
	if kinds[contract.kind]~=true or typeof(contract.runId)~="string" or #contract.runId<8 or typeof(contract.nonce)~="string" or #contract.nonce<16 then return false,"Malformed" end
	if contract.destinationRole~=destination then return false,"WrongDestination" end
	if typeof(contract.expiresAt)~="number" or contract.expiresAt~=contract.expiresAt or contract.expiresAt<=now then return false,"Expired" end
	local ok,reason=RunRules.validateParticipants(contract.memberUserIds,contract.leaderUserId); if not ok then return false,reason end
	local member=false; for _,id in contract.memberUserIds do member=member or id==userId end; if not member then return false,"NotParticipant" end
	local profile=contract.profiles and contract.profiles[tostring(userId)]; if typeof(profile)~="table" or typeof(profile.transferId)~="string" or typeof(profile.characterId)~="string" then return false,"ProfileIntentMissing" end
	return true,nil
end
function Rules.routingPayload(token:string,contract:any):any return {dungeonTransferVersion=Config.SchemaVersion,dungeonToken=token,runId=contract.runId,kind=contract.kind,destinationRole=contract.destinationRole} end
function Rules.isRoutingPayload(value:any,destination:string):boolean return typeof(value)=="table" and value.dungeonTransferVersion==Config.SchemaVersion and typeof(value.dungeonToken)=="string" and value.destinationRole==destination end
function Rules.rejoinValid(ticket:any,now:number,userId:number):boolean return typeof(ticket)=="table" and ticket.schemaVersion==Config.SchemaVersion and ticket.userId==userId and typeof(ticket.runId)=="string" and typeof(ticket.accessCode)=="string" and ticket.expiresAt>now and (ticket.state=="ACTIVE" or ticket.state=="BOSS") end
return table.freeze(Rules)
