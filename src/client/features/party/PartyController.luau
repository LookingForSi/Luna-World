--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PartyController = {}
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local actionRequest = remotes:WaitForChild("PartyActionRequest") :: RemoteEvent
local snapshotEvent = remotes:WaitForChild("PartySnapshot") :: RemoteEvent
local inviteEvent = remotes:WaitForChild("PartyInviteReceived") :: RemoteEvent
local resultEvent = remotes:WaitForChild("PartyResult") :: RemoteEvent
local connections: { RBXScriptConnection } = {}
local ui: any = nil

function PartyController.invite(userId: number): () actionRequest:FireServer({ action="Invite", targetUserId=userId }) end
function PartyController.accept(inviteId: string): () actionRequest:FireServer({ action="Accept", inviteId=inviteId }) end
function PartyController.decline(inviteId: string): () actionRequest:FireServer({ action="Decline", inviteId=inviteId }) end
function PartyController.leave(): () actionRequest:FireServer({ action="Leave" }) end
function PartyController.kick(userId: number): () actionRequest:FireServer({ action="Kick", targetUserId=userId }) end

function PartyController.start(partyUi: any): ()
	PartyController.stop(); ui = partyUi
	table.insert(connections, snapshotEvent.OnClientEvent:Connect(function(value) if ui then ui.setSnapshot(value) end end))
	table.insert(connections, inviteEvent.OnClientEvent:Connect(function(value) if ui then ui.setInvite(value) end end))
	table.insert(connections, resultEvent.OnClientEvent:Connect(function(value) if ui then ui.showResult(value) end end))
end

function PartyController.stop(): ()
	for _, connection in connections do connection:Disconnect() end
	table.clear(connections); ui = nil
end

return PartyController
