--!native
export type newNode = { new: (x: number, y: number, DependentTable: Board) -> Node }
export type newBoard = {
	new: (length: number, width: number, nodeTemplate: { [string]: any } | nil, random: Random?) -> Board,
}
export type Node = {
	x: number,
	y: number,
	-- _dependentTable: Board,
	new: newNode,
	Data: { [string]: any },

	FindNode: (self: Node, x: number, y: number) -> (),
	FindNeighbors: (self: Node) -> { Node },
	FindSurroundings: (self: Node) -> { Node },
	FindSurroundingsDeep: (self: Node, Depth: number) -> (),

	AddData: (self: Node, Key: string, Value: any) -> (),
	OverrideData: (self: Node, Key: string, Value: any | (oldData: any) -> any) -> (),
	ReconcileData: (self: Node, Template: { [string]: any }) -> Node,
	HasData: (self: Node, key: string) -> (boolean, any),
}

export type Board = {
	random: Random,
	length: number,
	width: number,
	nodes: { [number]: Node },
	FindNode: (self: Board, x: number, y: number) -> Node | nil,

	RandomNode: (self: Board) -> Node,
	RandomSquare: (self: Board, squareSize: number) -> { Node } | Promise,
	RandomRectangle: (self: Board, length: number, width: number) -> { Node } | Promise,

	UseFilter: (self: Board, filterOut: { string }, fn: (method: (...any) -> ...any) -> ()) -> (),
	UsePromise: (self: Board, fn: (method: (...any) -> ...any) -> ()) -> Promise,
	UseFilteredResult: (self: Board, filterOut: { string }) -> (),
}

