--!strict

export type TestCallback = () -> ()
export type TestCase = {
	name: string,
	callback: TestCallback,
}

export type Runner = {
	tests: { TestCase },
	test: (self: Runner, name: string, callback: TestCallback) -> (),
	run: (self: Runner) -> (number, number),
}

local TestRunner = {}
TestRunner.__index = TestRunner

function TestRunner.new(): Runner
	return setmetatable({
		tests = {},
	}, TestRunner) :: any
end

function TestRunner.test(self: Runner, name: string, callback: TestCallback)
	table.insert(self.tests, {
		name = name,
		callback = callback,
	})
end

function TestRunner.run(self: Runner): (number, number)
	local passed = 0
	local failures = {}

	for _, testCase in ipairs(self.tests) do
		local success, failure = pcall(testCase.callback)
		if success then
			passed += 1
		else
			table.insert(failures, string.format("%s: %s", testCase.name, tostring(failure)))
		end
	end

	if #failures > 0 then
		error(string.format("%d world test(s) failed:\n%s", #failures, table.concat(failures, "\n")), 0)
	end

	return passed, #self.tests
end

return TestRunner
