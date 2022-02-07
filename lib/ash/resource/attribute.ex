defmodule Ash.Resource.Attribute do
  @moduledoc "Represents an attribute on a resource"

  defstruct [
    :name,
    :type,
    :allow_nil?,
    :generated?,
    :primary_key?,
    :private?,
    :writable?,
    :always_select?,
    :default,
    :update_default,
    :description,
    sensitive?: false,
    filterable?: true,
    constraints: []
  ]

  @type t :: %__MODULE__{
          name: atom(),
          constraints: Keyword.t(),
          type: Ash.Type.t(),
          primary_key?: boolean(),
          private?: boolean(),
          default: (() -> term),
          update_default: (() -> term) | (Ash.Resource.record() -> term),
          sensitive?: boolean(),
          writable?: boolean()
        }

  alias Ash.OptionsHelpers

  @schema [
    name: [
      type: :atom,
      doc: "The name of the attribute."
    ],
    type: [
      type: :ash_type,
      doc: "The type of the attribute."
    ],
    constraints: [
      type: :keyword_list,
      doc:
        "Constraints to provide to the type when casting the value. See the type's documentation for more information."
    ],
    sensitive?: [
      type: :boolean,
      default: false,
      doc:
        "Whether or not the attribute value contains sensitive information, like PII. If so, it will be redacted while inspecting data."
    ],
    always_select?: [
      type: :boolean,
      default: false,
      doc: """
      Whether or not to always select this attribute when reading from the database.
      Useful if fields are used in read action preparations consistently.

      A primary key attribute *cannot be deselected*, so this option will have no effect.

      Generally, you should favor selecting the field that you need while running your preparation. For example:

      ```elixir
      defmodule MyApp.QueryPreparation.Thing do
        use Ash.Resource.Preparation

        def prepare(query, _, _) do
          query
          |> Ash.Query.select(:attribute_i_need)
          |> Ash.Query.after_action(fn query, results ->
            {:ok, Enum.map(results, fn result ->
              do_something_with_attribute_i_need(result)
            end)}
          end)
        end
      end
      ```

      This will prevent unnecessary fields from being selected.
      """
    ],
    primary_key?: [
      type: :boolean,
      default: false,
      doc:
        "Whether or not the attribute is part of the primary key (one or more fields that uniquely identify a resource). " <>
          "If primary_key? is true, allow_nil? must be false."
    ],
    allow_nil?: [
      type: :boolean,
      default: true,
      doc: "Whether or not the attribute can be set to nil."
    ],
    generated?: [
      type: :boolean,
      default: false,
      doc:
        "Whether or not the value may be generated by the data layer. If it is, the data layer will know to read the value back after writing."
    ],
    writable?: [
      type: :boolean,
      default: true,
      doc: "Whether or not the value can be written to."
    ],
    private?: [
      type: :boolean,
      default: false,
      doc:
        "Whether or not the attribute will appear in any interfaces created off of this resource, e.g AshJsonApi and AshGraphql."
    ],
    update_default: [
      type: {:custom, Ash.OptionsHelpers, :default, []},
      doc:
        "A zero argument function, an {mod, fun, args} triple or a value. `Ash.Changeset.for_update/4` sets the default in the changeset if a value is not provided."
    ],
    filterable?: [
      type: {:or, [:boolean, {:in, [:simple_equality]}]},
      default: true,
      doc: "Whether or not the attribute should be usable in filters."
    ],
    default: [
      type: {:custom, Ash.OptionsHelpers, :default, []},
      doc:
        "A zero argument function, an {mod, fun, args} triple or a value. `Ash.Changeset.for_create/4` sets the default in the changeset if a value is not provided."
    ],
    description: [
      type: :string,
      doc: "An optional description for the attribute."
    ]
  ]

  @create_timestamp_schema @schema
                           |> OptionsHelpers.set_default!(:writable?, false)
                           |> OptionsHelpers.set_default!(:private?, true)
                           |> OptionsHelpers.set_default!(:default, &DateTime.utc_now/0)
                           |> OptionsHelpers.set_default!(:type, Ash.Type.UtcDatetimeUsec)
                           |> OptionsHelpers.set_default!(:allow_nil?, false)

  @update_timestamp_schema @schema
                           |> OptionsHelpers.set_default!(:writable?, false)
                           |> OptionsHelpers.set_default!(:private?, true)
                           |> OptionsHelpers.set_default!(:default, &DateTime.utc_now/0)
                           |> OptionsHelpers.set_default!(
                             :update_default,
                             &DateTime.utc_now/0
                           )
                           |> OptionsHelpers.set_default!(:type, Ash.Type.UtcDatetimeUsec)
                           |> OptionsHelpers.set_default!(:allow_nil?, false)

  @uuid_primary_key_schema @schema
                           |> OptionsHelpers.set_default!(:writable?, false)
                           |> OptionsHelpers.set_default!(:default, &Ash.UUID.generate/0)
                           |> OptionsHelpers.set_default!(:primary_key?, true)
                           |> OptionsHelpers.set_default!(:type, Ash.Type.UUID)
                           |> Keyword.delete(:allow_nil?)

  @integer_primary_key_schema @schema
                              |> OptionsHelpers.set_default!(:writable?, false)
                              |> OptionsHelpers.set_default!(:primary_key?, true)
                              |> OptionsHelpers.set_default!(:generated?, true)
                              |> OptionsHelpers.set_default!(:type, Ash.Type.Integer)
                              |> Keyword.delete(:allow_nil?)

  @doc false
  def attribute_schema, do: @schema
  def create_timestamp_schema, do: @create_timestamp_schema
  def update_timestamp_schema, do: @update_timestamp_schema
  def uuid_primary_key_schema, do: @uuid_primary_key_schema
  def integer_primary_key_schema, do: @integer_primary_key_schema
end
