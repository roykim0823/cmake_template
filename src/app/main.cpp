#include <CLI/CLI.hpp>
#include <cstdlib>
#include <exception>
#include <fmt/core.h>
#include <optional>
#include <spdlog/spdlog.h>
#include <string>

// This file is generated automatically when you run the CMake configuration
// step. It creates a namespace named after the project. You can modify the
// source template at `configured_files/config.hpp.in`.
#include <internal_use_only/config.hpp>


// NOLINTNEXTLINE(bugprone-exception-escape)
int main(int argc, const char **argv)
{
  try {
    CLI::App app{ fmt::format("{} version {}",
      myproject::cmake::project_name,
      myproject::cmake::project_version) };

    bool show_version = false;
    app.add_flag("--version", show_version, "Show version information");

    std::optional<std::string> message;
    app.add_option("-m,--message", message, "A message to print");

    CLI11_PARSE(app, argc, argv);

    if (show_version) {
      fmt::print("{}\n", myproject::cmake::project_version);
      return EXIT_SUCCESS;
    }

    if (message) {
      fmt::print("{}\n", *message);
    } else {
      fmt::print("Hello from {} v{}\n",
        myproject::cmake::project_name,
        myproject::cmake::project_version);
    }
    return EXIT_SUCCESS;
  } catch (const std::exception &e) {
    spdlog::error("Unhandled exception in main: {}", e.what());
    return EXIT_FAILURE;
  }
}
