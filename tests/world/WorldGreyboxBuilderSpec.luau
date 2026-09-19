--!strict

local ServerStorage = game:GetService("ServerStorage")

local WorldGreyboxBuilder = require(ServerStorage.World.WorldGreyboxBuilder)

type Runner = {
	test: (self: Runner, name: string, callback: () -> ()) -> (),
}

local WorldGreyboxBuilderSpec = {}

local function countChildrenNamed(parent: Instance, name: string): number
	local count = 0
	for _, child in ipairs(parent:GetChildren()) do
		if child.Name == name then
			count += 1
		end
	end
	return count
end

local function findStableId(root: Instance, stableId: string): Instance?
	if root:GetAttribute("StableId") == stableId then
		return root
	end
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:GetAttribute("StableId") == stableId then
			return descendant
		end
	end
	return nil
end

local function withRoot(callback: (Model) -> ())
	local root = Instance.new("Model")
	root.Name = "WorldBuilderTestRoot"
	root.Parent = ServerStorage
	local ok, failure = pcall(callback, root)
	root:Destroy()
	if not ok then
		error(failure, 0)
	end
end

function WorldGreyboxBuilderSpec.register(runner: Runner)
	runner:test("builder creates both world blocks under one managed root", function()
		withRoot(function(root)
			local world = WorldGreyboxBuilder.rebuild(root)
			assert(world.Name == "LunaWorldGreybox")
			assert(world:GetAttribute("ManagedBy") == "LunaWorldGreyboxBuilder")
			assert(world:FindFirstChild("Village") ~= nil)
			assert(world:FindFirstChild("Meadows") ~= nil)
			assert(world:FindFirstChild("MoonfallRoad") ~= nil)
			assert(world:FindFirstChild("GoblinCamp") ~= nil)
			assert(world:FindFirstChild("SpiderHollow") ~= nil)
		end)
	end)

	runner:test("second rebuild replaces only the managed world root", function()
		withRoot(function(root)
			local foreign = Instance.new("Folder")
			foreign.Name = "ForeignOwnerContent"
			foreign.Parent = root

			local first = WorldGreyboxBuilder.rebuild(root)
			local second = WorldGreyboxBuilder.rebuild(root)

			assert(first.Parent == nil, "first managed root must be destroyed after replacement")
			assert(second.Parent == root, "replacement managed root must remain parented")
			assert(foreign.Parent == root, "foreign content must survive rebuild")
			assert(countChildrenNamed(root, "LunaWorldGreybox") == 1, "exactly one managed root must remain")
		end)
	end)

	runner:test("builder refuses conflicting unmanaged world root", function()
		withRoot(function(root)
			local conflict = Instance.new("Model")
			conflict.Name = "LunaWorldGreybox"
			conflict.Parent = root

			local ok = pcall(function()
				WorldGreyboxBuilder.rebuild(root)
			end)

			assert(not ok, "unmanaged name collision must abort rebuild")
			assert(conflict.Parent == root, "conflicting unmanaged root must not be destroyed")
			assert(countChildrenNamed(root, "LunaWorldGreybox") == 1, "failed rebuild must not add another world root")
		end)
	end)

	runner:test("second block exposes required stable landmarks and spawns", function()
		withRoot(function(root)
			local world = WorldGreyboxBuilder.rebuild(root)

			for _, stableId in ipairs({
				"poi_broken_wagon",
				"poi_moonfall_crossroads",
				"poi_old_waystone",
				"poi_goblin_camp",
				"poi_goblin_lookout",
				"poi_spider_hollow",
				"poi_spider_cave_mouth",
				"poi_dark_woodland_gate",
				"entry_dark_woodland",
				"spawn_goblin_scout_road",
				"spawn_goblin_scout_outer",
				"spawn_goblin_warrior_camp",
				"spawn_goblin_camp_elite_future",
				"spawn_spider_hollow_outer",
				"spawn_spider_hollow_mid",
				"spawn_spider_hollow_brood",
			}) do
				assert(findStableId(world, stableId) ~= nil, string.format("missing built stable ID '%s'", stableId))
			end
		end)
	end)

	runner:test("future goblin elite marker remains reservation-only", function()
		withRoot(function(root)
			local world = WorldGreyboxBuilder.rebuild(root)
			local marker = findStableId(world, "spawn_goblin_camp_elite_future")
			assert(marker ~= nil)
			assert(marker:GetAttribute("Purpose") == "FutureEliteReservation")
		end)
	end)
end

return table.freeze(WorldGreyboxBuilderSpec)
