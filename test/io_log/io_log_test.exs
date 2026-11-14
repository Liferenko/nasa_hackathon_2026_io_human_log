defmodule IoLog.IoLogTest do
  use IoLog.DataCase

  alias IoLog.Event

  describe "record/2" do
    test "records an event with defaults" do
      assert {:ok, %Event{} = event} = IoLog.record(:food_intake)

      assert event.id
      assert event.kind == "food_intake"
      assert event.person == "crew_1"
      assert event.source == "manual_iex"
      assert event.zone == nil
      assert event.payload == %{}
      assert %DateTime{} = event.occurred_at
      assert %DateTime{} = event.inserted_at
    end

    test "accepts a string kind and options" do
      occurred_at = ~U[2026-10-04 12:00:00.000000Z]

      assert {:ok, event} =
               IoLog.record("toilet_number_1",
                 person: "crew_2",
                 source: "mock",
                 zone: "hygiene",
                 payload: %{volume_ml: 320},
                 occurred_at: occurred_at
               )

      assert event.kind == "toilet_number_1"
      assert event.person == "crew_2"
      assert event.source == "mock"
      assert event.zone == "hygiene"
      assert event.occurred_at == occurred_at

      # Payload is stored as JSON and comes back with string keys.
      assert [%Event{payload: %{"volume_ml" => 320}}] = IoLog.list_events(person: "crew_2")
    end

    test "rejects unknown kinds" do
      assert {:error, %Ecto.Changeset{} = changeset} = IoLog.record(:teleport)
      assert %{kind: ["is invalid"]} = errors_on(changeset)
      assert IoLog.list_events() == []
    end

    test "broadcasts recorded events on the events topic" do
      :ok = IoLog.subscribe()
      {:ok, event} = IoLog.record(:water_intake)
      assert_receive {:event_recorded, ^event}
    end
  end

  describe "list_events/1" do
    test "returns events newest first" do
      {:ok, older} = IoLog.record(:food_intake, occurred_at: ~U[2026-10-04 08:00:00.000000Z])
      {:ok, newer} = IoLog.record(:water_intake, occurred_at: ~U[2026-10-04 09:00:00.000000Z])

      assert [first, second] = IoLog.list_events()
      assert first.id == newer.id
      assert second.id == older.id
    end

    test "filters by person" do
      {:ok, _} = IoLog.record(:food_intake, person: "crew_1")
      {:ok, crew_2} = IoLog.record(:toilet_number_2, person: "crew_2")

      assert [event] = IoLog.list_events(person: "crew_2")
      assert event.id == crew_2.id
    end
  end

  test "Event exposes allowed kinds" do
    assert "food_intake" in Event.kinds()
    assert length(Event.kinds()) == 5
    assert "unmapped_scan" in Event.kinds()
  end
end
