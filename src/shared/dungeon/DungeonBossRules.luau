--!strict
local Config=require(script.Parent.DungeonConfig)
local Rules={}
function Rules.phase(health:number,maxHealth:number,enraged:boolean):string
	if health<=0 then return "DEAD" end
	if enraged or (maxHealth>0 and health/maxHealth<=Config.EnrageHealthFraction) then return "ENRAGED" end
	return "BASE"
end
function Rules.aoeHits(origin:Vector3,position:Vector3,alive:boolean,radius:number?):boolean
	if not alive then return false end; local d=position-origin; return d.X*d.X+d.Y*d.Y+d.Z*d.Z <= (radius or Config.AoERadius)^2
end
function Rules.selectTarget(ordered:{number},alive:{[number]:boolean},present:{[number]:boolean}):number?
	for _,id in ordered do if alive[id] and present[id] then return id end end; return nil
end
function Rules.acceptTelegraph(eventGeneration:number,currentGeneration:number,bossAlive:boolean):boolean
	return bossAlive and eventGeneration==currentGeneration
end
return table.freeze(Rules)
