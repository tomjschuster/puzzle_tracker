defmodule PuzzleTracker.Crossword.PuzzleTest do
  use ExUnit.Case
  alias PuzzleTracker.Crossword.Puzzle

  describe "Creating a puzzle" do
    test "produces in a puzzle with a date, cell count and block count" do
      cases = [
        {Date.utc_today(), 1, 0},
        {Date.utc_today(), 1, 1},
        {Date.new!(1970, 1, 1), 225, 38},
        {Date.new!(2022, 2, 22), 100, 0},
        {Date.new!(3000, 12, 31), 9999, 1000}
      ]

      for {date, cell_count, block_count} <- cases do
        assert {:ok, %Puzzle{date: ^date, cell_count: ^cell_count, block_count: ^block_count}} =
                 Puzzle.new(date, cell_count, block_count)
      end
    end

    test "errors when block_count is higher than cell_count" do
      assert {:error, :more_blocks_than_cells} = Puzzle.new(Date.utc_today(), 1, 2)
    end
  end

  describe "Puzzle grid" do
    test "derives the number of white squares from the grid size and block count" do
      cases = [
        {1, 0, 1},
        {1, 1, 0},
        {196, 46, 150},
        {100, 0, 100},
        {9999, 1000, 8999}
      ]

      for {cell_count, block_count, white_squares} <- cases do
        assert {:ok, %Puzzle{} = puzzle} = Puzzle.new(Date.utc_today(), cell_count, block_count)
        assert Puzzle.white_squares(puzzle) == white_squares
      end
    end
  end
end
