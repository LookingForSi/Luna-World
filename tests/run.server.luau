--!strict

local TestRunner = require(script.Parent.TestRunner)

for _, child in script.Parent:GetChildren() do
    if child:IsA("ModuleScript") and string.match(child.Name, "Spec$") then
        local register = require(child)
        register(TestRunner)
    end
end

TestRunner.summary()
