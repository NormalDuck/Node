local node = require(script.node)

local board = node.board.new(8, 8, { Visited = false })
print(debug.setmemorycategory("server"))

while task.wait(1) do
	for i = 1, 10 do
		board
			:UsePromise(function()
				return board:FindNode(1, 1)
			end)
			:andThen(print)
	end
end
