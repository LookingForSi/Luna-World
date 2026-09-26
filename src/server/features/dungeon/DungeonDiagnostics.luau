--!strict
local Config=require(game:GetService("ReplicatedStorage").Shared.dungeon.DungeonConfig)
local D={}
function D.event(name:string,fields:any?):() local parts={Config.DiagnosticsPrefix,name}; if fields then for k,v in fields do table.insert(parts,string.format("%s=%s",k,tostring(v))) end end; print(table.concat(parts," ")) end
function D.reject(name:string,fields:any?):() local parts={Config.DiagnosticsPrefix,"REJECT_"..name}; if fields then for k,v in fields do table.insert(parts,string.format("%s=%s",k,tostring(v))) end end; warn(table.concat(parts," ")) end
return table.freeze(D)
