defmodule CooxWeb.RecipeLive.Form do
  use CooxWeb, :live_view

  alias Coox.Recipes
  alias Coox.Recipes.Recipe

  @uploads_dir Path.join([:code.priv_dir(:coox), "static", "uploads"])

  def render(assigns) do
    ~H"""
    <.header>{@page_title}</.header>

    <.simple_form for={@form} id="recipe-form" phx-change="validate" phx-submit="save">
      <div>
        <.label>Image</.label>
        <%= for entry <- @uploads.image.entries do %>
          <figure class="flex justify-around">
            <div>
              <.live_img_preview entry={entry} class="rounded max-h-64 shadow" />
              <figcaption class="text-center text-sm text-gray-700 mt-2">
                {entry.client_name}
              </figcaption>
            </div>
          </figure>
        <% end %>
        <.live_file_input upload={@uploads.image} class="mt-2" />
      </div>
      <.input field={@form[:name]} type="text" label="Name" phx-debounce />
      <.input
        field={@form[:description]}
        type="textarea"
        label="Description"
        phx-debounce
        phx-hook="MaintainHeight"
      />

      <:actions>
        <div class="flex">
          <.button phx-disable-with="Saving...">Save Recipe</.button>
          <.loading_spinner class="hidden phx-submit-loading:inline-block ml-4 mb-5" />
        </div>
      </:actions>
    </.simple_form>

    <.back navigate={~p"/"}>Back</.back>
    """
  end

  def mount(params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:image,
       accept: ~w(.png .jpg),
       max_entries: 1,
       max_file_size: 2 * 1024 * 1024
     )
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    recipe = Recipes.get_recipe!(id, socket.assigns.current_user)

    socket
    |> assign(:page_title, "Edit Recipe")
    |> assign(:recipe, recipe)
    |> assign(:form, to_form(Recipes.change_recipe(recipe)))
  end

  defp apply_action(socket, :new, _params) do
    recipe = %Recipe{}

    socket
    |> assign(:page_title, "New Recipe")
    |> assign(:recipe, recipe)
    |> assign(:form, to_form(Recipes.change_recipe(recipe)))
  end

  def handle_event("validate", %{"recipe" => recipe_params}, socket) do
    changeset = Recipes.change_recipe(socket.assigns.recipe, recipe_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"recipe" => recipe_params}, socket) do
    case save_recipe(socket, socket.assigns.live_action, recipe_params) do
      {:ok, recipe} ->
        image_path =
          socket
          |> consume_uploaded_entries(:image, fn %{path: path}, _entry ->
            dest = Path.join(@uploads_dir, Path.basename(path))
            File.cp!(path, dest)
            {:ok, Path.basename(dest)}
          end)
          |> List.first()

        if image_path do
          Recipes.update_recipe_image_path!(recipe, image_path, socket.assigns.current_user)
        end

        flash_msg =
          case socket.assigns.live_action do
            :new -> "Recipe created successfully"
            :edit -> "Recipe updated successfully"
          end

        {:noreply,
         socket
         |> put_flash(:info, flash_msg)
         |> push_navigate(to: ~p"/recipes/#{recipe}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_recipe(socket, :edit, recipe_params) do
    Recipes.update_recipe(socket.assigns.recipe, recipe_params, socket.assigns.current_user)
  end

  defp save_recipe(socket, :new, recipe_params) do
    Recipes.create_recipe(recipe_params, socket.assigns.current_user)
  end
end
