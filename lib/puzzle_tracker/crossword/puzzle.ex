defmodule PuzzleTracker.Crossword.Puzzle do
  import PuzzleTracker.Utils.Guards

  @type t :: %__MODULE__{
          date: Date.t(),
          cell_count: pos_integer(),
          block_count: non_neg_integer()
        }

  @enforce_keys [:date, :cell_count, :block_count]
  defstruct [:date, :cell_count, :block_count]

  @spec new(Date.t(), pos_integer(), non_neg_integer()) ::
          {:ok, t()} | {:error, :more_blocks_than_cells}
  def new(%Date{} = date, cell_count, block_count)
      when is_pos_integer(cell_count)
      when is_non_neg_integer(block_count) do
    if block_count > cell_count do
      {:error, :more_blocks_than_cells}
    else
      puzzle = %__MODULE__{
        date: date,
        cell_count: cell_count,
        block_count: block_count
      }

      {:ok, puzzle}
    end
  end

  def white_squares(%__MODULE__{} = puzzle),
    do: puzzle.cell_count - puzzle.block_count
end
