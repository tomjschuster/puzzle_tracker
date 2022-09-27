defmodule PuzzleTracker.Crossword.PuzzleAttemptTest do
  use ExUnit.Case
  import TestUtils

  alias PuzzleTracker.Crossword.Puzzle
  alias PuzzleTracker.Crossword.PuzzleAttempt

  describe "Starting a puzzle" do
    test "stores the provided puzzle" do
      puzzle = build_puzzle()
      assert %PuzzleAttempt{puzzle: ^puzzle} = PuzzleAttempt.new(puzzle)
    end

    test "adds a start time timestamp" do
      puzzle = build_puzzle()
      assert %PuzzleAttempt{started_at: started_at} = PuzzleAttempt.new(puzzle)
      assert_recent_timestamp started_at
    end
  end

  describe "Finishing a puzzle" do
    setup do
      %{attempt: PuzzleAttempt.new(build_puzzle())}
    end

    test "sets incompleted squares to 0 when completed", %{attempt: attempt} do
      assert {:ok, %PuzzleAttempt{incomplete: 0}} = PuzzleAttempt.complete(attempt)
    end

    test "sets incompleted squares when conceding", %{attempt: attempt} do
      for i <- 1..10 do
        assert {:ok, %PuzzleAttempt{incomplete: ^i}} = PuzzleAttempt.concede(attempt, i)
      end
    end

    test "concedes with no squares completed", %{attempt: attempt} do
      white_squares = Puzzle.white_squares(attempt.puzzle)

      assert {:ok, %PuzzleAttempt{incomplete: ^white_squares}} =
               PuzzleAttempt.concede(attempt, white_squares)
    end

    test "fails when conceding with more incomplete squares than available", %{attempt: attempt} do
      white_squares = Puzzle.white_squares(attempt.puzzle)
      assert {:error, :too_many_squares} = PuzzleAttempt.concede(attempt, white_squares + 1)
    end

    test "adds a finish time timestamp when completing", %{attempt: attempt} do
      assert {:ok, %PuzzleAttempt{finished_at: finished_at}} = PuzzleAttempt.complete(attempt)
      assert_recent_timestamp finished_at
    end

    test "adds a finish time timestamp when conceding", %{attempt: attempt} do
      assert {:ok, %PuzzleAttempt{finished_at: finished_at}} = PuzzleAttempt.concede(attempt, 1)
      assert_recent_timestamp finished_at
    end

    test "fails when conceding with no incomplete squares", %{attempt: attempt} do
      assert {:error, :no_incomplete} = PuzzleAttempt.concede(attempt, 0)
    end

    test "fails when test is already finished", %{attempt: attempt} do
      {:ok, attempt} = PuzzleAttempt.complete(attempt)
      assert {:error, :already_finished} = PuzzleAttempt.complete(attempt)
    end
  end

  describe "Scoring a puzzle" do
    setup do
      puzzle = build_puzzle()
      attempt = PuzzleAttempt.new(puzzle)
      {:ok, completed} = PuzzleAttempt.complete(attempt)
      {:ok, conceded} = PuzzleAttempt.concede(attempt, 1)

      %{
        in_progress: attempt,
        completed: completed,
        conceded: conceded
      }
    end

    test "sets incorrect blocks for a completed attempt", %{completed: attempt} do
      for i <- 0..10 do
        assert {:ok, %PuzzleAttempt{incorrect: ^i}} = PuzzleAttempt.record_score(attempt, i)
      end
    end

    test "sets incorrect blocks for a conceded attempt", %{conceded: attempt} do
      for i <- 0..10 do
        assert {:ok, %PuzzleAttempt{incorrect: ^i}} = PuzzleAttempt.record_score(attempt, i)
      end
    end

    test "records a complete incorrect score", %{completed: attempt} do
      white_squares = Puzzle.white_squares(attempt.puzzle)

      assert {:ok, %PuzzleAttempt{incorrect: ^white_squares}} =
               PuzzleAttempt.record_score(attempt, white_squares)
    end

    test "fails for a non-finished attempt", %{in_progress: attempt} do
      assert {:error, :not_finished} = PuzzleAttempt.record_score(attempt, 1)
    end

    test "fails for an already scored attempt", %{completed: attempt} do
      {:ok, attempt} = PuzzleAttempt.record_score(attempt, 0)
      assert {:error, :already_scored} = PuzzleAttempt.record_score(attempt, 0)
    end

    test "fails when more incorrect squares than available in grid", %{completed: attempt} do
      white_squares = Puzzle.white_squares(attempt.puzzle)
      assert {:error, :too_many_squares} = PuzzleAttempt.record_score(attempt, white_squares + 1)
    end

    test "fails when more incorrect squares than completed squares", %{conceded: attempt} do
      white_squares = Puzzle.white_squares(attempt.puzzle)
      assert {:error, :too_many_squares} = PuzzleAttempt.record_score(attempt, white_squares)
    end

    test "scores 100 when all correct", %{completed: attempt} do
      assert {:ok, %PuzzleAttempt{} = attempt} = PuzzleAttempt.record_score(attempt, 0)
      assert PuzzleAttempt.score(attempt) == 100
    end

    test "scores 100 when all incorrect", %{completed: attempt} do
      white_squares = Puzzle.white_squares(attempt.puzzle)

      assert {:ok, %PuzzleAttempt{} = attempt} =
               PuzzleAttempt.record_score(attempt, white_squares)

      assert PuzzleAttempt.score(attempt) == 0
    end

    test "rounds percentages", %{completed: attempt} do
      cases = [{37, 75}, {75, 50}, {112, 25}]

      for {incorrect, score} <- cases do
        assert {:ok, %PuzzleAttempt{} = attempt} = PuzzleAttempt.record_score(attempt, incorrect)

        assert PuzzleAttempt.score(attempt) == score
      end
    end

    test "counts incomplete squares as incorrect", %{conceded: attempt} do
      cases = [{0, 99}, {36, 75}, {74, 50}, {111, 25}]

      for {incorrect, score} <- cases do
        assert {:ok, %PuzzleAttempt{} = attempt} = PuzzleAttempt.record_score(attempt, incorrect)

        assert PuzzleAttempt.score(attempt) == score
      end
    end
  end

  describe "Timing a test" do
    setup do
      future_time = DateTime.utc_now() |> DateTime.add(2, :hour)
      one_hour_from_now = DateTime.utc_now() |> DateTime.add(1, :hour)
      forty_five_minutes_from_now = DateTime.utc_now() |> DateTime.add(45, :minute)
      thirty_minutes_from_now = DateTime.utc_now() |> DateTime.add(30, :minute)

      puzzle = build_puzzle()
      attempt = PuzzleAttempt.new(puzzle)

      paused = PuzzleAttempt.pause(attempt, thirty_minutes_from_now)

      {:ok, completed} = PuzzleAttempt.complete(attempt, future_time)
      {:ok, conceded} = PuzzleAttempt.concede(attempt, 1, future_time)

      {:ok, completed_with_pauses} =
        attempt
        |> PuzzleAttempt.pause(thirty_minutes_from_now)
        |> PuzzleAttempt.resume(forty_five_minutes_from_now)
        |> PuzzleAttempt.pause(one_hour_from_now)
        |> PuzzleAttempt.resume(future_time)
        |> PuzzleAttempt.complete(future_time)

      %{
        in_progress: attempt,
        paused: paused,
        completed: completed,
        conceded: conceded,
        completed_with_pauses: completed_with_pauses,
        future_time: future_time,
        one_hour_from_now: one_hour_from_now,
        forty_five_minutes_from_now: forty_five_minutes_from_now,
        thirty_minutes_from_now: thirty_minutes_from_now
      }
    end

    test "measures the total time of an in progress test", %{
      in_progress: attempt,
      future_time: future_time
    } do
      assert PuzzleAttempt.total_time(attempt, future_time) > 0
    end

    test "measures the total time of a completed test", %{completed: attempt} do
      assert PuzzleAttempt.total_time(attempt) > 0
    end

    test "measures the total time of a conceded test", %{completed: attempt} do
      assert PuzzleAttempt.total_time(attempt) > 0
    end

    test "measures paused time when paused", %{
      in_progress: attempt,
      thirty_minutes_from_now: thirty_minutes_from_now,
      forty_five_minutes_from_now: forty_five_minutes_from_now
    } do
      attempt = PuzzleAttempt.pause(attempt, thirty_minutes_from_now)
      assert PuzzleAttempt.paused_time(attempt, forty_five_minutes_from_now) > 0
    end

    test "treats pausing a paused test is a noop", %{paused: attempt} do
      assert PuzzleAttempt.pause(attempt) == attempt
    end

    test "treats resuming a non-paused test is a noop", %{in_progress: attempt} do
      assert PuzzleAttempt.resume(attempt) == attempt
    end

    test "measures paused time as 0 when not paused", %{
      in_progress: attempt,
      future_time: future_time
    } do
      assert PuzzleAttempt.paused_time(attempt, future_time) == 0
    end

    test "measures total paused time", %{
      paused: attempt,
      forty_five_minutes_from_now: forty_five_minutes_from_now,
      one_hour_from_now: one_hour_from_now,
      future_time: future_time
    } do
      first_pause_attempt = PuzzleAttempt.resume(attempt, forty_five_minutes_from_now)

      second_pause_attempt_paused =
        first_pause_attempt
        |> PuzzleAttempt.pause(one_hour_from_now)
        |> PuzzleAttempt.resume(future_time)

      second_pause_attempt_resumed =
        second_pause_attempt_paused
        |> PuzzleAttempt.pause(one_hour_from_now)
        |> PuzzleAttempt.resume(future_time)

      assert PuzzleAttempt.total_paused_time(first_pause_attempt, future_time) > 0

      assert PuzzleAttempt.total_paused_time(second_pause_attempt_paused, future_time) >
               PuzzleAttempt.total_paused_time(first_pause_attempt, future_time)

      assert PuzzleAttempt.total_paused_time(second_pause_attempt_resumed, future_time) >
               PuzzleAttempt.total_paused_time(first_pause_attempt, future_time)
    end

    test "includes paused time in total time", %{
      completed: without_pauses,
      completed_with_pauses: with_pauses,
      future_time: future_time
    } do
      assert PuzzleAttempt.total_time(without_pauses, future_time) > 0

      assert PuzzleAttempt.total_time(without_pauses, future_time) ==
               PuzzleAttempt.total_time(with_pauses, future_time)
    end

    test "doe not include paused time in total time spent", %{
      completed_with_pauses: attempt,
      future_time: future_time
    } do
      total_time_spent = PuzzleAttempt.total_time_spent(attempt, future_time)

      assert total_time_spent > 0

      assert total_time_spent ==
               PuzzleAttempt.total_time(attempt, future_time) -
                 PuzzleAttempt.total_paused_time(attempt, future_time)
    end
  end

  def build_puzzle(overrides \\ %{}) do
    %Puzzle{} =
      Puzzle
      |> struct(%{date: Date.new!(2022, 2, 22), cell_count: 196, block_count: 46})
      |> Map.merge(overrides)
  end
end
