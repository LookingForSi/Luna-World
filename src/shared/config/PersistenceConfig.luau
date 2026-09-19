--!strict

return table.freeze({
	DataStoreName = "LunaWorldPlayerData",
	StudioStoreSuffix = "_studio",
	-- Real Studio DataStore persistence stays opt-in until Task 24 owner checkpoint.
	-- The live progression path still runs through PlayerDataService using a volatile
	-- session store, so Studio does not require API Services just to test gameplay.
	UseDataStoreInStudio = false,
	AutosaveSeconds = 60,
	LeaseTimeoutSeconds = 300,
	MaxAttempts = 3,
	RetryBackoffSeconds = 0.25,
})
