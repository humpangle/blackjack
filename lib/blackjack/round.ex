defmodule Blackjack.Round do
  alias __MODULE__
  alias Blackjack.Hand
  alias Blackjack.Deck

  defstruct [
    :deck,
    :current_hand,
    :current_player_id,
    :all_players,
    :remaining_players,
    :successful_hands,
    :instructions
  ]

  @opaque t :: %Round{
            deck: Deck.t(),
            current_hand: Hand.t(),
            current_player_id: player_id,
            all_players: [player_id],
            remaining_players: [player_id],
            successful_hands: [%{player_id: player_id, play: Hand.t()}],
            instructions: [instruction]
          }

  @type instruction :: {:notify_player, player_id, player_instruction}

  @type player_instruction ::
          {:deal_card, Deck.card()}
          | :move
          | :busted
          | {:winners, [player_id]}
          | :unauthorized_move

  @type player_id :: any

  @type move :: :stand | :hit

  @spec start([player_id]) :: {[instruction], t}
  def start(players_ids), do: start(players_ids, Deck.shuffled())

  @spec move(t, player_id, move) :: {[instruction], t}
  def move(%Round{current_player_id: player_id} = round, player_id, move),
    do:
      %Round{round | instructions: []}
      |> handle_move(move)
      |> instructions_and_state()

  def move(round, player_id, _move),
    do:
      %Round{round | instructions: []}
      |> notify_player(player_id, :unauthorized_move)
      |> instructions_and_state()

  @doc false
  def start(player_ids, deck) do
    %Round{
      deck: deck,
      current_hand: nil,
      current_player_id: nil,
      all_players: player_ids,
      remaining_players: player_ids,
      successful_hands: [],
      instructions: []
    }
    |> start_new_hand()
    |> instructions_and_state()
  end

  defp start_new_hand(%Round{remaining_players: []} = round) do
    winners = winners(round.successful_hands)

    Enum.reduce(
      round.all_players,
      %Round{round | current_hand: nil, current_player_id: nil},
      &notify_player(&2, &1, {:winners, winners})
    )
  end

  defp start_new_hand(round) do
    [current_player_id | remaining_players] = round.remaining_players

    round = %Round{
      round
      | current_hand: Hand.new(),
        current_player_id: current_player_id,
        remaining_players: remaining_players
    }

    {:ok, round} = deal(round)
    {:ok, round} = deal(round)
    round
  end

  defp handle_move(round, :stand),
    do:
      round
      |> hand_succeeded()
      |> start_new_hand()

  defp handle_move(round, :hit) do
    case deal(round) do
      {:ok, round} ->
        round

      {:busted, round} ->
        round
        |> notify_player(round.current_player_id, :busted)
        |> start_new_hand()
    end
  end

  defp deal(round) do
    {:ok, card, deck} =
      with {:error, :empty} <- Deck.take(round.deck),
           do:
             Deck.shuffled()
             |> Deck.take()

    {hand_status, hand} = Hand.deal(round.current_hand, card)

    round =
      %Round{
        round
        | deck: deck,
          current_hand: hand
      }
      |> notify_player(round.current_player_id, {:deal_card, card})

    {hand_status, round}
  end

  defp hand_succeeded(round) do
    hand_data = %{player_id: round.current_player_id, hand: round.current_hand}
    %Round{round | successful_hands: [hand_data | round.successful_hands]}
  end

  defp winners([]), do: []

  defp winners(successful_hands) do
    max_score = Enum.max_by(successful_hands, & &1.hand.score).hand.score

    successful_hands
    |> Stream.filter(&(&1.hand.score == max_score))
    |> Stream.map(& &1.player_id)
    |> Enum.reverse()
  end

  defp notify_player(round, player_id, data),
    do: update_in(round.instructions, &[{:notify_player, player_id, data} | &1])

  defp instructions_and_state(round),
    do:
      round
      |> tell_current_player_to_move()
      |> take_instructions()

  defp tell_current_player_to_move(%Round{current_player_id: nil} = round), do: round

  defp tell_current_player_to_move(round),
    do: notify_player(round, round.current_player_id, :move)

  defp take_instructions(round),
    do: {
      Enum.reverse(round.instructions),
      %Round{round | instructions: []}
    }
end