export type Promise = {
	awaitValue: any,
	andThen: (self: Promise, successHandler: any, failureHandler: any) -> Promise,
	andThenCall: (self: Promise, callback: any, ...any) -> Promise,
	andThenReturn: (self: Promise, ...any) -> Promise,
	await: (self: Promise) -> (boolean, ...any),
	awaitStatus: (self: Promise) -> (Status, ...any),
	cancel: (self: Promise) -> (),
	catch: (self: Promise, failureHandler: any) -> Promise,
	expect: (self: Promise) -> ...any,
	finally: (self: Promise, finallyHandler: (status: Status) -> ...any) -> (),
	finallyReturn: (self: Promise, ...any) -> Promise,
	getStatus: (self: Promise, Status) -> (),
	now: (self: Promise, rejectionValue: any) -> Promise,
	tap: (self: Promise, tapHandler: any) -> Promise,
	timeout: (self: Promise, seconds: number, rejectionValue: any) -> Promise,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Promise = require(ReplicatedStorage.Packages.Promise)

--UTILITIES--
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

local function ToBool(data: any): boolean
	if type(data) == "boolean" then
		return data
	elseif type(data) == "nil" then
		return false
	else
		return true
	end
end
--UTILITIES--

--[=[
	@class Node
]=]
local Node = {} :: Node

--[=[
	@class Board

	### Standards
	* length means **x axis**
	* width means **y axis**
	* If random is specified during construction then random will be used whenever something random is needed.
]=]
local Board = {} :: Board

Node.__index = Node
Board.__index = Board

--[=[
	the constructor of the node.
	@return Node
]=]
function Node.new(x: number, y: number, DependentTable: Board)
	local self = setmetatable({} :: Node, Node)
	self.x = x
	self.y = y
	self._dependentTable = DependentTable
	self.Data = {}
	return self
end

--[=[
	find node using this node's coordinates
	@return Node | nil
]=]
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

--[=[
	finds the the neighbors of the node (up, down, left right)
	@return { Node } | nil
]=]
function Node:FindNeighbors()
	local Neighbors = {}
	for _, offset in ipairs({ { 0, 1 }, { 0, -1 }, { -1, 0 }, { 1, 0 } }) do
		table.insert(Neighbors, self:FindNode(unpack(offset)))
	end
	return Neighbors
end

--[=[
	finds the surrounding of the node.
	@return { Node } | nil
]=]
function Node:FindSurroundings()
	local Neighbors = {}
	for _, offset in ipairs({ { 0, 1 }, { 0, -1 }, { -1, 0 }, { 1, 0 }, { 1, 1 }, { -1, -1 }, { 1, -1 }, { -1, 1 } }) do
		table.insert(Neighbors, self:FindNode(unpack(offset)))
	end
	return Neighbors
end

--[=[
	@return {Node} | nil
	finds the surroundings, but you may specify how far the surrounding should be.
	:::caution
	this also includes their own node when returned, this is due to my implemetation
	:::
]=]
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

--[=[
	@param key string -- key to store data
	@param value any -- inital data to store
	adds a data piece of data to the node.
	:::caution
	cannot add data that already exists, or it will throw a error
	:::
]=]
function Node:AddData(key, value)
	assert(not self.Data[key], "[Node] cannot add data that already exists")
	self.Data[key] = value
	return self
end

--[=[
	@param key string -- key to override data
	@param value any | (oldData: any) -> any -- inital data to store
	you may use both callback or just purely overriding data.
]=]
function Node:OverrideData(key, value)
	assert(self.Data[key], "[Node] cannot override empty data.")
	if type(value) == "function" then
		self.Data[key] = value(self:RetriveData(key))
	else
		self.Data[key] = value
	end
end

--[=[
	@param template { [string]: any }
	@return Node
	reconciles data to the node. Returns self for internal reason.
]=]
function Node:ReconcileData(template)
	self.Data = Reconcile(self.Data, template)
	return self
end

--[=[
	@param key string -- the key to check if the data exists or not
	@return boolean, any

	returns a tuple, first param is exists and the second is the data that it has.
	```lua
		local node = require(path.to.node)
		local thisNode = node.node.new(...)
		local exists, data = thisNode:HasData("CustomData")
		print(exists) -- false
		print(data) -- nil
	```
]=]
function Node:HasData(key: string)
	return (self.Data[key] ~= nil), self.Data[key]
end

--[=[
	@param length number
	@param width number
	@param nodeTemplate  { [string]: any } -- the template for nodes to reconcile.
	constructs a new board, automatically creates all the nodes using length and width.
	If there is nodeTemplate then automatically reconciles the node with the template.
	If random is specified then any random calculations will be using the random you provided
]=]
function Board.new(length: number, width: number, nodeTemplate: { [string]: any } | nil, random: Random?)
	local self = setmetatable({} :: Board, Board)
	self.length = length
	self.width = width
	self.nodes = {}
	if nodeTemplate then
		for x = 1, length do
			for y = 1, width do
				table.insert(self.nodes, Node.new(x, y, self):ReconcileData(nodeTemplate))
			end
		end
	else
		for x = 1, length do
			for y = 1, width do
				table.insert(self.nodes, Node.new(x, y, self))
			end
		end
	end
	return self
end

--[=[
	@return Node | nil
	finds the node in the board, if there is any
]=]
function Board:FindNode(x: number, y: number)
	for i = 1, #self.nodes do
		if self.nodes[i].x == x and self.nodes[i].y == y then
			return self.nodes[i]
		end
	end
end

--[=[
	@return Node
	returns a random node on the board.
]=]
function Board:RandomNode()
	if self.random then
		return self.nodes[self.random:NextInteger(1, #self.nodes)]
	else
		return self.nodes[math.random(1, #self.nodes)]
	end
end

--[=[
	@return { Node }
	@yields
	finds a random rectangle
	:::caution
	may recursively find rectangle if the random node doesn't have a rectangle.
	This **may** lead to potential yielding or even stack overflow but the chances are **depends on the board size**.
	to prevent yielding please wrap this method with `:UsePromise`
	:::
]=]
function Board:RandomRectangle(length: number, width: number)
	local function findRectangle()
		local randomNode = self:RandomNode()
		local neighbors = {}
		for x = 1, length do
			for y = 1, width do
				table.insert(neighbors, randomNode:FindNode(x, y))
			end
		end
		if #neighbors == length * width then
			return neighbors
		else
			table.clear(neighbors)
		end
	end
	local result = findRectangle()
	while result == nil do
		result = findRectangle()
	end
	return result
end

--[=[
	@return { Node }
	@yields
	:::caution
	may recursively find rectangle if the random node doesn't have a square.
	This **may** lead to potential yielding or even stack overflow but the chances are **depends on the board size**.
	to prevent yielding please wrap this method with `:UsePromise`
	:::
]=]
function Board:RandomSquare(size: number)
	return self:RandomRectangle(size, size)
end

--[=[
	@param fn () -> Node | {Node} --the method that is going to be used
	@param filterOut {string} -- the data to see if it should exist
	@return { Node } | nil
	Removes the result of the node. If the value attached to the key is `false` it will still be filtered out.
	:::caution
	when passing down the method, please create a anoymous function and return the method you're using. **this applies to all `Use` methods**
	:::
]=]
function Board:UseFilter(filterOut: { string }, fn: () -> Node | { Node })
	local result = fn()
	--having dependent table asumes its not bundled up into another table.
	if result._dependentTable then
		for i = 1, #filterOut do
			local hasdata = result:HasData(filterOut[i])
			if hasdata then
				return nil
			else
				print(result)
				return result
			end
		end
	else
		local returnValue = {}
		for key = 1, #filterOut do
			for i = 1, #result do
				local hasdata = result[i]:HasData(filterOut[key])
				if not hasdata then
					table.insert(returnValue, result[i])
				end
			end
		end
		return returnValue
	end
end

--[=[
	@param fn () -> Node | {Node} --the method that is going to be used
	@return Promise

	wraps the method you're using with a promise so it can avoid potential yielding.

	:::caution
	when passing down the method, please create a anoymous function and return the method you're using. **this applies to all `Use` methods**
	:::

	:::tip
	you should wrap this into any potential yielding methods. Promises are very flexible!
	:::

	```lua
		local node = require(path.to.node)
		local board = node.board.new(2, 2)

		board
			:UsePromise(function()
				return board:RandomSquare(2) --this method may yield.
			end)
			:andThen(print)
	```
]=]
function Board:UsePromise(fn: () -> ())
	return Promise.new(function(resolve)
		resolve(fn())
	end)
end

--[=[
	@param fn () -> Node | {Node} --the method that is going to be used
	@param filterOut {string} -- the data to see if it should exist
	@yields
	checks if any node needs to be filtered. If any node is determined to be filtered, it will call the function recursively until no node is needed to be filtered.
	:::caution
	when passing down the method, please create a anoymous function and return the method you're using. **this applies to all `Use` methods**
	:::

	```lua
		local node = require(path.to.node)
		local board = node.board.new(2, 2)
		board
			:UsePromise(function()
				return board:UseFilteredResult({"Visited"}, function()
					return board:RandomSquare(2, 2)
				end)
			end)
			:andThen(print)
	```
]=]


function Board:UseFilteredResult(filterOut: { string }, fn: () -> Node | { Node })
	local result = fn()
	local function scan()
		if result._dependentTable then
			for i = 1, #filterOut do
				local hasdata = result:HasData(filterOut[i])
				if hasdata then
					return false
				else
					return true
				end
			end
		else
			local returnValue = {}
			for key = 1, #filterOut do
				for i = 1, #result do
					local hasdata = result[i]:HasData(filterOut[key])
					if not hasdata then
						table.insert(returnValue, result[i])
					else
						return false
					end
				end
			end
			return true
		end
	end
	local recursive = scan()
	while recursive do
		result = fn()
		recursive = scan()
	end
	return result
end

return { node = Node, board = Board } :: { node: newNode, board: newBoard }
