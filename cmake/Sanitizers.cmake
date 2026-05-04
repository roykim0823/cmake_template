function(
  enable_sanitizers
  project_name
  ENABLE_SANITIZER_ADDRESS
  ENABLE_SANITIZER_LEAK
  ENABLE_SANITIZER_UNDEFINED_BEHAVIOR
  ENABLE_SANITIZER_THREAD
  ENABLE_SANITIZER_MEMORY)

  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU" OR CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
    set(SANITIZERS "")

    if(${ENABLE_SANITIZER_ADDRESS})
      list(APPEND SANITIZERS "address")
    endif()

    if(${ENABLE_SANITIZER_LEAK})
      # LeakSanitizer is unsupported on Apple platforms (the linker rejects
      # -fsanitize=leak on macOS, including arm64). On Apple, leak detection
      # is provided by AddressSanitizer with ASAN_OPTIONS=detect_leaks=1.
      if(APPLE)
        message(WARNING "Leak sanitizer is not supported on Apple platforms; ignoring ENABLE_SANITIZER_LEAK")
      else()
        list(APPEND SANITIZERS "leak")
      endif()
    endif()

    if(${ENABLE_SANITIZER_UNDEFINED_BEHAVIOR})
      list(APPEND SANITIZERS "undefined")
    endif()

    if(${ENABLE_SANITIZER_THREAD})
      if("address" IN_LIST SANITIZERS OR "leak" IN_LIST SANITIZERS)
        message(WARNING "Thread sanitizer does not work with Address and Leak sanitizer enabled")
      else()
        list(APPEND SANITIZERS "thread")
      endif()
    endif()

    if(${ENABLE_SANITIZER_MEMORY} AND CMAKE_CXX_COMPILER_ID MATCHES ".*Clang")
      message(
        WARNING
          "Memory sanitizer requires all the code (including libc++) to be MSan-instrumented otherwise it reports false positives"
      )
      if("address" IN_LIST SANITIZERS
         OR "thread" IN_LIST SANITIZERS
         OR "leak" IN_LIST SANITIZERS)
        message(WARNING "Memory sanitizer does not work with Address, Thread or Leak sanitizer enabled")
      else()
        list(APPEND SANITIZERS "memory")
      endif()
    endif()
  endif()

  list(
    JOIN
    SANITIZERS
    ","
    LIST_OF_SANITIZERS)

  if(LIST_OF_SANITIZERS AND NOT "${LIST_OF_SANITIZERS}" STREQUAL "")
    target_compile_options(${project_name} INTERFACE -fsanitize=${LIST_OF_SANITIZERS})
    target_link_options(${project_name} INTERFACE -fsanitize=${LIST_OF_SANITIZERS})
  endif()

endfunction()



