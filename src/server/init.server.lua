local node = require(script.node)

local board = node.board.new(4, 4)

print(board:FindNode(2, 2):FindSurroundings())
