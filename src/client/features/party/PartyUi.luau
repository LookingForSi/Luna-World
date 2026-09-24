--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ProgressionConfig = require(ReplicatedStorage.Shared.config.ProgressionConfig)
local HudLayout = require(script.Parent.Parent.Parent.ui.HudLayout)

local PartyUi = {}
local localPlayer = Players.LocalPlayer
local gui: ScreenGui? = nil
local panel: Frame? = nil
local memberList: Frame? = nil
local playerList: Frame? = nil
local hud: Frame? = nil
local inviteDialog: Frame? = nil
local statusLabel: TextLabel? = nil
local snapshot: any = nil
local callbacks: any = nil
local connections: { RBXScriptConnection } = {}
local observed: { RBXScriptConnection } = {}

local function label(parent: Instance, text: string, pos: UDim2, size: UDim2, textSize: number?): TextLabel
	local value = Instance.new("TextLabel"); value.BackgroundTransparency=1; value.Position=pos; value.Size=size
	value.Text=text; value.TextColor3=Color3.fromRGB(235,235,240); value.Font=Enum.Font.GothamMedium
	value.TextSize=textSize or 14; value.TextXAlignment=Enum.TextXAlignment.Left; value.Parent=parent; return value
end

local function button(parent: Instance, text: string, pos: UDim2, size: UDim2, callback: () -> ()): TextButton
	local value=Instance.new("TextButton"); value.Position=pos; value.Size=size; value.Text=text; value.Font=Enum.Font.GothamBold
	value.TextSize=13; value.TextColor3=Color3.fromRGB(245,245,245); value.BackgroundColor3=Color3.fromRGB(63,70,83); value.BorderSizePixel=0; value.Parent=parent
	local corner=Instance.new("UICorner"); corner.CornerRadius=UDim.new(0,4); corner.Parent=value
	table.insert(connections,value.Activated:Connect(callback)); return value
end

local function clearRows(container: Instance): ()
	for _, child in container:GetChildren() do if child:GetAttribute("PartyRow") then child:Destroy() end end
end

local function playerName(player: Player?): string return if player then (player:GetAttribute("CharacterNickname") or player.DisplayName) else "Offline" end

local function renderHud(): ()
	if hud == nil then return end
	clearRows(hud); for _, connection in observed do connection:Disconnect() end; table.clear(observed)
	local ids = if snapshot and typeof(snapshot.memberUserIds)=="table" then snapshot.memberUserIds else {}
	local row = 0
	for _, userId in ids do
		if userId == localPlayer.UserId then continue end
		row += 1; if row > 3 then break end
		local player=Players:GetPlayerByUserId(userId); local holder=Instance.new("Frame"); holder:SetAttribute("PartyRow",true)
		holder.BackgroundColor3=Color3.fromRGB(22,24,31); holder.BackgroundTransparency=.18; holder.BorderSizePixel=0
		holder.Position=UDim2.fromOffset(0,(row-1)*38); holder.Size=UDim2.fromOffset(230,34); holder.Parent=hud
		local title=label(holder,(if snapshot.leaderUserId==userId then "◆ " else "")..playerName(player),UDim2.fromOffset(7,1),UDim2.new(1,-14,0,16),12)
		local health=label(holder,"",UDim2.fromOffset(7,16),UDim2.new(1,-14,0,16),11); health.TextColor3=Color3.fromRGB(184,211,179)
		local function update(): ()
			local character=if player then player.Character else nil; local humanoid=if character then character:FindFirstChildOfClass("Humanoid") else nil
			local level=if player then player:GetAttribute(ProgressionConfig.LevelAttribute) else nil
			title.Text=(if snapshot.leaderUserId==userId then "◆ " else "")..playerName(player).."  LVL "..tostring(level or "—")
			health.Text=if humanoid and humanoid.Health<=0 then "DEAD" elseif humanoid then string.format("HP %d / %d",humanoid.Health,humanoid.MaxHealth) else "HP —"
		end
		update()
		if player then
			table.insert(observed,player.CharacterAdded:Connect(function() task.defer(renderHud) end))
			local humanoid=if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
			if humanoid then table.insert(observed,humanoid.HealthChanged:Connect(update)) end
		end
	end
	hud.Visible=row>0
end

local function renderPanel(): ()
	if panel == nil or memberList == nil or playerList == nil then return end
	clearRows(memberList); clearRows(playerList)
	local ids=if snapshot and typeof(snapshot.memberUserIds)=="table" then snapshot.memberUserIds else {}
	for index,userId in ids do local p=Players:GetPlayerByUserId(userId); local row=label(memberList,(if snapshot.leaderUserId==userId then "◆ " else "")..playerName(p),UDim2.fromOffset(0,(index-1)*25),UDim2.new(1,0,0,23),13); row:SetAttribute("PartyRow",true) end
	local canInvite=#ids==0 or (snapshot.leaderUserId==localPlayer.UserId and #ids<4); local y=0
	if canInvite then for _,p in Players:GetPlayers() do if p~=localPlayer and not table.find(ids,p.UserId) then
		local row=label(playerList,playerName(p),UDim2.fromOffset(0,y),UDim2.new(1,-82,0,28),13); row:SetAttribute("PartyRow",true)
		local invite=button(playerList,"Invite",UDim2.new(1,-76,0,y),UDim2.fromOffset(72,26),function() callbacks.invite(p.UserId) end); invite:SetAttribute("PartyRow",true); y+=30
	end end end
