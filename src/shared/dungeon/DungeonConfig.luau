--!strict
return table.freeze({
	SchemaVersion=1, DungeonId="selene", MaxParticipants=4,
	HandoffTtlSeconds=120, RunTtlSeconds=1800, RejoinTtlSeconds=300, ReturnTtlSeconds=120, ConsumedTtlSeconds=180,
	PartyReconstructionDelaySeconds=4, TransferRetrySeconds=2, PromptDebounceSeconds=2, ConfirmationTtlSeconds=30,
	EnrageHealthFraction=.35, AoERadius=22, AoETelegraphSeconds=1.8,
	CompletionXP=900, CompletionLuna=450, CompletionItemId="material_fallen_relic",
	EntrancePromptName="RuinsOfSeleneEntrance", ExitPromptName="RuinsOfSeleneExit",
	HandoffMapName="LunaDungeonHandoffsV2", RejoinMapName="LunaDungeonRejoinV1",
	DiagnosticsPrefix="[DungeonSelene]",
})
