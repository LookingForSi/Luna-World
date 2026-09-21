--!strict
local Store = {}; Store.__index = Store
function Store.new() return setmetatable({ intents = {} }, Store) end
function Store:create(intent: any): (boolean, string?) if self.intents[intent.transferId] then return false,"Duplicate" end; self.intents[intent.transferId]=intent; return true end
function Store:consume(id: string): (any?, string?) local value=self.intents[id]; if not value then return nil,"MissingOrConsumed" end; self.intents[id]=nil; return value end
function Store:remove(id: string): () self.intents[id]=nil end
return Store
