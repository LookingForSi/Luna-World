--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Character Lobby owns the first spawn in DevCombined/Lobby flows.
Players.CharacterAutoLoads = false

local PlaceRole = require(ReplicatedStorage.Shared.core.runtime.PlaceRole)
local PlaceRuntime = require(ReplicatedStorage.Shared.core.runtime.PlaceRuntime)
local ServerBootstrap = require(script.Parent.bootstrap.ServerBootstrap)

local LobbyServerManifest = require(script.Parent.bootstrap.manifests.LobbyServerManifest)
local WorldServerManifest = require(script.Parent.bootstrap.manifests.WorldServerManifest)
local DungeonServerManifest = require(script.Parent.bootstrap.manifests.DungeonServerManifest)
local DevCombinedServerManifest = require(script.Parent.bootstrap.manifests.DevCombinedServerManifest)

local role = PlaceRuntime.resolve(game.PlaceId, game.GameId, RunService:IsStudio(), nil)

local manifest
if role == PlaceRole.Lobby then
	manifest = LobbyServerManifest
elseif role == PlaceRole.World then
	manifest = WorldServerManifest
elseif role == PlaceRole.Dungeon then
	manifest = DungeonServerManifest
elseif role == PlaceRole.DevCombined then
	manifest = DevCombinedServerManifest
else
	error(string.format("Unsupported server PlaceRole: %s", tostring(role)))
end

ServerBootstrap.start(manifest)
