defmodule PuzzleTracker.Utils.Guards do
  defguard is_pos_integer(term) when is_integer(term) and term > 0
  defguard is_non_neg_integer(term) when is_integer(term) and term >= 0
end
