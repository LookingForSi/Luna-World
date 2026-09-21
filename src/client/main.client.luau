--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlaceRole = require(ReplicatedStorage.Shared.core.runtime.PlaceRole)
local PlaceRuntime = require(ReplicatedStorage.Shared.core.runtime.PlaceRuntime)
local ClientBootstrap = require(script.Parent.bootstrap.ClientBootstrap)

local LobbyClientManifest = require(script.Parent.bootstrap.manifests.LobbyClientManifest)
local WorldClientManifest = require(script.Parent.bootstrap.manifests.WorldClientManifest)
local DungeonClientManifest = require(script.Parent.bootstrap.manifests.DungeonClientManifest)
local DevCombinedClientManifest = require(script.Parent.bootstrap.manifests.DevCombinedClientManifest)

local role = PlaceRuntime.resolve(game.PlaceId, game.GameId, RunService:IsStudio(), nil)

local manifest
if role == PlaceRole.Lobby then
	manifest = LobbyClientManifest
elseif role == PlaceRole.World then
	manifest = WorldClientManifest
elseif role == PlaceRole.Dungeon then
	manifest = DungeonClientManifest
elseif role == PlaceRole.DevCombined then
	manifest = DevCombinedClientManifest
else
	error(string.format("Unsupported client PlaceRole: %s", tostring(role)))
end

local stop = ClientBootstrap.start(manifest)
script.Destroying:Connect(stop)
