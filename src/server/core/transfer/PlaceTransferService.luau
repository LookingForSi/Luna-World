--!strict
local HttpService=game:GetService("HttpService")
local Rules=require(game:GetService("ReplicatedStorage").Shared.core.transfer.TransferIntentRules)
local Service={}; Service.__index=Service
function Service.new(deps:any) return setmetatable({data=deps.playerData,intents=deps.intentStore,gateway=deps.gateway,clock=deps.clock or os.time,ttl=deps.ttl or 60,pending={}},Service) end
function Service:begin(player:Player, characterId:string, destination:any):(boolean,string?)
	if self.pending[player] then return false,"TransferInProgress" end
	if typeof(destination)~="table" or typeof(destination.placeId)~="number" or destination.placeId<=0 then return false,"InvalidDestination" end
	if self.data:getActiveCharacterId(player)~=characterId then return false,"CharacterNotOwnedOrActive" end
	self.pending[player]=true
	local ok,reason=self.data:beginTransfer(player); if not ok then self.pending[player]=nil; return false,reason end
	local intent={transferVersion=1,transferId=HttpService:GenerateGUID(false),userId=player.UserId,characterId=characterId,destinationRole=destination.role,entryPointId=destination.entryPointId,expiresAt=self.clock()+self.ttl}
	local made,makeReason=self.intents:create(intent); if not made then self.data:recoverTransfer(player); self.pending[player]=nil; return false,makeReason end
	local sent,sendReason=self.gateway:teleport(destination.placeId,{player},Rules.routingPayload(intent))
	if not sent then self.intents:remove(intent.transferId); self.data:recoverTransfer(player); self.pending[player]=nil; return false,sendReason end
	return true
end
function Service:recover(player:Player):() if self.pending[player] then self.data:recoverTransfer(player); self.pending[player]=nil end end
return Service
