--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local RemoveTableDupes = require(ReplicatedStorage.Shared.Utils.Utilities).RemoveTableDupes

local StackModule = require(script.StackModule)
local Constants = require(script.Constants)

export type ConfigurationsTypes = {
	StartingNode: number,
	MazeSize: number,
	WallColor: Color3,
	CellSize: number,
	Material: Enum.Material,
	Thickness: number,
	Height: number,
	StartingVector: Vector3,
	Seed: Random,
	Algorithm: "Recursive" | "Prims",
}

local MazeService = Knit.CreateService({
	Name = "MazeService",
	Client = {},
})

local function RemoveWalls(CurrentNode, NextNode)
	local X = CurrentNode.X - NextNode.X
	local Y = CurrentNode.Y - NextNode.Y
	if X == -1 then
		CurrentNode:RemoveWall("Right")
		NextNode:RemoveWall("Left")
	end
	if X == 1 then
		CurrentNode:RemoveWall("Left")
		NextNode:RemoveWall("Right")
	end
	if Y == 1 then
		CurrentNode:RemoveWall("Down")
		NextNode:RemoveWall("Up")
	end
	if Y == -1 then
		CurrentNode:RemoveWall("Up")
		NextNode:RemoveWall("Down")
	end
end

local function BatchMiddlePoints(...) end
function MazeService:InitMaze(Configurations)
	-------------------------MAZE INITIALIZATION-----------------------------
	local Index = 1
	for y = 1, Configurations.MazeSize do
		for x = 1, Configurations.MazeSize do
			local NewNode = self.NodeModule.new(x, y, Configurations.MazeSize)
			table.insert(self.Nodes, NewNode)
			Index += 1
			if x ~= Configurations.MazeSize then
				NewNode.Walls.Right = false
			end
			if y ~= Configurations.MazeSize then
				NewNode.Walls.Up = false
			end
		end
	end
	---------------------------------------------------------------------------

	-------------------------------Maze Configs----------------------------------
	self.Configurations.MazeSize = Configurations.MazeSize or Constants.MazeSize
	self.Configurations.StartingNode = Configurations.StartingNode or Constants.StartingNode
	self.Configurations.StartingVector = Configurations.StartingVector or Constants.StartingVector
	self.Configurations.Thickness = Configurations.Thickness or Constants.Thickness
	self.Configurations.Height = Configurations.Height or Constants.Height
	self.Configurations.Seed = Configurations.Seed or Constants.Seed
	self.Configurations.WallColor = Configurations.WallColor or Constants.WallColor
	self.Configurations.CellSize = Configurations.CellSize or Constants.CellSize
	self.Configurations.Material = Configurations.Material or Constants.Material
	self.Configurations.Algorithm = Configurations.Algorithm or Constants.Algorithm
	self.Seed = Random.new(self.Configurations.Seed)
	--------------------------------------------------------------------------------

	if self.Configurations.Algorithm == "Backtrack" then
		local Stack = StackModule.new(self.Configurations.MazeSize * self.Configurations.MazeSize)
		local CurrentNode = Stack:Push(self.Nodes[self.Configurations.StartingNode])
		CurrentNode.Visited = true
		self.Nodes[#self.Nodes].Walls.Up = false --Exit
		while not Stack:IsEmpty() do
			CurrentNode = Stack:Pop()
			local Neighbors = CurrentNode:FindNeighbors("NonVisited")
			if Neighbors ~= nil then
				local NextNode = Neighbors[self.Seed:NextInteger(1, #Neighbors)]
				Stack:Push(CurrentNode)
				RemoveWalls(CurrentNode, NextNode)
				NextNode.Visited = true
				Stack:Push(NextNode)
			end
		end
		Stack:Destroy()
	end

	if self.Configurations.Algorithm == "Prims" then
		local Frontier = {}
		self.Nodes[self.Configurations.StartingNode].Visited = true
		Frontier = TableUtil.Extend(Frontier, self.Nodes[self.Configurations.StartingNode]:FindNeighbors("NonVisited"))
		self.Nodes[#self.Nodes].Walls.Up = false --Exit
		while not TableUtil.IsEmpty(Frontier) do
			local CurrentNode = Frontier[self.Seed:NextInteger(1, #Frontier)]
			local Neighbors = CurrentNode:FindNeighbors("NonVisited")
			CurrentNode.Visited = true
			if Neighbors ~= nil then
				Frontier = TableUtil.Extend(Frontier, CurrentNode:FindNeighbors("NonVisited"))
				Frontier = RemoveTableDupes(Frontier)
			end
			RemoveWalls(
				CurrentNode:FindNeighbors("Visited")[self.Seed:NextInteger(1, #CurrentNode:FindNeighbors("Visited"))],
				CurrentNode
			)
			table.remove(Frontier, table.find(Frontier, CurrentNode))
		end
		self.Nodes[self.Configurations.StartingNode]:AddEvent("SpawnLocation")
	end

	for _, Node in ipairs(self.Nodes) do
		Node:PreRender()
		Node:MarkFakeWalls()
	end
	return MazeService
end

--[[
Creates a room pattern
]]
function MazeService:CreateRoom(RoomSize: number, MazeEvent: string)
	assert(tonumber(RoomSize), "Please pass down a number")
	local SelectedNode = self.Nodes[self.Seed:NextInteger(1, #self.Nodes)]
	while true do
		local NodesInRoom = {}
		local FalseSignal = false
		local BreakSignal = false
		for y = 0, RoomSize - 1 do
			for x = 0, RoomSize - 1 do
				local Node = SelectedNode:FindNode(x, y)
				table.insert(NodesInRoom, Node)
				if Node then
					if Node.Visited and Node:IsEdge() then
						FalseSignal = true
					end
				else
					FalseSignal = true
				end
			end
		end
		if FalseSignal then
			SelectedNode = self.Nodes[self.Seed:NextInteger(1, #self.Nodes)]
			continue
		end
		for _, Node in ipairs(NodesInRoom) do
			Node.Visited = true
			if Node == SelectedNode then
				local MiddlePoint = function()
					local MiddleX = 0
					local MiddleZ = 0
					for _, Node in ipairs(NodesInRoom) do
						MiddleX += Node:GetPosition().X
						MiddleZ += Node:GetPosition().Z
					end
					MiddleX /= #NodesInRoom
					MiddleZ /= #NodesInRoom
					return Vector3.new(MiddleX, SelectedNode:GetPosition().Y, MiddleZ)
				end
				Node:AddEvent(MazeEvent or "_", { MiddlePoint = MiddlePoint(), RoomSize = RoomSize })
			else
				Node:AddEvent("_")
			end
			if Node.Y - SelectedNode.Y ~= 0 then
				Node:RemoveWall("Down")
			else
				Node:AddWall("Down")
			end
			if Node.X - SelectedNode.X ~= 0 then
				Node:RemoveWall("Left")
			elseif Node ~= SelectedNode then
				Node:AddWall("Left")
			end
		end
		SelectedNode.Walls.Left = false
		SelectedNode.Visited = true
		BreakSignal = true
		if BreakSignal then
			break
		end
	end
end

--[[Creates a passage pattern]]
function MazeService:CreatePassage() end

function MazeService:MarkEvents()
	for _, Node in ipairs(self.Nodes) do
		if not Node:ContainsEvent() and Node:GetWallType() == "DeadEnd" then
			Node:AddEvent("JailCell")
		else
		end
	end
	local ForceMazeEvent = {}
	local MazeEventsPercentage = {
		{ Name = "JailCell", Percentage = 1, Type = "DeadEnd" },
		--DEFINE ROOMS WITH ROOMSIZE, OR IT WON'T WORK
		{ Name = "Treehouse", Percentage = 10, Type = "Room", RoomSize = 2 },
	}

	-- local AvailableNodes: number = #self.Nodes
	-- local _Events = {
	-- 	QuestGiver1 = 1,
	-- 	QuestGiver2 = 1,
	-- 	QuestGiver3 = 1,
	-- 	QuestGiver4 = 1,

	-- 	Exit = 1,
	-- 	Spawn = 1,
	-- }

	-- local _EventPercentages = setmetatable({
	-- 	Empty = 90,
	-- 	Paintings = 10,
	-- }, {
	-- 	__div = function(Table, _AvailableNodes)
	-- 		local TranslatedTable = TableUtil.Copy(Table)
	-- 		for EventName, EventPercent in pairs(TranslatedTable) do
	-- 			TranslatedTable[EventName] = math.round((EventPercent / 100) * _AvailableNodes)
	-- 		end
	-- 		return TranslatedTable
	-- 	end,
	-- })

	-- for EventName, MaximumAllowed in pairs(_Events) do
	-- 	for i = 1, MaximumAllowed do
	-- 		local RandomInteger = self.Seed:NextInteger(1, #self.Nodes)
	-- 		local Node = self.Nodes[RandomInteger]
	-- 		if not Node:ContainsEvent() then
	-- 			AvailableNodes -= 1
	-- 			Node.Event = EventName
	-- 			continue
	-- 		end
	-- 		while Node:ContainsEvent() do
	-- 			RandomInteger = self.Seed:NextInteger(1, #self.Nodes)
	-- 			Node = self.Nodes[RandomInteger]
	-- 			if not Node:ContainsEvent() then
	-- 				AvailableNodes -= 1
	-- 				Node.Event = EventName
	-- 				break
	-- 			end
	-- 		end
	-- 	end
	-- end

	-- _EventPercentages = _EventPercentages / AvailableNodes

	-- for EventName, MaximumAllowed in pairs(_EventPercentages) do
	-- 	for i = 1, MaximumAllowed do
	-- 		local RandomInteger = self.Seed:NextInteger(1, #self.Nodes)
	-- 		local Node = self.Nodes[RandomInteger]
	-- 		if not Node:ContainsEvent() then
	-- 			AvailableNodes -= 1
	-- 			Node.Event = EventName
	-- 			continue
	-- 		end
	-- 		while Node:ContainsEvent() do
	-- 			RandomInteger = self.Seed:NextInteger(1, #self.Nodes)
	-- 			Node = self.Nodes[RandomInteger]
	-- 			if not Node:ContainsEvent() then
	-- 				AvailableNodes -= 1
	-- 				Node.Event = EventName
	-- 				break
	-- 			end
	-- 		end
	-- 	end
	-- end
end

function MazeService:Render(PrintWallTypes: boolean)
	local Deadend = {}
	local Hallway = {}
	local Turn = {}
	local Edge = {}
	local Empty = {}
	for i, Node in ipairs(self.Nodes) do
		if Node:GetWallType() == "DeadEnd" then
			table.insert(Deadend, Node.instance)
			Node:PostRender()
		end
		if Node:GetWallType() == "Hallway" then
			table.insert(Hallway, Node.instance)
			Node:PostRender()
		end
		if Node:GetWallType() == "Turn" then
			table.insert(Turn, Node.instance)
			Node:PostRender()
		end
		if Node:GetWallType() == "Edge" then
			table.insert(Edge, Node.instance)
			Node:PostRender()
		end
		if Node:GetWallType() == "Empty" then
			table.insert(Empty, Node.instance)
			Node:PostRender()
		end
	end
	if PrintWallTypes then
		task.delay(1, function()
			print("DeadEnds: ", Deadend)
			print("Hallways: ", Hallway)
			print("Turn", Turn)
			print("Edges: ", Edge)
			print("Empty:", Empty)
		end)
	end
end

function MazeService:KnitInit()
	self.NodeModule = require(script.NodeModule)
	self.Nodes = {}
	self.Configurations = {} :: ConfigurationsTypes
	self.Configurations.MazeSize = self.Configurations.MazeSize or Constants.MazeSize
	self.Configurations.StartingNode = self.Configurations.StartingNode or Constants.StartingNode
	self.Configurations.StartingVector = self.Configurations.StartingVector or Constants.StartingVector
	self.Configurations.Thickness = self.Configurations.Thickness or Constants.Thickness
	self.Configurations.Height = self.Configurations.Height or Constants.Height
	self.Configurations.Seed = self.Configurations.Seed or Constants.Seed
	self.Configurations.WallColor = self.Configurations.WallColor or Constants.WallColor
	self.Configurations.CellSize = self.Configurations.CellSize or Constants.CellSize
	self.Configurations.Material = self.Configurations.Material or Constants.Material
	self.Configurations.Algorithm = self.Configurations.Algorithm or Constants.Algorithm
end
function MazeService:KnitStart()
end

return MazeService
