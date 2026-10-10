--[[
	Runs the unit tests for pure modules with Lune: `lune run tests/run`
	Each spec returns a table of named test functions.
]]

local process = require("@lune/process")

local specs = {
	Cone = require("./Cone.spec"),
	RoundLogic = require("./RoundLogic.spec"),
}

local passed, failed = 0, 0

for specName, tests in specs do
	for testName, test in tests do
		local ok, err = pcall(test)
		if ok then
			passed += 1
			print(`PASS {specName}: {testName}`)
		else
			failed += 1
			print(`FAIL {specName}: {testName}\n  {err}`)
		end
	end
end

print(`\n{passed} passed, {failed} failed`)
process.exit(if failed > 0 then 1 else 0)
