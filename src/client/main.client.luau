--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlaceRole = require(ReplicatedStorage.Shared.core.runtime.PlaceRole)
local PlaceRuntime = require(ReplicatedStorage.Shared.core.runtime.PlaceRuntime)
local StudioPlaceRole = require(ReplicatedStorage.Shared.core.runtime.StudioPlaceRole)
local ClientApplication = require(script.Parent.bootstrap.ClientApplication)
local LobbyClientRuntime = require(script.Parent.bootstrap.LobbyClientRuntime)
local GameplayClientRuntime = require(script.Parent.bootstrap.GameplayClientRuntime)
local LocalPlaceTransitionAdapter = require(script.Parent.bootstrap.transport.LocalPlaceTransitionAdapter)
local TeleportTransitionAdapter = require(script.Parent.bootstrap.transport.TeleportTransitionAdapter)
local ExistingClientComponents = require(script.Parent.bootstrap.adapters.ExistingClientComponents)

local isStudio = RunService:IsStudio()
local studioRole = if isStudio then StudioPlaceRole.read(ReplicatedStorage) else nil
local role = PlaceRuntime.resolve(game.PlaceId, game.GameId, isStudio, studioRole)

if not PlaceRole.isValid(role) then
	error(string.format("Unsupported client PlaceRole: %s", tostring(role)))
end

local selectCharacter = ExistingClientComponents.requestCharacterSelection
local adapter = if role == PlaceRole.DevCombined
	then LocalPlaceTransitionAdapter.new(selectCharacter)
	else TeleportTransitionAdapter.new(selectCharacter)
local application = ClientApplication.new(LobbyClientRuntime.new(), GameplayClientRuntime.new(), adapter)
local ok, reason = application:start({ mode = role })
if not ok then
	error(string.format("Client application failed to start for %s: %s", role, tostring(reason)))
end

script.Destroying:Connect(function()
	application:stop()
end)
