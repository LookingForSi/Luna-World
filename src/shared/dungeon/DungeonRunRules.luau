--!strict
local Config = require(script.Parent.DungeonConfig)
local Rules = {}
local transitions = { CREATED={ENTERING=true,FAILED=true}, ENTERING={ACTIVE=true,FAILED=true}, ACTIVE={BOSS=true,FAILED=true}, BOSS={COMPLETED=true,FAILED=true}, COMPLETED={CLOSED=true}, FAILED={CLOSED=true} }
local function integer(v:any):boolean return typeof(v)=="number" and v==v and v%1==0 and v>0 end
function Rules.validateParticipants(members:any, leader:any):(boolean,string?)
	if typeof(members)~="table" or #members<1 or #members>Config.MaxParticipants or not integer(leader) then return false,"InvalidParticipants" end
	local seen={}; local leaderFound=false
	for _,id in members do if not integer(id) or seen[id] then return false,"InvalidParticipants" end; seen[id]=true; leaderFound = leaderFound or id==leader end
	return leaderFound, if leaderFound then nil else "LeaderNotParticipant"
end
function Rules.canTransition(from:string,to:string):boolean return transitions[from]~=nil and transitions[from][to]==true end
function Rules.advanceEncounter(current:number, eventIndex:number, consumed:boolean):(number,boolean)
	if consumed or eventIndex~=current+1 or eventIndex<1 or eventIndex>4 then return current,false end
	return eventIndex,true
end
function Rules.allDead(participants:{number}, alive:{[number]:boolean}, connected:{[number]:boolean}):boolean
	local found=false; for _,id in participants do if connected[id] then found=true; if alive[id] then return false end end end; return found
end
function Rules.claim(claimed:{[number]:boolean},userId:number):(boolean,{[number]:boolean})
	if claimed[userId] then return false,claimed end; local copy=table.clone(claimed); copy[userId]=true; return true,copy
end
return table.freeze(Rules)
