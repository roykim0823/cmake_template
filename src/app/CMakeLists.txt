add_executable(app main.cpp)

target_link_libraries(
  app
  PRIVATE ${PROJECT_NAME}::options
          ${PROJECT_NAME}::warnings
          CLI11::CLI11
          fmt::fmt
          spdlog::spdlog)


configure_linker(app)

target_include_directories(app PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include")
