defmodule Ecto.Schema.Serializer do
  @moduledoc """
  Callbacks used by `Ecto.Type` and adapters to serialize and cast models.
  """
  alias Ecto.Schema.Metadata

  @doc """
  Loads recursively given model from data.

  Data can be either a map with string keys or a tuple of index and row,
  where index specifies the place in the row, where data for loading model
  starts.
  """
  def load!(model, source, data, id_types) do
    source = source || model.__schema__(:source)
    struct = model.__struct__()
    fields = model.__schema__(:fields_with_types)

    loaded = do_load(struct, fields, data, id_types)
    loaded = Map.put(loaded, :__meta__, %Metadata{state: :loaded, source: source})
    Ecto.Model.Callbacks.__apply__(model, :after_load, loaded)
  end

  defp do_load(struct, fields, map, id_types) when is_map(map) do
    Enum.reduce(fields, struct, fn
      {field, type}, acc ->
        value = Ecto.Type.load!(type, Map.get(map, Atom.to_string(field)), id_types)
        Map.put(acc, field, value)
    end)
  end

  defp do_load(struct, fields, {idx, values}, id_types) when is_integer(idx) and is_tuple(values) do
    Enum.reduce(fields, {struct, idx}, fn
      {field, type}, {acc, idx} ->
        value = Ecto.Type.load!(type, elem(values, idx), id_types)
        {Map.put(acc, field, value), idx + 1}
    end) |> elem(0)
  end

  @doc """
  Dumps recursively given model's struct.

  ## Options:

    * `:skip_pk` - whether primary keys should be dumped (default: `false`)

  """
  def dump!(struct, id_types, opts \\ []) do
    model  = struct.__struct__
    fields = model.__schema__(:fields_with_types)
    pks = if Keyword.get(opts, :skip_pk, false),
            do: model.__schema__(:primary_key),
            else: []

    Enum.reduce(fields, %{}, &do_dump(struct, &1, &2, pks, id_types))
  end

  defp do_dump(struct, {field, type}, acc, pks, id_types) do
    if field in pks do
      acc
    else
      value = Map.get(struct, field)
      Map.put(acc, field, Ecto.Type.dump!(type, value, id_types))
    end
  end
end
