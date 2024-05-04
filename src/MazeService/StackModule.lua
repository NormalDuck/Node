--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local StackModule = {}
StackModule.__index = StackModule
function StackModule.new(Size: number)
	local self = setmetatable({}, StackModule)
	self.stack = {}
	self.size = Size
	self.top = -1
	self._trove = Trove.new()
	return self
end

function StackModule:Push(Node)
	if #self.stack == self.size then
		return "Stack Overflow"
	end
	self.top += 1
	self.stack[self.top] = Node
	return self.stack[self.top]
end

function StackModule:Pop()
	local PoppedNode = self.stack[self.top]
	if self:IsEmpty() then
		return "Stack Overflow"
	end
	self.stack[self.top] = nil
	self.top -= 1
	return PoppedNode
end

function StackModule:Peek()
	return self.stack[self.top]
end

function StackModule:IsEmpty()
	return self.top == -1
end

function StackModule:Destroy()
	self._trove:Clean()
end

return StackModule
