--!strict
local ProfileSchema=require(game.ReplicatedStorage.Shared.persistence.ProfileSchema)
local QuestRules=require(game.ReplicatedStorage.Shared.quests.QuestRules)
local UnlockRules=require(game.ReplicatedStorage.Shared.dungeon.DungeonUnlockRules)
local QuestDefinitions=require(game.ReplicatedStorage.Shared.definitions.QuestDefinitions)
return function(TestRunner)
	TestRunner.run("quest chain gates prerequisites and caps objective progress",function()
		local profile=ProfileSchema.createDefault()
		assert(not QuestRules.isAvailable(profile.Quests,"quest_young_wolf_problem"))
		assert(QuestRules.accept(profile,"quest_farm_message","npc_gatekeeper"))
		QuestRules.credit(profile,"TalkToNpc","npc_farmer",10)
		assert(profile.Quests.quest_farm_message.State=="ReadyToTurnIn")
		assert(profile.Quests.quest_farm_message.Progress.talk_farmer==1)
	end)
	TestRunner.run("turn in is atomic and idempotent",function()
		local profile=ProfileSchema.createDefault();assert(QuestRules.accept(profile,"quest_farm_message","npc_gatekeeper"));QuestRules.credit(profile,"TalkToNpc","npc_farmer")
		assert(QuestRules.turnIn(profile,"quest_farm_message","npc_farmer"));assert(profile.Luna==25 and profile.Quests.quest_farm_message.State=="Completed")
		assert(profile.Quests.quest_farm_message.RewardClaimed==true)
		assert(not QuestRules.turnIn(profile,"quest_farm_message","npc_farmer"));assert(profile.Luna==25)
		assert(QuestRules.isAvailable(profile.Quests,"quest_young_wolf_problem"))
	end)
	TestRunner.run("retreat retry does not duplicate a completed quest reward",function()
		local profile=ProfileSchema.createDefault()
		local definition=QuestDefinitions[UnlockRules.QuestId]
		local progress={}
		for _,objective in definition.objectives do progress[objective.id]=objective.required end
		profile.Quests[UnlockRules.QuestId]={State="Completed",Progress=progress}
		assert(UnlockRules.prepareRetry(profile.Quests,definition))
		local beforeLevel,beforeXP,beforeLuna=profile.Level,profile.XP,profile.Luna
		QuestRules.credit(profile,"KillMob","mob_moonbound_warden")
		assert(profile.Quests[UnlockRules.QuestId].State=="ReadyToTurnIn")
		assert(QuestRules.turnIn(profile,UnlockRules.QuestId,definition.turnInNpcId))
		assert(profile.Level==beforeLevel and profile.XP==beforeXP and profile.Luna==beforeLuna)
	end)
end
