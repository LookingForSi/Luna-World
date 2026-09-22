--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RuntimeManifest = require(ReplicatedStorage.Shared.core.runtime.RuntimeManifest)

return function(TestRunner)
	TestRunner.run("runtime manifest starts in order and stops in reverse order once", function()
		local events = {}
		local function component(name: string)
			return {
				name = name,
				start = function()
					table.insert(events, "start:" .. name)
				end,
				stop = function()
					table.insert(events, "stop:" .. name)
				end,
			}
		end

		local stop = RuntimeManifest.start(RuntimeManifest.new("ordered", {
			component("A"),
			component("B"),
			component("C"),
		}))
		assert(table.concat(events, ",") == "start:A,start:B,start:C")
		stop()
		stop()
		assert(table.concat(events, ",") == "start:A,start:B,start:C,stop:C,stop:B,stop:A")
	end)

	TestRunner.run("runtime manifest rolls back only previously started components", function()
		local events = {}
		local manifest = RuntimeManifest.new("rollback", {
			{
				name = "A",
				start = function()
					table.insert(events, "start:A")
				end,
				stop = function()
					table.insert(events, "stop:A")
				end,
			},
			{
				name = "B",
				start = function()
					table.insert(events, "start:B")
					error("boom")
				end,
				stop = function()
					table.insert(events, "stop:B")
				end,
			},
			{
				name = "C",
				start = function()
					table.insert(events, "start:C")
				end,
				stop = function()
					table.insert(events, "stop:C")
				end,
			},
		})

		local ok = pcall(function()
			RuntimeManifest.start(manifest)
		end)
		assert(not ok)
		assert(table.concat(events, ",") == "start:A,start:B,stop:A")
	end)

	TestRunner.run("runtime manifest rejects duplicate component names", function()
		local noop = function() end
		local ok = pcall(function()
			RuntimeManifest.new("duplicates", {
				{ name = "same", start = noop, stop = noop },
				{ name = "same", start = noop, stop = noop },
			})
		end)
		assert(not ok)
	end)
end
