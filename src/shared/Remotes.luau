--[[
	Names of every remote the client and server use to talk.
	The server creates them at startup with Remotes.create(); clients get them with Remotes.get().

	Round state, roles and health travel as attributes instead (see Attributes.luau),
	so a client that joins late still sees the current values.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Remotes"

local Remotes = {}

Remotes.Events = {
	Caught = "Caught", -- server -> client: you were caught by the flashlight
}

Remotes.UnreliableEvents = {
	FlashlightAim = "FlashlightAim", -- seeker client -> server: aim direction, ~10 per second
}

function Remotes.create(): Folder
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	for _, name in Remotes.Events do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	for _, name in Remotes.UnreliableEvents do
		local remote = Instance.new("UnreliableRemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end

	folder.Parent = ReplicatedStorage
	return folder
end

function Remotes.get(name: string): Instance
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name)
end

return Remotes
