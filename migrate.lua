for _, v in pairs(game:GetDescendants()) do
	if (v ~= script and v.Name ~= "BadgerService") and table.find({"Script", "ModuleScript"}, v.ClassName) then
		local src = v.Source .. "\n"
		local changes = {}
		local hasAwardBadge = false

		for line in src:gmatch("(.-)\n") do
			local indent, trimmed = line:match("^(%s*)(.-)%s*$")
			if trimmed:find("AwardBadge%(") then
				local newLine = trimmed:gsub("^(.*)AwardBadge%((.-)%)", function(_, args)
					return string.format('require(game:GetService("ServerStorage"):FindFirstChild("BadgerService")).award(%s)', args)
				end)
				table.insert(changes, indent .. newLine)
				hasAwardBadge = true
			elseif trimmed:find("BadgeAward:Fire%(") then
				local newLine = trimmed:gsub("^(.*)BadgeAward:Fire%((.-)%)", function(_, args)
					return string.format('require(game:GetService("ServerStorage"):FindFirstChild("BadgerService")).award(%s)', args)
				end)
				table.insert(changes, indent .. newLine)
				hasAwardBadge = true
			else
				table.insert(changes, line)
			end
		end

		local modifiedSrc = table.concat(changes, "\n")

		if hasAwardBadge then
			local newScript = Instance.new(v.ClassName)
			newScript.Name = v.Name
			if newScript:IsA("Script") then
				newScript.Enabled = v.Enabled
			end
			newScript.Source = modifiedSrc
			newScript.Parent = v.Parent
			for _, child in ipairs(v:GetChildren()) do
				child.Parent = newScript
			end
			v:Destroy()
			print(`ℹ️ Migrated {newScript:GetFullName()}`)
		end
	end
end
