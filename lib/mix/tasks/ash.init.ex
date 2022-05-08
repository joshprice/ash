defmodule Mix.Tasks.Ash.Init do
  @moduledoc """
  Configures Ash on a Mix project.

  This task is mostly meant to be used after bootstrapping a fresh project using
  `mix new`. Although it can also be used on existing non-fresh projects, some patches
  might not be applicable as they may depend on file content code/patterns that are no longer available.

  If such cases are detected, the task will inform you which patches were skipped as well as provide
  instructions for manual configuration.

      $ mix ash.init

  ## Important note

  This task is still **experimental**. Make sure you have committed your work or have a proper
  backup before running it. As it may change a few files in the project, it's recommended to
  have a safe way to rollback the changes in case anything goes wrong.

  ## Options

    * `--dry-run` - does not save, delete or patch any file.

  """

  use Mix.Task

  alias Mix.Tasks.Ash.Init.ProjectPatcher
  alias Mix.Tasks.Ash.Init.ExPatcher
  alias Mix.Tasks.Ash.Init.ProjectPatchers

  @switches [
    dry_run: :boolean
  ]

  @default_opts [
    dry_run: false
  ]

  @project_patchers [
    ProjectPatchers.Common,
    ProjectPatchers.Formatter
  ]

  @impl Mix.Task
  def run(args) do
    opts = parse_opts(args)
    assigns = init_assigns(opts)

    Mix.Task.run("app.start")

    unless assigns.yes do
      message = """
      This task will change existing files in your project.

      Make sure you commit your work before running it, especially if this is not a fresh mix project.
      """

      Mix.shell().info([:yellow, "\nNote: ", :reset, message])

      unless Mix.shell().yes?("Do you want to continue?") do
        exit(:normal)
      end
    end

    @project_patchers
    |> ProjectPatcher.run(assigns)
    |> handle_results(assigns)
  end

  defp parse_opts(args) do
    {opts, _parsed} = OptionParser.parse!(args, strict: @switches)
    Keyword.merge(@default_opts, opts)
  end

  defp init_assigns(opts) do
    context_app = Mix.Phoenix.context_app()
    web_path = Mix.Phoenix.web_path(context_app)
    base = Module.concat([Mix.Phoenix.base()])
    web_module = Mix.Phoenix.web_module(base)
    web_module_path = web_module_path(context_app)
    using_gettext? = using_gettext?(web_path, web_module)

    opts
    |> Map.new()
    |> Map.merge(%{
      context_app: context_app,
      app_module: base,
      web_module: web_module,
      web_module_path: web_module_path,
      web_path: web_path,
      using_gettext?: using_gettext?
    })
  end

  defp web_module_path(ctx_app) do
    web_prefix = Mix.Phoenix.web_path(ctx_app)
    [lib_prefix, web_dir] = Path.split(web_prefix)
    Path.join(lib_prefix, "#{web_dir}.ex")
  end

  defp using_gettext?(web_path, web_module) do
    file = Path.join(web_path, "views/error_helpers.ex")
    error_helper = Module.concat(web_module, ErrorHelpers)

    file
    |> ExPatcher.parse_file!()
    |> ExPatcher.enter_defmodule(error_helper)
    |> ExPatcher.enter_def(:translate_error)
    |> ExPatcher.find_code_containing("Gettext.dngettext")
    |> ExPatcher.valid?()
  end

  defp handle_results(results, assigns) do
    %{
      n_patches: n_patches,
      n_files: n_files,
      n_patches_applied: n_patches_applied,
      n_patches_already_patched: n_patches_already_patched,
      n_patches_skipped: n_patches_skipped,
      patches_with_messages: patches_with_messages,
      updated_deps: updated_deps
    } = results

    n_patches_with_messages = length(patches_with_messages)

    Mix.shell().info(["\nFinished running #{n_patches} patches for #{n_files} files."])

    if n_patches_with_messages > 0 do
      Mix.shell().info([:yellow, "#{n_patches_with_messages} messages emitted."])
    end

    summary = "#{n_patches_applied} changes applied, #{n_patches_skipped} skipped."

    if n_patches_already_patched == n_patches do
      Mix.shell().info([:yellow, summary])
      Mix.shell().info([:cyan, "It looks like this project has already been patched."])
    else
      Mix.shell().info([:green, summary])
    end

    print_opts = [doc_bold: [:yellow], doc_underline: [:italic, :yellow], width: 90]

    patches_with_messages
    |> Enum.with_index(1)
    |> Enum.each(fn {{result, file, %{name: name, instructions: instructions}}, index} ->
      {reason, details} =
        case result do
          :maybe_already_patched ->
            {"it seems the patch has already been applied or manually set up", ""}

          :cannot_patch ->
            {"unexpected file content",
             """

             *Either the original file has changed or it has been modified by the user \
             and it's no longer safe to automatically patch it.*
             """}

          :file_not_found ->
            {"file not found", ""}

          :cannot_read_file ->
            {"cannot read file", ""}
        end

      IO.ANSI.Docs.print_headings(["Message ##{index}"], print_opts)

      message = """
      Patch _"#{name}"_ was not applied to `#{file}`.

      Reason: *#{reason}.*
      #{details}
      If you believe you still need to apply this patch, you must do it manually with the following instructions:

      #{instructions}
      """

      IO.ANSI.Docs.print(message, "text/markdown", print_opts)
    end)

    if updated_deps != [] && assigns.install do
      Mix.shell().info("\nThe following dependencies were updated/added to your project:\n")

      for dep <- updated_deps do
        Mix.shell().info(["  * #{dep}"])
      end

      Mix.shell().info("")

      if assigns.yes || Mix.shell().yes?("Do you want to fetch and install them now?") do
        Mix.shell().cmd("mix deps.get", [])
        Mix.shell().cmd("mix deps.compile", [])
      end
    end

    results
  end
end
