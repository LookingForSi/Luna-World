--!strict
local MemoryStoreService=game:GetService("MemoryStoreService")
local Config=require(game:GetService("ReplicatedStorage").Shared.dungeon.DungeonConfig)
local map=MemoryStoreService:GetSortedMap("LunaDungeonHandoffV1")
local Store={}
function Store.put(token:string,contract:any):() map:SetAsync(token,contract,Config.HandoffTtlSeconds) end
function Store.get(token:string):any local ok,value=pcall(function() return map:GetAsync(token) end); return if ok then value else nil end
return Store
