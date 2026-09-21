--!strict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Validator=require(ReplicatedStorage.Shared.world.WorldLayoutValidator)
local Manifest=require(ReplicatedStorage.Shared.world.MoonfallRegionManifest)
local Runtime={}
function Runtime.start():() local ok,reason=Validator.validate(require(ReplicatedStorage.Shared.world.WorldLayout)); assert(ok,`Invalid authored Moonfall anchors: {tostring(reason)}`) end
function Runtime.stop():() end
function Runtime.getManifest():any return Manifest end
return table.freeze(Runtime)
