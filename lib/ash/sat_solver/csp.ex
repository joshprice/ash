if Code.ensure_loaded?(Csp) do
  defmodule Ash.SatSolver.Csp do
    @moduledoc """
    An elixir native sat solver, for use if you're having issues with picosat or can't use a NIF for whatever reason.

    This is a bit hacky, as I'm using a constraint solver which is more generic, but just constraining domains to true/false.
    It will also be significantly slower than picosat (not technically verified, but I'm confident in that fact), at least for
    the really complex problems.
    """

    defmodule Constraint do
      @moduledoc false
      defstruct [:scenario, :args]

      defimpl Csp.Constraint do
        def arguments(%{args: args}), do: args

        def satisfies?(constraint, assignment) do
          Enum.any?(constraint.scenario, fn {var, value} ->
            Map.fetch!(assignment, var) == value
          end)
        end
      end
    end

    def solve(integers) do
      variables = integers |> List.flatten() |> Enum.map(&abs/1) |> Enum.uniq()

      %Csp{
        variables: variables,
        domains:
          Enum.into(variables, %{}, fn var ->
            {var, [true, false]}
          end),
        constraints: constraints(integers)
      }
      |> Csp.solve()
      |> case do
        :no_solution ->
          {:error, :unsatisfiable}

        {:solved, assignment} ->
          {:ok, assignment_to_scenario(assignment)}
      end
    end

    defp assignment_to_scenario(assignment) do
      Enum.map(assignment, fn {var, value} ->
        if value do
          var
        else
          -var
        end
      end)
    end

    defp constraints(integers) do
      Enum.map(integers, fn scenario ->
        scenario =
          Enum.map(scenario, fn i ->
            {abs(i), !(i < 0)}
          end)

        %Constraint{
          scenario: scenario,
          args: Enum.map(scenario, &elem(&1, 0))
        }
      end)
    end
  end
end
