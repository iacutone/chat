defmodule Chatty.Message do
  defmodule Register do
    defstruct [:username]
  end

  defmodule Broadcast do
    defstruct [:from_username, :contents]
  end
end
