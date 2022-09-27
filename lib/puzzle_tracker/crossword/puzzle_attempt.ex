defmodule PuzzleTracker.Crossword.PuzzleAttempt do
  import PuzzleTracker.Utils.Guards

  alias PuzzleTracker.Crossword.Puzzle

  @type t :: %__MODULE__{
          puzzle: Puzzle.t(),
          started_at: DateTime.t(),
          finished_at: DateTime.t() | nil,
          pauses: [{DateTime.t(), DateTime.t() | nil}],
          incorrect: non_neg_integer() | nil,
          incomplete: non_neg_integer() | nil
        }

  @enforce_keys [:puzzle, :started_at, :pauses]
  defstruct puzzle: nil,
            started_at: nil,
            finished_at: nil,
            pauses: [],
            incorrect: nil,
            incomplete: nil

  defguardp is_finished(attempt) when not is_nil(attempt.finished_at)
  defguardp is_scored(attempt) when not is_nil(attempt.incorrect)

  # Write functions

  @spec new(Puzzle.t()) :: t()
  def new(%Puzzle{} = puzzle),
    do: %__MODULE__{puzzle: puzzle, started_at: DateTime.utc_now(), pauses: []}

  @spec pause(t()) :: t()
  def pause(attempt, paused_at \\ DateTime.utc_now())

  def pause(%__MODULE__{pauses: [{%DateTime{}, nil} | _]} = attempt, _paused_at),
    do: attempt

  def pause(%__MODULE__{pauses: pauses} = attempt, paused_at),
    do: %__MODULE__{attempt | pauses: [{paused_at, nil} | pauses]}

  @spec resume(t()) :: t()
  def resume(attempt, resumed_at \\ DateTime.utc_now())

  def resume(
        %__MODULE__{pauses: [{%DateTime{} = paused_at, nil} | pauses]} = attempt,
        resumed_at
      ),
      do: %__MODULE__{attempt | pauses: [{paused_at, resumed_at} | pauses]}

  def resume(%__MODULE__{} = attempt, _resumed_at), do: attempt

  @spec complete(t(), DateTime.t()) :: {:ok, t()} | {:error, :already_finished}
  def complete(%__MODULE__{} = attempt, finished_at \\ DateTime.utc_now()) do
    with {:ok, attempt} <- finish(attempt, finished_at),
         do: {:ok, %__MODULE__{attempt | incomplete: 0}}
  end

  @spec concede(t(), pos_integer(), DateTime.t()) :: {:ok, t()} | {:error, reason}
        when reason: :no_incomplete | :already_finished | :too_many_squares
  def concede(attempt, incomplete, finished_at \\ DateTime.utc_now())

  def concede(%__MODULE__{}, 0 = _incomplete, _finished_at), do: {:error, :no_incomplete}

  def concede(%__MODULE__{} = attempt, incomplete, finished_at)
      when is_pos_integer(incomplete) do
    with {:ok, attempt} <- finish(attempt, finished_at),
         :ok <- validate_squares_score(attempt, incomplete),
         do: {:ok, %__MODULE__{attempt | incomplete: incomplete}}
  end

  @spec record_score(t(), non_neg_integer()) :: {:ok, t()} | {:error, reason}
        when reason: :not_finished | :already_scored | :too_many_squares

  def record_score(%__MODULE__{} = attempt, _incorrect) when not is_finished(attempt),
    do: {:error, :not_finished}

  def record_score(%__MODULE__{} = attempt, _incorrect) when is_scored(attempt),
    do: {:error, :already_scored}

  def record_score(%__MODULE__{} = attempt, incorrect) when is_non_neg_integer(incorrect) do
    with :ok <- validate_squares_score(attempt, incorrect),
         do: {:ok, %__MODULE__{attempt | incorrect: incorrect}}
  end

  # Read functions

  @spec total_time_spent(t(), DateTime.t()) :: non_neg_integer()
  def total_time_spent(%__MODULE__{} = attempt, now \\ DateTime.utc_now()),
    do: total_time(attempt, now) - total_paused_time(attempt, now)

  @spec total_time(t(), DateTime.t()) :: non_neg_integer()
  def total_time(%__MODULE__{} = attempt, now \\ DateTime.utc_now()),
    do: DateTime.diff(attempt.finished_at || now, attempt.started_at)

  @spec total_paused_time(t(), DateTime.t()) :: non_neg_integer()
  def total_paused_time(%__MODULE__{} = attempt, now \\ DateTime.utc_now()) do
    Enum.reduce(attempt.pauses, 0, fn {start, stop}, acc ->
      DateTime.diff(stop || now, start) + acc
    end)
  end

  @spec paused_time(t(), DateTime.t()) :: non_neg_integer()
  def paused_time(attempt, now \\ DateTime.utc_now())

  def paused_time(%__MODULE__{pauses: [{%DateTime{} = start, nil} | _]}, now),
    do: DateTime.diff(now, start)

  def paused_time(_attempt, _now), do: 0

  @spec score(t()) :: non_neg_integer()
  def score(%__MODULE__{} = attempt) when is_scored(attempt) do
    %{puzzle: puzzle, incomplete: incomplete, incorrect: incorrect} = attempt

    white_squares = puzzle.cell_count - puzzle.block_count
    correct = white_squares - incomplete - incorrect

    div(correct * 100, white_squares)
  end

  # Helpers

  @spec finish(t(), DateTime.t()) :: {:ok, t()} | {:error, :already_finished}
  defp finish(%__MODULE__{} = attempt, _finished_at) when is_finished(attempt),
    do: {:error, :already_finished}

  defp finish(%__MODULE__{} = attempt, finished_at),
    do: {:ok, %__MODULE__{resume(attempt, finished_at) | finished_at: finished_at}}

  defp validate_squares_score(%__MODULE__{puzzle: puzzle, incomplete: incomplete}, squares) do
    if squares > Puzzle.white_squares(puzzle) - (incomplete || 0) do
      {:error, :too_many_squares}
    else
      :ok
    end
  end
end
