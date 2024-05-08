--!native
export type newNode = { new: (DependentTable: Board, x: number, y: number) -> Node }
export type newBoard = { new: (length: number, width: number, nodeTemplete: { [string]: any } | nil) -> Board }
export type Node = {
	x: number,
	y: number,
	_dependentTable: Board,
	new: newNode,
	Data: { [string]: any },
	FindNode: (self: Node, x: number, y: number) -> (),
	FindNeighbors: (self: Node) -> { Node },
	FindSurroundings: (self: Node) -> { Node },
	AddData: (self: Node, Key: string, Value: any) -> (),
	OverrideData: (self: Node, Key: string, Value: any | (oldData: any) -> any) -> (),
	ReconcileData: (self: Node, Template: { [string]: any }) -> Node,
	RetriveData: (self: Node, key: string) -> any,
}
export type Board = {
	length: number,
	width: number,
	nodes: { Node },
	GetNode: (x: number, y: number) -> Node,
}

local function Copy<T>(t: T, deep: boolean?): T
	if not deep then
		return (table.clone(t :: any) :: any) :: T
	end
	local function DeepCopy(tbl: { any })
		local tCopy = table.clone(tbl)
		for k, v in tCopy do
			if type(v) == "table" then
				tCopy[k] = DeepCopy(v)
			end
		end
		return tCopy
	end
	return DeepCopy(t :: any) :: T
end

local function Reconcile<S, T>(src: S, template: T): S & T
	assert(type(src) == "table", "First argument must be a table")
	assert(type(template) == "table", "Second argument must be a table")

	local tbl = table.clone(src)

	for k, v in template do
		local sv = src[k]
		if sv == nil then
			if type(v) == "table" then
				tbl[k] = Copy(v, true)
			else
				tbl[k] = v
			end
		elseif type(sv) == "table" then
			if type(v) == "table" then
				tbl[k] = Reconcile(sv, v)
			else
				tbl[k] = Copy(sv, true)
			end
		end
	end

	return (tbl :: any) :: S & T
end

local Node = {} :: Node
local Board = {} :: Board
Node.__index = Node
Board.__index = Board

function Node.new(x: number, y: number, DependentTable: {})
	local self: Node = setmetatable({}, Node)
	self.x = x
	self.y = y
	self._dependentTable = DependentTable
	self.Data = {}
	return self
end

function Node:FindNode(x: number, y: number)
	local NewX = self.x + x
	local NewY = self.x + y
	for i = 1, #self._dependentTable.nodes do
		if self._dependentTable.nodes[i].x == NewX and self._dependentTable.nodes[i].y == NewY then
			return self._dependentTable.nodes[i]
		end
	end
	return nil
end

function Node:FindNeighbors()
	local Neighbors = {}
	for _, offset in ipairs({ { 0, 1 }, { 0, -1 }, { -1, 0 }, { 1, 0 } }) do
		table.insert(Neighbors, self:FindNode(unpack(offset)))
	end
	return Neighbors
end

function Node:FindSurroundings()
	local Neighbors = {}
	for _, offset in ipairs({ { 0, 1 }, { 0, -1 }, { -1, 0 }, { 1, 0 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }) do
		table.insert(Neighbors, self:FindNode(unpack(offset)))
	end
	return Neighbors
end

function Node:FindSurroundingsDeep(Depth: number)
	local Neighbors = {}
	for CurrentDepth = 1, Depth do
		for x = -CurrentDepth, CurrentDepth do
			for y = -CurrentDepth, CurrentDepth do
				table.insert(Neighbors, self:FindNode(x, y))
			end
		end
	end
	return Neighbors
end

function Node:AddData(key, value)
	assert(not self.Data[key], "[Node] cannot add data that already exists")
	self.Data[key] = value
	return self
end

function Node:OverrideData(key, value)
	assert(self.Data[key], "[Node] cannot override empty data.")
	if type(value) == "function" then
		self.Data[key] = value(self:RetriveData(key))
	else
		self.Data[key] = value
	end
end

function Node:RetriveData(key)
	return self.Data[key]
end

function Node:ReconcileData(temp)
	self.Data = Reconcile(self.Data, temp)
	return self
end

function Board() end

return { node = Node, board = Board } :: { node: newNode, board: newBoard }