end

function PartyUi.setSnapshot(value: any): () snapshot=value; renderPanel(); renderHud() end
function PartyUi.setInvite(value: any): ()
	if inviteDialog == nil or typeof(value)~="table" then return end
	if value.cancelled then inviteDialog.Visible=false; return end
	inviteDialog.Visible=true; local text=inviteDialog:FindFirstChild("Message") :: TextLabel; text.Text=tostring(value.inviterName).." приглашает в группу"
	inviteDialog:SetAttribute("InviteId",value.inviteId)
end
function PartyUi.showResult(value: any): () if statusLabel and typeof(value)=="table" then statusLabel.Text=if value.ok then "Готово" else tostring(value.reason or "Отклонено") end end
function PartyUi.toggle(): () if panel then panel.Visible=not panel.Visible; renderPanel() end end

function PartyUi.start(actions: any): ()
	PartyUi.stop(); callbacks=actions
	gui=Instance.new("ScreenGui"); gui.Name="PartyUi"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=false; gui.Parent=localPlayer:WaitForChild("PlayerGui")
	button(gui,"ГРУППА",UDim2.fromOffset(24,210),UDim2.fromOffset(108,34),PartyUi.toggle)
	panel=Instance.new("Frame"); panel.Name="PartyPanel"; panel.AnchorPoint=Vector2.new(.5,.5); panel.Position=UDim2.fromScale(.5,.5); panel.Size=UDim2.fromOffset(440,350); panel.Visible=false; panel.Parent=gui; HudLayout.applyPanelStyle(panel)
	label(panel,"ГРУППА",UDim2.fromOffset(18,10),UDim2.new(1,-70,0,30),18); table.insert(connections,HudLayout.makeCloseButton(panel).Activated:Connect(function() if panel then panel.Visible=false end end))
	memberList=Instance.new("Frame"); memberList.BackgroundTransparency=1; memberList.Position=UDim2.fromOffset(18,54); memberList.Size=UDim2.fromOffset(190,130); memberList.Parent=panel
	playerList=Instance.new("Frame"); playerList.BackgroundTransparency=1; playerList.Position=UDim2.fromOffset(222,54); playerList.Size=UDim2.fromOffset(200,220); playerList.Parent=panel
	statusLabel=label(panel,"",UDim2.fromOffset(18,285),UDim2.fromOffset(270,28),12)
	button(panel,"ПОКИНУТЬ",UDim2.new(1,-132,1,-48),UDim2.fromOffset(114,30),function() callbacks.leave() end)
	hud=Instance.new("Frame"); hud.Name="PartyHud"; hud.BackgroundTransparency=1; hud.Position=UDim2.fromOffset(24,252); hud.Size=UDim2.fromOffset(230,114); hud.Parent=gui
	inviteDialog=Instance.new("Frame"); inviteDialog.Name="InviteDialog"; inviteDialog.AnchorPoint=Vector2.new(.5,.5); inviteDialog.Position=UDim2.fromScale(.5,.42); inviteDialog.Size=UDim2.fromOffset(330,130); inviteDialog.Visible=false; inviteDialog.Parent=gui; HudLayout.applyPanelStyle(inviteDialog)
	local message=label(inviteDialog,"",UDim2.fromOffset(16,14),UDim2.new(1,-32,0,40),14); message.Name="Message"
	button(inviteDialog,"ПРИНЯТЬ",UDim2.fromOffset(16,76),UDim2.fromOffset(140,34),function() local id=inviteDialog and inviteDialog:GetAttribute("InviteId"); if typeof(id)=="string" then callbacks.accept(id) end; if inviteDialog then inviteDialog.Visible=false end end)
	button(inviteDialog,"ОТКЛОНИТЬ",UDim2.fromOffset(174,76),UDim2.fromOffset(140,34),function() local id=inviteDialog and inviteDialog:GetAttribute("InviteId"); if typeof(id)=="string" then callbacks.decline(id) end; if inviteDialog then inviteDialog.Visible=false end end)
	if UserInputService.TouchEnabled and workspace.CurrentCamera then hud.Position=UDim2.fromOffset(8,126); hud.Size=UDim2.fromOffset(200,102) end
	table.insert(connections,Players.PlayerAdded:Connect(renderPanel)); table.insert(connections,Players.PlayerRemoving:Connect(function() task.defer(renderPanel); task.defer(renderHud) end))
	renderPanel(); renderHud()
end

function PartyUi.stop(): ()
	for _,c in connections do c:Disconnect() end; for _,c in observed do c:Disconnect() end
	table.clear(connections); table.clear(observed); if gui then gui:Destroy() end
	gui=nil; panel=nil; memberList=nil; playerList=nil; hud=nil; inviteDialog=nil; statusLabel=nil; snapshot=nil; callbacks=nil
end

return PartyUi
