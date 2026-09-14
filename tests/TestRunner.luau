--!strict

local TestRunner = {}

local passed = 0
local failed = 0

function TestRunner.run(name: string, callback: () -> ()): ()
    local ok, err = pcall(callback)
    if ok then
        passed += 1
        print("[PASS] " .. name)
    else
        failed += 1
        warn("[FAIL] " .. name .. ": " .. tostring(err))
    end
end

function TestRunner.summary(): ()
    print(string.format("Tests: %d passed, %d failed", passed, failed))
    assert(failed == 0, string.format("%d test(s) failed", failed))
end

return TestRunner
