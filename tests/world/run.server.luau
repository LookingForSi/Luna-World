--!strict

local TestRunner = require(script.Parent.TestRunner)
local WorldLayoutSpec = require(script.Parent.WorldLayoutSpec)

local runner = TestRunner.new()
WorldLayoutSpec.register(runner)

local passed, total = runner:run()
print(string.format("World layout tests passed: %d/%d", passed, total))
