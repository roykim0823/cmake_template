# Doxygen — generates HTML API docs from /// and /** ... */ comments in
# the public headers under include/<projectname>/.
#
# Usage from CMakeLists.txt:
#   if(ENABLE_DOXYGEN)
#     include(cmake/Doxygen.cmake)
#     enable_doxygen()
#   endif()
#
# Output ends up in ${CMAKE_BINARY_DIR}/docs/html/index.html.
# Build the docs with:  cmake --build <build-dir> --target docs
#
# This is opt-in (default OFF) because not every consumer has Doxygen
# installed and the docs target adds noise to `cmake --build`.

macro(enable_doxygen)
  find_package(Doxygen REQUIRED dot OPTIONAL_COMPONENTS mscgen dia)

  if(DOXYGEN_FOUND)
    # Reasonable defaults — override per-project as needed.
    set(DOXYGEN_PROJECT_NAME ${PROJECT_NAME})
    set(DOXYGEN_PROJECT_NUMBER ${PROJECT_VERSION})
    set(DOXYGEN_PROJECT_BRIEF "${PROJECT_DESCRIPTION}")
    set(DOXYGEN_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/docs)
    set(DOXYGEN_GENERATE_HTML YES)
    set(DOXYGEN_GENERATE_LATEX NO)
    set(DOXYGEN_GENERATE_MAN NO)
    set(DOXYGEN_GENERATE_TREEVIEW YES)
    set(DOXYGEN_DISABLE_INDEX NO)
    set(DOXYGEN_FULL_SIDEBAR NO)
    set(DOXYGEN_HAVE_DOT YES)
    set(DOXYGEN_DOT_IMAGE_FORMAT svg)
    set(DOXYGEN_INTERACTIVE_SVG YES)
    set(DOXYGEN_USE_MDFILE_AS_MAINPAGE README.md)
    set(DOXYGEN_RECURSIVE YES)
    set(DOXYGEN_EXTRACT_ALL YES)
    set(DOXYGEN_EXTRACT_PRIVATE NO)
    set(DOXYGEN_EXTRACT_STATIC YES)
    set(DOXYGEN_QUIET YES)
    set(DOXYGEN_WARN_AS_ERROR NO)
    set(DOXYGEN_BUILTIN_STL_SUPPORT YES)

    # Skip generated/build artefacts and third-party code.
    set(DOXYGEN_EXCLUDE_PATTERNS
        */build/*
        */out/*
        */.devcontainer/*
        */fuzz_test/*
        */test/*
        */bench/*
        */_deps/*
        */node_modules/*
        */.git/*)

    # Sources to scan: public headers + library sources + the README.
    doxygen_add_docs(
      docs
      ${PROJECT_SOURCE_DIR}/include
      ${PROJECT_SOURCE_DIR}/src
      ${PROJECT_SOURCE_DIR}/README.md
      WORKING_DIRECTORY ${PROJECT_SOURCE_DIR}
      COMMENT "Generating API documentation with Doxygen")

    message(STATUS "Doxygen target 'docs' available — run: cmake --build <build> --target docs")
  endif()
endmacro()
