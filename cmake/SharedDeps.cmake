# Shared runtime dependency packages for plugin modules.
#
# Every module keeps its PRIVATE runtime DLLs in modulesBert/<Module>/deps/ (unchanged). In
# addition, a runtime package used by several modules (e.g. the ModuleWorks SDK, used by
# ModuleMillingKalotte and ModulePostProcessor) is staged ONCE as a named package:
#
#   bin/<CONFIG>/modulesBert/shared/<Package>/
#
# instead of one full copy per module. Windows loads a DLL once per process by name anyway, so
# the per-module copies never isolated anything - they only duplicated ~90 DLLs and hid
# version mismatches.
#
# Three places refer to a package, kept in sync by onemill_module_uses_shared():
#   1. here (build staging):   onemill_shared_package(<Package> FILES ...)
#   2. the module's plugin metadata JSON (Q_PLUGIN_METADATA ... FILE), "sharedDeps": [...] -
#      read by MainApp (ModuleDllSearchPaths) BEFORE loading the module, to add the package
#      folder to the DLL search path and to report a missing package by name
#   3. the install script (cmake/install_app.cmake.in) - installs shared/<Package> whenever at
#      least one installed module uses it, derived from the ONEMILL_SHARED_PACKAGE_USERS_*
#      global properties recorded below (no per-module *_DEPS option needed)
#
# Rule: a DLL file name must exist in exactly ONE folder (a module's deps/ or one package) -
# Windows does not define the search order between AddDllDirectory folders. The staging step
# below prunes stale copies of a package's files from every module's deps/ (left over from the
# per-module layout), and MainApp logs any remaining duplicate at startup.

set(ONEMILL_SHARED_DEPS_FOLDER "${MODULE_OUTPUT_FOLDER}/shared")
set(_onemill_shared_prune_script "${CMAKE_CURRENT_LIST_DIR}/SharedDepsPrune.cmake")

# onemill_shared_package(<Package> FILES <file>...)
# Stages <file>... into modulesBert/shared/<Package>/ via target SharedDeps_<Package>.
#
# Stamped rather than a bare add_custom_target(... ALL), which would re-copy everything on every
# build - same pattern as the PyPy interpreter copy in ModulePostProcessorWidget/CMakeLists.txt.
# The stamp lives in bin/$<CONFIG> (next to MainApp.exe) and DEPENDS on the file list, so an
# in-place SDK update re-triggers the copy on its own.
function(onemill_shared_package package)
    cmake_parse_arguments(ARG "" "" "FILES" ${ARGN})
    if(NOT ARG_FILES)
        message(FATAL_ERROR "onemill_shared_package(${package}): no FILES given")
    endif()
    if(TARGET SharedDeps_${package})
        message(FATAL_ERROR "onemill_shared_package(${package}): package declared twice")
    endif()

    set(_dest "${ONEMILL_SHARED_DEPS_FOLDER}/${package}")
    set(_stamp "${MODULE_OUTPUT_FOLDER}/../SharedDeps_${package}.stamp")

    set(_names "")
    foreach(_f IN LISTS ARG_FILES)
        get_filename_component(_n "${_f}" NAME)
        list(APPEND _names "${_n}")
    endforeach()
    string(REPLACE ";" "," _names_arg "${_names}")

    add_custom_command(
        OUTPUT "${_stamp}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${_dest}"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${ARG_FILES} "${_dest}"
        COMMAND ${CMAKE_COMMAND}
                "-DMODULES_ROOT=${MODULE_OUTPUT_FOLDER}"
                "-DFILE_NAMES=${_names_arg}"
                -P "${_onemill_shared_prune_script}"
        COMMAND ${CMAKE_COMMAND} -E touch "${_stamp}"
        DEPENDS ${ARG_FILES} "${_onemill_shared_prune_script}"
        COMMENT "Staging shared dependency package ${package} -> ${_dest}"
        VERBATIM
    )
    add_custom_target(SharedDeps_${package} ALL DEPENDS "${_stamp}")
    set_target_properties(SharedDeps_${package} PROPERTIES FOLDER "SharedDeps")

    set_property(GLOBAL APPEND PROPERTY ONEMILL_SHARED_PACKAGES "${package}")
