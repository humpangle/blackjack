defmodule Demo do
  use GenServer
  @behaviour Blackjack.PlayerNotifier

  alias Blackjack.Hand
  alias Blackjack.RoundServer

  def start_link(_opts \\ []) do
    round_id = :"round_#{:erlang.unique_integer()}"
    player_ids = Enum.map(1..5, &:"player_#{&1}")

    players_map =
      player_ids
      |> Enum.map(&{&1, Hand.new()})
      |> Enum.into(%{})

    state = %{round_id: round_id, players: players_map}
    GenServer.start_link(__MODULE__, state, name: round_id)

    players =
      player_ids
      |> Enum.map(
        &%{
          id: &1,
          callback_mod: __MODULE__,
          callback_arg: round_id
        }
      )

    Blackjack.RoundServer.start_playing(round_id, players)
  end

  @doc false
  def deal_card(round_id, player_id, card),
    do: GenServer.call(round_id, {:deal_card, player_id, card})

  @doc false
  def move(round_id, player_id), do: GenServer.call(round_id, {:move, player_id})

  @doc false
  def busted(round_id, player_id), do: GenServer.call(round_id, {:busted, player_id})

  @doc false
  def unauthorized_move(round_id, player_id),
    do: GenServer.call(round_id, {:unauthorized_move, player_id})

  @doc false
  def winners(round_id, player_id, winners) do
    if Enum.member?(winners, player_id),
      do:
        GenServer.call(
          round_id,
          {:won, player_id}
        )

    :ok
  end

  @doc false
  def init(%{} = state) do
    IO.puts("\n\nGame round: #{state.round_id} starting")

    {:ok, state}
  end

  def handle_call({:deal_card, player_id, card}, _from, state) do
    IO.puts([
      stringify_player(player_id, state.round_id),
      ": #{card.rank} of #{card.suit}"
    ])

    {
      :reply,
      :ok,
      update_in(state.players[player_id], fn hand ->
        {_, new_hand} = Hand.deal(hand, card)
        new_hand
      end)
    }
  end

  @doc false
  def handle_call({:move, player_id}, from, state) do
    GenServer.reply(from, :ok)

    player_str = stringify_player(player_id, state.round_id)

    IO.puts([player_str, ": thinking ..."])

    hand = state.players[player_id]

    :timer.seconds(2) |> :rand.uniform() |> Process.sleep()

    next_move =
      if :rand.uniform(11) + 10 < hand.score do
        :stand
      else
        :hit
      end

    IO.puts([player_str, ": #{next_move}"])

    if next_move == :stand, do: IO.puts("")

    Blackjack.RoundServer.move(state.round_id, player_id, next_move)

    {:noreply, state}
  end

  def handle_call({:busted, player_id}, _from, state) do
    IO.puts([stringify_player(player_id, state.round_id), ": busted\n"])
    {:reply, :ok, state}
  end

  def handle_call({:won, player_id}, _from, %{round_id: round_id} = state) do
    IO.puts([
      stringify_player(player_id, round_id),
      ": won!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n"
    ])

    RoundServer.round_sup_name(round_id) |> Supervisor.stop()

    {:stop, :normal, state}
  end

  defp stringify_player(player_id, round_id), do: "#{round_id}\t#{player_id}"
end
