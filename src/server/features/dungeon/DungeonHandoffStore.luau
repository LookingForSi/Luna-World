--!strict
local MemoryStoreService=game:GetService("MemoryStoreService")
local Config=require(game:GetService("ReplicatedStorage").Shared.dungeon.DungeonConfig)
local handoffs=MemoryStoreService:GetHashMap(Config.HandoffMapName)
local rejoins=MemoryStoreService:GetHashMap(Config.RejoinMapName)
local Store={}
local function safe(callback:()->any):(boolean,any) local ok,value=pcall(callback); return ok,value end
function Store.put(token:string,contract:any,ttl:number?):(boolean,string?) local ok,e=safe(function() handoffs:SetAsync(token,contract,ttl or Config.HandoffTtlSeconds) end); return ok,if ok then nil else "StoreError:"..tostring(e) end
function Store.get(token:string):any local ok,v=safe(function() return handoffs:GetAsync(token) end); return if ok then v else nil end
function Store.remove(token:string):() safe(function() handoffs:RemoveAsync(token) end) end
function Store.putRejoin(userId:number,ticket:any):boolean local ok=safe(function() rejoins:SetAsync(tostring(userId),ticket,Config.RejoinTtlSeconds) end); return ok end
function Store.getRejoin(userId:number):any local ok,v=safe(function() return rejoins:GetAsync(tostring(userId)) end); return if ok then v else nil end
function Store.removeRejoin(userId:number):() safe(function() rejoins:RemoveAsync(tostring(userId)) end) end
return Store
