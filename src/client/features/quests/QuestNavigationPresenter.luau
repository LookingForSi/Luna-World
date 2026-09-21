--!strict
local Presenter={}
function Presenter.describe(objective:any):string return if objective==nil then "" else tostring(objective) end
return table.freeze(Presenter)
