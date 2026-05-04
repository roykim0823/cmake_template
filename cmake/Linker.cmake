macro(configure_linker project_name)
  set(USER_LINKER_OPTION
    "DEFAULT"
      CACHE STRING "Linker to be used")
    set(USER_LINKER_OPTION_VALUES "DEFAULT" "SYSTEM" "LLD" "GOLD" "BFD" "MOLD" "SOLD" "APPLE_CLASSIC")
  set_property(CACHE USER_LINKER_OPTION PROPERTY STRINGS ${USER_LINKER_OPTION_VALUES})
  list(
    FIND
    USER_LINKER_OPTION_VALUES
    ${USER_LINKER_OPTION}
    USER_LINKER_OPTION_INDEX)

  if(${USER_LINKER_OPTION_INDEX} EQUAL -1)
    message(
      STATUS
        "Using custom linker: '${USER_LINKER_OPTION}', explicitly supported entries are ${USER_LINKER_OPTION_VALUES}")
  endif()

  set_target_properties(${project_name} PROPERTIES LINKER_TYPE "${USER_LINKER_OPTION}")
endmacro()