endfunction()

# onemill_module_uses_shared(<plugin target> MODULE <ModuleName> METADATA <plugin json> PACKAGES <Package>...)
# - makes <plugin target> depend on each package's staging target (so building the module, and
#   therefore install_full, always stages it),
# - records <ModuleName> as a user of each package for the install script,
# - FATAL_ERRORs if the plugin metadata JSON's "sharedDeps" does not list exactly these packages,
#   so the runtime declaration and the build declaration can never drift apart.
function(onemill_module_uses_shared plugin_target)
    cmake_parse_arguments(ARG "" "MODULE;METADATA" "PACKAGES" ${ARGN})
    if(NOT ARG_MODULE OR NOT ARG_METADATA OR NOT ARG_PACKAGES)
        message(FATAL_ERROR "onemill_module_uses_shared(${plugin_target}): MODULE, METADATA and PACKAGES are required")
    endif()

    # --- consistency check against the plugin metadata JSON ---
    if(NOT EXISTS "${ARG_METADATA}")
        message(FATAL_ERROR "onemill_module_uses_shared(${plugin_target}): metadata file not found: ${ARG_METADATA}")
    endif()
    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS "${ARG_METADATA}")
    file(READ "${ARG_METADATA}" _json)
    set(_declared "")
    string(JSON _count ERROR_VARIABLE _err LENGTH "${_json}" sharedDeps)
    if(NOT _err)
        if(_count GREATER 0)
            math(EXPR _last "${_count} - 1")
            foreach(_i RANGE ${_last})
                string(JSON _p GET "${_json}" sharedDeps ${_i})
                list(APPEND _declared "${_p}")
            endforeach()
        endif()
    endif()
    set(_expected ${ARG_PACKAGES})
    list(SORT _declared)
    list(SORT _expected)
    if(NOT _declared STREQUAL _expected)
        message(FATAL_ERROR
            "onemill_module_uses_shared(${plugin_target}): \"sharedDeps\" in\n"
            "    ${ARG_METADATA}\n"
            "lists [${_declared}], but CMake declares [${_expected}]. Keep both in sync - MainApp only adds "
            "the packages listed in the plugin metadata to the DLL search path.")
    endif()

    foreach(_pkg IN LISTS ARG_PACKAGES)
        if(NOT TARGET SharedDeps_${_pkg})
            message(FATAL_ERROR "onemill_module_uses_shared(${plugin_target}): unknown shared package '${_pkg}' - "
                "declare it with onemill_shared_package() before add_subdirectory(Modules)")
        endif()
        add_dependencies(${plugin_target} SharedDeps_${_pkg})
        set_property(GLOBAL APPEND PROPERTY ONEMILL_SHARED_PACKAGE_USERS_${_pkg} "${ARG_MODULE}")
    endforeach()
endfunction()

# Generates the package -> using-modules table substituted into install_app.cmake.in
# (@ONEMILL_SHARED_PACKAGE_TABLE@). Call after add_subdirectory(Modules).
function(onemill_shared_package_install_table out_var)
    get_property(_packages GLOBAL PROPERTY ONEMILL_SHARED_PACKAGES)
    set(_table "set(_SHARED_PACKAGES \"${_packages}\")\n")
    foreach(_pkg IN LISTS _packages)
        get_property(_users GLOBAL PROPERTY ONEMILL_SHARED_PACKAGE_USERS_${_pkg})
        list(REMOVE_DUPLICATES _users)
        string(APPEND _table "set(_SHARED_PACKAGE_USERS_${_pkg} \"${_users}\")\n")
    endforeach()
    set(${out_var} "${_table}" PARENT_SCOPE)
endfunction()
