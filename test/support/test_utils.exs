defmodule TestUtils do
  import ExUnit.Assertions

  def assert_recent_timestamp(%DateTime{} = date_time, delta_seconds \\ 1) do
    timestamp = DateTime.to_unix(date_time)
    now = DateTime.to_unix(DateTime.utc_now())
    assert_in_delta timestamp, now, delta_seconds
  end
end
