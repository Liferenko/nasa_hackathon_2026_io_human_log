defmodule IoLog.Repo.Migrations.CreateEvents do
  use Ecto.Migration

  def change do
    create table(:events) do
      add :kind, :string, null: false
      add :person, :string, null: false, default: "crew_1"
      add :source, :string, null: false, default: "manual_iex"
      add :zone, :string
      add :payload, :map, null: false, default: %{}
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:events, [:occurred_at])
    create index(:events, [:person, :occurred_at])
    create index(:events, [:kind])
  end
end
