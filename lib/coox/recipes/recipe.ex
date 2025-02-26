defmodule Coox.Recipes.Recipe do
  use Ecto.Schema
  import Ecto.Changeset

  alias Coox.Accounts.User
  alias Coox.Recipes.Ingredient
  alias Coox.Recipes.Instruction

  schema "recipes" do
    field :name, :string
    field :description, :string
    field :image_path, :string
    field :rating, :float

    has_many :ingredients, Ingredient, on_replace: :delete, preload_order: [asc: :order]

    embeds_many :instructions, Instruction, on_replace: :delete

    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(recipe, attrs) do
    recipe
    |> cast(attrs, [:name, :description, :rating])
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
  end
end
