# ModuleWorks SDK integration - shared by every target that links against it
# (MillingBackend/MillingInterface, PostProcessorBackend). Included ONCE from
# the root CMakeLists.txt, before add_subdirectory(Modules), and declares its
# targets IMPORTED GLOBAL so both modules' subdirectory scopes can see them -
# a plain (non-GLOBAL) imported target, like a plain set() variable, is only
# visible in the directory it's created in and that directory's own children,
# not in sibling subdirectories such as Modules/ModuleMillingKalotte vs.
# Modules/ModulePostProcessor.
#
# Replaces two former ~113-line, 97%-identical per-module copies of this same
# setup (Modules/ModuleMillingKalotte/MillingBackend/CMakeHelp/ModuleWorksSetup.cmake
# and the ModulePostProcessor equivalent - each hand-listing ~20 include dirs
# and ~24 .lib files from the pre-2026.08 SDK's per-component directory
# layout, and both linking the FULL list into both modules regardless of
# whether either module's code actually used a given component.
#
# What's declared below instead is only the library groups MillingBackend and
# PostProcessorBackend actually #include headers from (verified by grepping
# both modules' sources against the SDK's own include_legacy/proxy_map.json,
# which maps every old header to the new SDK's library grouping):
#   MillingBackend/MillingInterface:  Util, Toolpath, Verifier, 5axui
#   PostProcessorBackend:             Util, Toolpath, MultiXPost, PPInterface, PPConverter
# Everything else the old setup linked into both modules unconditionally -
# 5axmfcuiutils, MachSimIntegration, MeshToolkit, mwCNCSim(InterpolationUtil/
# Visualization/Web), mwJobSetup, mwMSimCollisionChecker, mwRaster2Vector,
# mwSimMfcUiUtils, MXPUI, StockManagerInterface - is unused by either module
# today and was dropped. Add a new ModuleWorks::<Group> target below (and
# link it from the one module that needs it) if that changes.

set(_moduleworks_dir_from_env FALSE)
if(NOT DEFINED MODULEWORKS_DIR AND DEFINED ENV{MODULEWORKS_DIR})
    set(MODULEWORKS_DIR "$ENV{MODULEWORKS_DIR}")
    set(_moduleworks_dir_from_env TRUE)
endif()
set(MODULEWORKS_DIR "${MODULEWORKS_DIR}" CACHE PATH "Path to ModuleWorks SDK root directory")
if(NOT MODULEWORKS_DIR OR NOT EXISTS "${MODULEWORKS_DIR}")
    message(FATAL_ERROR
        "MODULEWORKS_DIR is not set or points to a non-existent path. Set the path to your ModuleWorks SDK"
    )
endif()
if(_moduleworks_dir_from_env)
    message(WARNING
        "MODULEWORKS_DIR was taken from the ENVIRONMENT, not from a preset or -D:\n"
        "    $ENV{MODULEWORKS_DIR}\n"
        "This build therefore depends on per-machine state and will not reproduce on a clean "
        "machine or a CI agent. Declare MODULEWORKS_DIR in CMakeUserPresets.json instead - see "
        "CMakeUserPresets.json.example.")
endif()

# 2026.08+ SDK layout: a single include/ dir, a single lib/ dir, and a single
# bin/ dir for runtime DLLs, replacing the pre-2026.08 SDK's ~20 scattered
# per-component top-level directories (5axui/, mwgeolib/, PPFramework/, ...).
# Headers are self-qualifying now (mw/Util/..., mw/Toolpath/...), so ONE
# include dir covers every library group - no per-group include dir needed.
set(MODULEWORKS_INCLUDE_DIR "${MODULEWORKS_DIR}/include")
set(MODULEWORKS_LIB_DIR "${MODULEWORKS_DIR}/lib")
set(MODULEWORKS_DLL_DIR "${MODULEWORKS_DIR}/bin")

if(NOT EXISTS "${MODULEWORKS_INCLUDE_DIR}")
    message(FATAL_ERROR
        "MODULEWORKS_DIR (${MODULEWORKS_DIR}) does not look like a 2026.08+ ModuleWorks SDK - "
        "'${MODULEWORKS_INCLUDE_DIR}' was not found. This project's CMake expects the new single "
        "include/lib/bin layout, not the pre-2026.08 per-component one."
    )
endif()

# --- License ---------------------------------------------------------------
set(_mw_license_default "${MODULEWORKS_DLL_DIR}/mwSupport.lic")
if(NOT EXISTS "${_mw_license_default}")
    set(_mw_license_default "")
endif()
set(MODULEWORKS_LICENSE_FILE "${_mw_license_default}" CACHE FILEPATH "Path to ModuleWorks license file")

