--!strict
local Players=game:GetService("Players")
local HttpService=game:GetService("HttpService")
local TeleportService=game:GetService("TeleportService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Config=require(ReplicatedStorage.Shared.dungeon.DungeonConfig)
local PlaceConfig=require(ReplicatedStorage.Shared.config.PlaceConfig)
local PlaceRole=require(ReplicatedStorage.Shared.core.runtime.PlaceRole)
local PartyService=require(script.Parent.Parent.party.PartyService)
local PlayerDataService=require(script.Parent.Parent.Parent.services.PlayerDataService)
local Store=require(script.Parent.DungeonHandoffStore)
local Service={}; local connection:RBXScriptConnection?=nil; local transferring:{[number]:boolean}={}
local function begin(leader:Player):()
	if transferring[leader.UserId] or not PlayerDataService.isReady(leader) then return end
	local snapshot=PartyService.getSnapshot(leader); local members=if snapshot then snapshot.memberUserIds else {leader.UserId}; local leaderId=if snapshot then snapshot.leaderUserId else leader.UserId
	if leaderId~=leader.UserId or #members>Config.MaxParticipants then return end
	local players={}; for _,id in members do local p=Players:GetPlayerByUserId(id); if not p or not PlayerDataService.isReady(p) then return end; table.insert(players,p) end
	local placeId=PlaceConfig.getPlaceId(game.GameId,PlaceRole.Dungeon); if not placeId then if RunService:IsStudio() then return end; warn("Ruins of Selene destination is not configured"); return end
	for _,p in players do if transferring[p.UserId] then return end end; for _,p in players do transferring[p.UserId]=true end
	local runId=HttpService:GenerateGUID(false); local token=HttpService:GenerateGUID(false)..HttpService:GenerateGUID(false); local now=workspace:GetServerTimeNow()
	local contract={schemaVersion=Config.SchemaVersion,runId=runId,nonce=token,sourceRole="World",destinationRole="Dungeon",leaderUserId=leaderId,memberUserIds=table.clone(members),issuedAt=now,expiresAt=now+Config.HandoffTtlSeconds}
	local ok,err=pcall(function() Store.put(token,contract); local code=TeleportService:ReserveServer(placeId); local options=Instance.new("TeleportOptions"); options.ReservedServerAccessCode=code; options:SetTeleportData({schemaVersion=Config.SchemaVersion,runId=runId,token=token,destinationRole="Dungeon"}); TeleportService:TeleportAsync(placeId,players,options) end)
	if not ok then for _,p in players do transferring[p.UserId]=nil end; warn("Dungeon transfer failed: "..tostring(err)) end
end
function Service.start():()
	local entrance=workspace:FindFirstChild(Config.EntrancePromptName,true)
	if not entrance then
		local marker=Instance.new("Part"); marker.Name=Config.EntrancePromptName; marker.Size=Vector3.new(8,10,2); marker.Position=Vector3.new(35,5,35); marker.Anchored=true; marker.Color=Color3.fromRGB(70,55,95); marker.Parent=workspace
		local created=Instance.new("ProximityPrompt"); created.ActionText="Войти в Ruins of Selene"; created.ObjectText="Печать Селены"; created.MaxActivationDistance=12; created.Parent=marker; entrance=marker
	end
	local prompt=entrance:FindFirstChildOfClass("ProximityPrompt"); if prompt then connection=prompt.Triggered:Connect(begin) end
end
function Service.stop():() if connection then connection:Disconnect(); connection=nil end; table.clear(transferring) end
return Service
