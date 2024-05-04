--!native
return {
	StartingNode = 1,
	MazeSize = 50,
	WallColor = Color3.new(0.517647, 0.517647, 0.517647),
	CellSize = 20,
	Material = Enum.Material.Plastic,
	Thickness = 1,
	Height = 100,
	StartingVector = Vector3.new(0, 0, 0),
	Seed = math.random(1, 2147483647),
	Algorithm = "Prims",
}
