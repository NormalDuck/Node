--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")

local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Knit = require(ReplicatedStorage.Packages.Knit)
local Utilities = require(ReplicatedStorage.Shared.Utils.Utilities)
local Node = {}

type self = {
	X: number,
	Y: number,
	Visited: false,
	IsPreRendered: boolean,
	IsPostRendered: boolean,
	Model: nil | Model,
	Event: nil | { EventName: string, EventData: string },
	Walls: { Up: boolean, Down: boolean, Left: boolean, Right: boolean },
	FakeWalls: { Up: boolean, Down: boolean, Left: boolean, Right: boolean },
}

export type Node = typeof(setmetatable({} :: self, Node))

Knit.OnStart():andThen(function()
	local MazeModel = Instance.new("Model")
	MazeModel.Name = "Maze"
	MazeModel.Parent = workspace
	local MazeService = Knit.GetService("MazeService")

	--[[Constructs a new node]]
	function Node.new(X: number, Y: number): Node
		local StartingVector = MazeService.Configurations.StartingVector
		local CellSize = MazeService.Configurations.CellSize
		local Height = MazeService.Configurations.Height
		local self = setmetatable({} :: Node, { __index = Node })
		self.X = X
		self.Y = Y
		self.Walls = setmetatable({ Up = true, Down = true, Left = true, Right = true }, {
			len = function(Walls)
				local Count = 0
				for Wall, Exists in pairs(Walls) do
					if Exists then
						Count += 1
					end
				end
				return Count
			end,
		})
		self.FakeWalls = {}
		self.Position = Vector3.new(
			StartingVector.X + CellSize * self.X,
			StartingVector.Y - (Height / -2),
			StartingVector.Z + CellSize * self.Y
		)
		return self
	end

	--[[Finds **one node**. May return nil]]
	function Node:FindNode(X: number, Y: number): Node
		local NewX = self.X + X
		local NewY = self.Y + Y
		if
			NewX < 1
			or NewY < 1
			or NewX > MazeService.Configurations.MazeSize
			or NewY > MazeService.Configurations.MazeSize
		then
			return nil
		end
		return MazeService.Nodes[NewX + (NewY - 1) * MazeService.Configurations.MazeSize]
	end

	--[[Finds the neighbors of the node]]
	function Node:FindNeighbors(
		FindFor: "Visited" | "NonVisited" | "Any",
		DictionaryFormat: boolean,
		IncludeEvents: boolean
	): { self } | nil
		local Neighbors = {}
		local Up = self:FindNode(0, 1)
		local Down = self:FindNode(0, -1)
		local Left = self:FindNode(-1, 0)
		local Right = self:FindNode(1, 0)

		if not IncludeEvents and Up then
			if Up["Event"] then
				Up = nil
			end
		end
		if not IncludeEvents and Down then
			if Down["Event"] then
				Down = nil
			end
		end
		if not IncludeEvents and Left then
			if Left["Event"] then
				Left = nil
			end
		end
		if not IncludeEvents and Right then
			if Right["Event"] then
				Right = nil
			end
		end

		if Up ~= nil then
			if
				FindFor == nil
				or (FindFor == "NonVisited" and not Up.Visited)
				or (FindFor == "Visited" and Up.Visited)
			then
				if DictionaryFormat then
					Neighbors.Up = Up
				else
					table.insert(Neighbors, Up)
				end
			end
		end

		if Down ~= nil then
			if
				FindFor == nil
				or (FindFor == "NonVisited" and not Down.Visited)
				or (FindFor == "Visited" and Down.Visited)
			then
				if DictionaryFormat then
					Neighbors.Down = Down
				else
					table.insert(Neighbors, Down)
				end
			end
		end

		if Left ~= nil then
			if
				FindFor == nil
				or (FindFor == "NonVisited" and not Left.Visited)
				or (FindFor == "Visited" and Left.Visited)
			then
				if DictionaryFormat then
					Neighbors.Left = Left
				else
					table.insert(Neighbors, Left)
				end
			end
		end

		if Right ~= nil then
			if
				FindFor == nil
				or (FindFor == "NonVisited" and not Right.Visited)
				or (FindFor == "Visited" and Right.Visited)
			then
				if DictionaryFormat then
					Neighbors.Right = Right
				else
					table.insert(Neighbors, Right)
				end
			end
		end

		if #TableUtil.Values(Neighbors) > 0 then
			return Neighbors
		else
			return nil
		end
	end

	--[[Finds the surrounding of the node.
	\
	**This does return your own node**]]
	function Node:FindSurrounding(Radius: number)
		local Surroundings = {}
		for current = 0, Radius do
			for i = -(math.abs(current)), current do
				self:FindNode()
			end
		end
		return Utilities.RemoveTableDupes(Surroundings)
	end

	--[[
	Renders the basic walls for the Maze, parented to nil unless PostRender is called. Initially marks FakeWalls
	]]
	function Node:PreRender(): Node
		local CellSize = MazeService.Configurations.CellSize
		local Height = MazeService.Configurations.Height
		local Thickness = MazeService.Configurations.Thickness
		local Material = MazeService.Configurations.Material
		local WallColor = MazeService.Configurations.WallColor
		local Model = Instance.new("Model")

		Model.Name = self.X .. ", " .. self.Y

		for Index, Exists in pairs(self.Walls) do
			if not Exists then
				continue
			end
			local Wall = Instance.new("Part")
			Wall.Anchored = true
			Wall.Material = Material

			if Index == "Up" then
				Wall.Position =
					Vector3.new(self.Position.X - CellSize / 2 - Thickness / 2, self.Position.Y, self.Position.Z)
				Wall.Size = Vector3.new(CellSize, Height, Thickness)
				self.Walls.Up = Wall
			end

			if Index == "Down" then
				Wall.Position = Vector3.new(
					self.Position.X - CellSize / 2 - Thickness / 2,
					self.Position.Y,
					self.Position.Z - CellSize
				)
				Wall.Size = Vector3.new(CellSize, Height, Thickness)
				self.Walls.Down = Wall
			end

			if Index == "Left" then
				Wall.Position = Vector3.new(
					self.Position.X - CellSize,
					self.Position.Y,
					self.Position.Z - CellSize / 2 - Thickness / 2
				)
				Wall.Size = Vector3.new(Thickness, Height, CellSize)
				self.Walls.Left = Wall
			end

			if Index == "Right" then
				Wall.Position =
					Vector3.new(self.Position.X, self.Position.Y, self.Position.Z - CellSize / 2 - Thickness / 2)
				Wall.Size = Vector3.new(Thickness, Height, CellSize)
				self.Walls.Right = Wall
			end
			Wall.Name = Index
			Wall.CanTouch = false
			Wall.CanQuery = false
			Wall.Parent = Model
			Wall.Color = WallColor
		end

		local TopWall = Instance.new("Part")
		TopWall.Transparency = 1
		TopWall.Material = Material
		TopWall.Anchored = true
		TopWall.Size = Vector3.new(CellSize, Thickness, CellSize)
		TopWall.Position =
			Vector3.new(self.Position.X - CellSize / 2, self.Position.Y - Height / -2, self.Position.Z - CellSize / 2)
		TopWall.Name = "Roof"
		TopWall.CanTouch = false
		TopWall.CanQuery = false
		TopWall.Locked = false
		TopWall.Color = WallColor

		local BottomWall = Instance.new("Part")
		BottomWall.Material = Material
		BottomWall.Anchored = true
		BottomWall.Size = Vector3.new(CellSize, Thickness, CellSize)
		BottomWall.Position =
			Vector3.new(self.Position.X - CellSize / 2, self.Position.Y - Height / 2, self.Position.Z - CellSize / 2)
		BottomWall.Name = "Floor"
		BottomWall.CanTouch = false
		BottomWall.CanQuery = false
		BottomWall.Locked = false
		BottomWall.Color = WallColor

		TopWall.Parent = Model
		BottomWall.Parent = Model

		self.Model = Model
		self.IsPreRendered = true
	end

	--[[
	Sets the parent of the node to workspace. Adding maze event if there is
	]]
	function Node:PostRender(): Node
		if self:ContainsEvent() then
			if self:GetEventData() and self:GetEventData().RoomSize then
				local EventInstance: UnionOperation =
					ServerStorage.MazeEvents.Rooms[self:GetEventData().RoomSize][self.Event.EventName]
				local CloneEventInstance = EventInstance:Clone()
				CloneEventInstance:PivotTo(CFrame.new(self:GetEventData().MiddlePoint))
				CloneEventInstance.Anchored = true
				CloneEventInstance:FindFirstChild("Event").Parent = self.Model
				CloneEventInstance:Destroy()
			else
				local EventInstance: UnionOperation = ServerStorage.MazeEvents:FindFirstChild(self.Event.EventName)
				local CloneEventInstance = EventInstance:Clone()
				local Rotation = CFrame.Angles(0, math.rad(self:GetRotation()), 0)
				CloneEventInstance:PivotTo(CFrame.new(self:GetPosition()) * Rotation)
				CloneEventInstance.Anchored = true
				CloneEventInstance:FindFirstChild("Event").Parent = self.Model
				CloneEventInstance:Destroy()
			end
		end
		self.Model.Parent = MazeModel
		self.IsPostRendered = true
	end

	--[[Checks if node has event attached to it. **Returns false if event name is called "_"**]]
	function Node:ContainsEvent(): boolean
		if self.Event then
			if self.Event.EventName == "_" then
				return false
			end
			return self.Event
		else
			return false
		end
	end

	--[[returns the wall count of the node. **fake walls are counted**. Please use #Node for "pure" wall count, ignoring fake walls]]
	function Node:WallCount(): number
		local FakeWallTable = {}
		local WallTable = {}
		for WallSide, Exist in pairs(self.Walls) do
			if Exist then
				table.insert(WallTable, WallSide)
			end
		end
		for WallSide, Exist in pairs(self.FakeWalls) do
			if Exist and not table.find(WallTable, WallSide) then
				table.insert(FakeWallTable, WallSide)
			end
		end
		return #FakeWallTable + #WallTable
	end

	--[[returns the middle point of the node]]
	function Node:GetPosition(): Vector3
		return Vector3.new(
			self.Position.X - (MazeService.Configurations.CellSize / 2),
			self.Position.Y - MazeService.Configurations.Height / 2,
			self.Position.Z - (MazeService.Configurations.CellSize / 2)
		)
	end

	--[[Attaches a event to the node, with additional informaion to pass within the event]]
	function Node:AddEvent(EventName: string, EventData: any): Node
		assert(
			ServerStorage.MazeEvents:FindFirstChild(EventName, true) or EventName == "_",
			"Please provide a event name or _ for none. Or the event doesn't exist."
		)
		self.Event = { EventName = EventName, EventData = EventData }
	end

	--[[returns the rotation of a model.
	\
	**IT SHOULDN'T RETURN ERROR. IF SO, PROBABLY IMPLEMENTATION'S PROBLEM**]]
	function Node:GetRotation(): number
		if self:GetWallType() == "DeadEnd" then
			-- Check for walls in three directions
			if self:HasWall("Right") and self:HasWall("Up") and self:HasWall("Left") then
				return 0
			elseif self:HasWall("Up") and self:HasWall("Left") and self:HasWall("Down") then
				return -90
			elseif self:HasWall("Left") and self:HasWall("Down") and self:HasWall("Right") then
				return 180
			elseif self:HasWall("Down") and self:HasWall("Right") and self:HasWall("Up") then
				return 90
			end
			warn("[FIXME] Node: cannot get rotation? ", self.Walls, self.FakeWalls)
		end
		if self:GetWallType() == "Turn" then
			if self:HasWall("Up") and self:HasWall("Right") then
				return 0
			elseif self:HasWall("Up") and self:HasWall("Left") then
				return -90
			elseif self:HasWall("Down") and self:HasWall("Right") then
				return 90
			elseif self:HasWall("Down") and self:HasWall("Left") then
				return 180
			end
			warn("[FIXME] Node: cannot get rotation? ", self.Walls, self.FakeWalls)
		end
		if self:GetWallType() == "Hallway" then
			if self:HasWall("Right") and self:HasWall("Left") then
				return 0
			elseif self:HasWall("Up") and self:HasWall("Down") then
				return 90
			end
			warn("[FIXME] Node: cannot get rotation? ", self.Walls, self.FakeWalls)
		end
		if self:GetWallType() == "Edge" then
			if self:HasWall("Up") then
				return 0
			elseif self:HasWall("Right") then
				return 90
			elseif self:HasWall("Left") then
				return -90
			elseif self:HasWall("Down") then
				return 180
			end
			warn("[FIXME] Node: cannot get rotation? ", self.Walls, self.FakeWalls)
		end
		if self:GetWallType() == "Empty" then
			return 0
		end
		warn("[FIXME] Node: cannot get rotation? ", self.Walls, self.FakeWalls)
	end

	--[[Constructs a wall on the node if there isn't one before, **does not add into FakeWalls internally**. Internally uses Debris as deletion]]
	function Node:AddWall(Side: "Up" | "Down" | "Left" | "Right"): ()
		local CellSize = MazeService.Configurations.CellSize
		local Height = MazeService.Configurations.Height
		local Thickness = MazeService.Configurations.Thickness
		local Material = MazeService.Configurations.Material
		local WallColor = MazeService.Configurations.WallColor
		if self.IsPreRendered then
			local Wall = Instance.new("Part")
			Wall.Anchored = true
			Wall.Material = Material

			if Side == "Up" and self:HasWall("Up") then
				Wall.Position =
					Vector3.new(self.Position.X - CellSize / 2 - Thickness / 2, self.Position.Y, self.Position.Z)
				Wall.Size = Vector3.new(CellSize, Height, Thickness)
				self.Walls.Up = Wall
			end

			if Side == "Down" then
				Wall.Position = Vector3.new(
					self.Position.X - CellSize / 2 - Thickness / 2,
					self.Position.Y,
					self.Position.Z - CellSize
				)
				Wall.Size = Vector3.new(CellSize, Height, Thickness)
				self.Walls.Down = Wall
			end

			if Side == "Left" then
				Wall.Position = Vector3.new(
					self.Position.X - CellSize,
					self.Position.Y,
					self.Position.Z - CellSize / 2 - Thickness / 2
				)
				Wall.Size = Vector3.new(Thickness, Height, CellSize)
				self.Walls.Left = Wall
			end

			if Side == "Right" then
				Wall.Position =
					Vector3.new(self.Position.X, self.Position.Y, self.Position.Z - CellSize / 2 - Thickness / 2)
				Wall.Size = Vector3.new(Thickness, Height, CellSize)
				self.Walls.Right = Wall
			end
			Wall.Name = Side
			Wall.CanTouch = false
			Wall.CanQuery = false
			Wall.Parent = self.Model
			Wall.Color = WallColor
		else
			self.Walls[Side] = true
		end
	end

	--[[Schedules a removment for the wall. Uses Debris internally, **does remove FakeWalls and Walls internally**. #TODO make promises implementation instead?]]
	function Node:RemoveWall(Side: "Up" | "Down" | "Left" | "Right"): ()
		if self.IsPreRendered or self.IsPostRendered then
			Debris:AddItem(self.Model:FindFirstChild(Side))
			self.Walls[Side] = nil
		else
			self.Walls[Side] = nil
		end
	end

	--[[returns the piece of information stored for the event if there is. Or it will turn nil.]]
	function Node:GetEventData(): any
		return self.Event.EventData
	end

	--[[Finds the neighbors, "claims" the wall as FakeWall if it is "part-of" the cell. Ignoring any condition of the neighbors provided]]
	function Node:MarkFakeWalls()
		for Side, OtherNode in pairs(self:FindNeighbors("Visited", true)) do
			if Side == "Down" and OtherNode.Walls.Up and not self.Walls.Down then
				self.FakeWalls.Down = OtherNode.Walls.Up
			end
			if Side == "Up" and OtherNode.Walls.Down and not self.Walls.Up then
				self.FakeWalls.Up = OtherNode.Walls.Down
			end
			if Side == "Left" and OtherNode.Walls.Right and not self.Walls.Left then
				self.FakeWalls.Left = OtherNode.Walls.Right
			end
			if Side == "Right" and OtherNode.Walls.Left and not self.Walls.Right then
				self.FakeWalls.Right = OtherNode.Walls.Left
			end
		end
	end

	--[[checks if node has a wall, if true returns the wall instance. **Fake walls do count as the wall**]]
	function Node:HasWall(Wall: "Up" | "Down" | "Left" | "Right"): ()
		if self.Walls[Wall] then
			return self.Walls[Wall]
		elseif self.FakeWalls[Wall] then
			return self.FakeWalls[Wall]
		else
			return nil
		end
	end

	--[[Returns the wall type. ]]
	function Node:GetWallType(): "DeadEnd" | "HallWay" | "Turn" | "Edge" | "Empty"
		local WallCount = self:WallCount()
		if WallCount == 3 then
			return "DeadEnd"
		end
		if WallCount == 2 then
			if (self:HasWall("Up") and self:HasWall("Down")) or (self:HasWall("Left") and self:HasWall("Right")) then
				return "Hallway"
			else
				return "Turn"
			end
		end
		if WallCount == 1 then
			return "Edge"
		end
		if WallCount == 0 then
			return "Empty"
		end
	end

	function Node:RemoveAllWalls()
		for _, Side in ipairs({ "Up", "Down", "Left", "Right" }) do
			self:RemoveWall(Side)
		end
	end

	function Node:IsEdge()
		return self.X == 1
			or self.Y == 1
			or self.X == MazeService.Configurations.MazeSize
			or self.Y == MazeService.Configurations.MazeSize
	end
end)

return Node
