--!strict

local TestRunner = require(script.Parent.TestRunner)
local WorldLayoutSpec = require(script.Parent.WorldLayoutSpec)
local WorldGreyboxBuilderSpec = require(script.Parent.WorldGreyboxBuilderSpec)

local runner = TestRunner.new()
WorldLayoutSpec.register(runner)
WorldGreyboxBuilderSpec.register(runner)

local passed, total = runner:run()
print(string.format("World tests passed: %d/%d", passed, total))
