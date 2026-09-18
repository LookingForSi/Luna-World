--!strict

return table.freeze({
	DataStoreName = "LunaWorldPlayerData",
	StudioStoreSuffix = "_studio",
	AutosaveSeconds = 60,
	LeaseTimeoutSeconds = 300,
	MaxAttempts = 3,
	RetryBackoffSeconds = 0.25,
})
