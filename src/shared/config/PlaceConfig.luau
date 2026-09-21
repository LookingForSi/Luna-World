--!strict

-- Deployment IDs intentionally remain empty until physical test/production
-- Places are created in Gate D. Studio uses the explicit DevCombined default.
local PlaceConfig = {
	StudioDefaultRole = "DevCombined",
	Deployments = {},
}

return table.freeze(PlaceConfig)
