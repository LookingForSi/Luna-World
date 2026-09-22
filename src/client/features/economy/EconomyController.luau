--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyController = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local request = remotes:WaitForChild("EconomyRequest") :: RemoteEvent
local snapshotEvent = remotes:WaitForChild("EconomySnapshot") :: RemoteEvent
local openEvent = remotes:WaitForChild("EconomyOpen") :: RemoteEvent
local resultEvent = remotes:WaitForChild("EconomyResult") :: RemoteEvent
local connections: { RBXScriptConnection } = {}

function EconomyController.buy(itemId: string): () request:FireServer("Buy", itemId, 1) end
function EconomyController.sell(instanceId: string): () request:FireServer("Sell", instanceId, 1) end
function EconomyController.sellBatch(selections: { any }): () request:FireServer("SellBatch", selections) end
function EconomyController.craft(craftId: string): () request:FireServer("Craft", craftId, 1) end
function EconomyController.start(onOpen: (string) -> (), onSnapshot: (any) -> (), onResult: (any) -> ()): ()
	EconomyController.stop()
	table.insert(connections, openEvent.OnClientEvent:Connect(onOpen))
	table.insert(connections, snapshotEvent.OnClientEvent:Connect(onSnapshot))
	table.insert(connections, resultEvent.OnClientEvent:Connect(onResult))
end
function EconomyController.stop(): () for _, connection in connections do connection:Disconnect() end; table.clear(connections) end
return EconomyController