# Fail if license is not found - user set in cmake cache
if(NOT EXISTS "${MODULEWORKS_LICENSE_FILE}")
    message(FATAL_ERROR
        "ModuleWorks license file (mwSupport.lic) not found. Set MODULEWORKS_LICENSE_FILE in cmake options"
    )
endif()

# --- Per-library-group targets ----------------------------------------------
# One small IMPORTED GLOBAL INTERFACE target per ModuleWorks library group -
# each carries only its own .lib(s) plus the other groups its headers depend
# on; the include dir is the same single MODULEWORKS_INCLUDE_DIR for all of
# them. Consumers link only the groups they actually use, e.g.:
#   target_link_libraries(MillingBackend PUBLIC ModuleWorks::Util ModuleWorks::Toolpath ...)
function(_moduleworks_add_target name)
    cmake_parse_arguments(ARG "" "" "LIBS;DEPENDS" ${ARGN})
    add_library(ModuleWorks::${name} INTERFACE IMPORTED GLOBAL)
    target_include_directories(ModuleWorks::${name} INTERFACE "${MODULEWORKS_INCLUDE_DIR}")
    foreach(_lib IN LISTS ARG_LIBS)
        target_link_libraries(ModuleWorks::${name} INTERFACE "${MODULEWORKS_LIB_DIR}/${_lib}")
    endforeach()
    foreach(_dep IN LISTS ARG_DEPENDS)
        target_link_libraries(ModuleWorks::${name} INTERFACE ModuleWorks::${_dep})
    endforeach()
endfunction()

_moduleworks_add_target(Util         LIBS mwUtil.lib)      # basic types, tools, mesh
_moduleworks_add_target(Toolpath    LIBS mwToolpath.lib    DEPENDS Util)
_moduleworks_add_target(Verifier    LIBS mwVerifier.lib    DEPENDS Toolpath Util)
_moduleworks_add_target(MultiXPost  LIBS multixpost.lib    DEPENDS Toolpath Util)
_moduleworks_add_target(PPInterface LIBS PPInterface.lib)
_moduleworks_add_target(PPConverter LIBS MWPPConverter.lib DEPENDS PPInterface MultiXPost)

# Header-only today: the one 5axui header MillingBackend uses (ParamInteractor.hpp,
# for mwParamInteractor) is a pure abstract interface with no out-of-line methods,
# so no .lib is needed - just the shared include dir. If a future change starts
# subclassing/instantiating real 5axui machinery, add LIBS 5axui.lib here.
_moduleworks_add_target(5axui)

# --- Runtime DLL / license staging ------------------------------------------
# Copies every ModuleWorks runtime DLL (+ the license) into a module's own
# deps/ folder. Trimming this to only the DLLs a given module's linked .lib
# subset transitively needs isn't reliably derivable from the SDK alone (only
# ModuleWorks knows the full runtime dependency graph), so every module that
# links any ModuleWorks::* target still gets the full set, same as before.
#
# Stamped rather than a bare add_custom_target(... ALL) (which has no OUTPUT, so it's always
# considered out of date and re-copies ~90 DLLs on every single build, done or not) - same
# pattern as ModulePostProcessorWidget/CMakeLists.txt's PyPy interpreter copy: the stamp lives
# in bin/$<CONFIG> itself (MODULE_OUTPUT_FOLDER's parent, alongside MainApp.exe), findable at a
# glance and named after the copy target (MWCopyKalotte.stamp, MWCopyPP.stamp - matches what
# Visual Studio's Output window already calls these targets), and DEPENDS on the actual DLL list
# so an in-place SDK update (any DLL's mtime changing) re-triggers the copy on its own - the
# PyPy stamp only depends on one file (pypy3.exe) since that copy's source tree isn't glob'd
# ahead of time the way this one already is. install_full/deploy never sweeps bin/$<CONFIG>
# wholesale (see cmake/install_app.cmake.in), so a loose stamp file there is never picked up.
function(moduleworks_copy_runtime target_name output_dir)
    file(GLOB _mw_dlls "${MODULEWORKS_DLL_DIR}/*.dll")
    list(APPEND _mw_dlls "${MODULEWORKS_LICENSE_FILE}")
    set(_stamp "${MODULE_OUTPUT_FOLDER}/../${target_name}.stamp")
    add_custom_command(
        OUTPUT "${_stamp}"
        COMMAND ${CMAKE_COMMAND} -E make_directory "${output_dir}/deps"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different ${_mw_dlls} "${output_dir}/deps"
        COMMAND ${CMAKE_COMMAND} -E touch "${_stamp}"
        DEPENDS ${_mw_dlls}
        COMMENT "Copying all ModuleWorks DLLs to ${output_dir}/deps"
        VERBATIM
    )
    add_custom_target(${target_name} ALL DEPENDS "${_stamp}")
endfunction()
