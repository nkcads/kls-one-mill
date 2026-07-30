cmake_minimum_required(VERSION 3.16)
project(KLSOneMill)

# Group generated projects into Visual Studio solution folders (see the
# "VS solution folders" assignment block at the bottom of this file).
set_property(GLOBAL PROPERTY USE_FOLDERS ON)
set_property(GLOBAL PROPERTY PREDEFINED_TARGETS_FOLDER "CMakePredefinedTargets")

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MT")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO} /MT")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MTd")

if(MSVC AND DEFINED CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Release;RelWithDebInfo" CACHE STRING "" FORCE)
endif()

set(IGL_WITH_VULKAN OFF CACHE BOOL "" FORCE)

# Set VTK_DIR from env if available
set(VTK_DIR_DEFAULT "VTK_DIR_NOTFOUND")
if(DEFINED ENV{VTK_DIR})
    set(VTK_DIR_DEFAULT "$ENV{VTK_DIR}")
endif()
set(VTK_DIR "${VTK_DIR_DEFAULT}" CACHE PATH "Path to vtk lib/cmake/vtk-9.4 directory")

set(MAIN_APP_NAME "KLSOneMill")

#####VCPKG START

# Set VCPKG_ROOT from env if available
if(NOT DEFINED VCPKG_ROOT AND DEFINED ENV{VCPKG_ROOT})
    set(VCPKG_ROOT "$ENV{VCPKG_ROOT}" CACHE PATH "VCPKG root directory")
endif()

set(VCPKG_ROOT "${VCPKG_ROOT}" CACHE PATH "Path to vcpkg root directory")
if(NOT DEFINED VCPKG_ROOT OR NOT EXISTS "${VCPKG_ROOT}")
    message(FATAL_ERROR "VCPKG_ROOT not set or invalid. Set it manually.")
endif()


set(CMAKE_TOOLCHAIN_FILE "${VCPKG_ROOT}/scripts/buildsystems/vcpkg.cmake")

if(CMAKE_TOOLCHAIN_FILE)
    include(${CMAKE_TOOLCHAIN_FILE})
	message(STATUS "VCPKG CMAKE_TOOLCHAIN_FILE = ${CMAKE_TOOLCHAIN_FILE}")
else()
	message(FATAL_ERROR "VCPKG NOT FOUND CMAKE_TOOLCHAIN_FILE = ${CMAKE_TOOLCHAIN_FILE}")
endif(CMAKE_TOOLCHAIN_FILE)

set(VCPKG_TARGET_TRIPLET "x64-windows-static")
message(STATUS "VCPKG_TARGET_TRIPLET = ${VCPKG_TARGET_TRIPLET}")

#####VCPKG END

find_package(cpr CONFIG REQUIRED)
find_package(libzippp CONFIG REQUIRED)
find_package(pugixml CONFIG REQUIRED)
find_package(VTK REQUIRED)
find_package(spdlog CONFIG REQUIRED)
find_package(Clipper2 CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets OpenGL OpenGLWidgets Network)
find_package(Boost REQUIRED COMPONENTS system)


# Define your global output structure
set(OUTPUT_BASE_DIR ${CMAKE_BINARY_DIR}/bin/${CMAKE_BUILD_TYPE})

# Pass these to subprojects
set(GLOBAL_RUNTIME_DIR ${OUTPUT_BASE_DIR})
set(GLOBAL_PLUGIN_DIR ${OUTPUT_BASE_DIR}/plugins)
set(GLOBAL_ARCHIVE_DIR ${CMAKE_BINARY_DIR}/lib)

add_subdirectory(ModuleInterface)
add_subdirectory(BackendUtils)
add_subdirectory(GeneralUtils)
add_subdirectory(ModuleUtils)
add_subdirectory(MainApp)
add_subdirectory(Updater)

set(MODULE_OUTPUT_FOLDER "${CMAKE_BINARY_DIR}/bin/$<CONFIG>/modulesBert")


add_subdirectory(Modules)


# ModuleWorks setup

# === Fast deploy knobs (override at configure time) ===
set(DEPLOY_DIR "D:/deployData/KLSOneMill" )
set(DEPLOY_EXE "D:/deployData/KLSOneMill/MainApp.exe" )

# Find windeployqt once
find_program(WINDEPLOYQT_EXECUTABLE NAMES windeployqt windeployqt.exe HINTS "$ENV{QTDIR}/bin")
if(NOT WINDEPLOYQT_EXECUTABLE)
  message(FATAL_ERROR "windeployqt not found. Set QTDIR or WINDEPLOYQT_EXECUTABLE.")
endif()

# Small cmake script that does the work (generated once)
set(_deploy_script "${CMAKE_BINARY_DIR}/cmake/deploy_qt_vtk.cmake")
file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/cmake")
file(WRITE "${_deploy_script}" [=[
# --- deploy_qt_vtk.cmake ---
# Inputs via -D: OUTDIR, OVERRIDE_EXE, APP_EXE, ALL_DLLS, WINDEPLOY, CFGFLAG
if(NOT DEFINED OUTDIR OR OUTDIR STREQUAL "")
  message(FATAL_ERROR "OUTDIR not set")
endif()

# Choose EXE: override path wins if provided
set(_exe "${APP_EXE}")
if(DEFINED OVERRIDE_EXE AND NOT OVERRIDE_EXE STREQUAL "")
  set(_exe "${OVERRIDE_EXE}")
endif()
if(NOT EXISTS "${_exe}")
  message(FATAL_ERROR "APP EXE not found: ${_exe}")
endif()

file(MAKE_DIRECTORY "${DEPLOY_DIR}")

# 1) Qt deploy
execute_process(
  COMMAND "${WINDEPLOY}" ${CFGFLAG}
          --no-translations --no-quick-import
          --no-system-d3d-compiler --no-compiler-runtime
          --dir "${OUTDIR}" "${_exe}"
  RESULT_VARIABLE _qt_rc
  ERROR_VARIABLE  _qt_err
)
if(NOT _qt_rc EQUAL 0)
  message(FATAL_ERROR "windeployqt failed: ${_qt_err}")
endif()

# 2) VTK-only DLL copy (no version pattern)
set(_dlls ${ALL_DLLS})
list(REMOVE_DUPLICATES _dlls)
foreach(d IN LISTS _dlls)
  if(d MATCHES [[(^|/|\\)vtk[^/\\]*\.dll$]] OR d MATCHES [[(^|/|\\)vtksys[^/\\]*\.dll$]])
    file(COPY "${d}" DESTINATION "${OUTDIR}")
  endif()
endforeach()

message(STATUS "Deploy done -> ${OUTDIR}")
]=])

# Make the 'deploy' target fast to run
# If DEPLOY_EXE is not given, we depend on building the app first.
set(_deploy_deps)
if(NOT DEPLOY_EXE)
  list(APPEND _deploy_deps ${PROJECT_NAME})
endif()

add_custom_target(deploy
  DEPENDS ${_deploy_deps}
  COMMAND ${CMAKE_COMMAND}
          -DOUTDIR=${DEPLOY_DIR}
          -DOVERRIDE_EXE=${DEPLOY_EXE}
         # -DAPP_EXE=$<TARGET_FILE:${PROJECT_NAME}>
          -DALL_DLLS=$<TARGET_RUNTIME_DLLS:MainApp>
          -DWINDEPLOY=${WINDEPLOYQT_EXECUTABLE}
          -DCFGFLAG=--release
          -P "${_deploy_script}"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
          "${CMAKE_SOURCE_DIR}/releaseNotes"
          "${DEPLOY_DIR}/releaseNotes"
  VERBATIM
  COMMENT "Deploying Qt & VTK (VTK-only DLLs)"
)

# ============================================================
# Install targets  (install_full  /  install_plugins)
# ============================================================
# Configure via cmake -D or cmake-gui:
#   INSTALL_DIR               — destination root directory
#   INSTALL_MOD_<NAME>        — ON/OFF per module
#   INSTALL_MOD_MILLING_DEPS  — include ModuleWorks fw DLLs for MillingKalotte
#   INSTALL_MOD_PP_DEPS       — include ModuleWorks fw + PyPy for PostProcessor

set(INSTALL_DIR "D:/deployData/KLSOneMill" CACHE PATH "Install destination directory")

option(INSTALL_MOD_VIEW          "Install ModuleView"            ON)
option(INSTALL_MOD_OVERLAY       "Install ModuleOverlayCritter"  ON)
option(INSTALL_MOD_MILLING       "Install ModuleMillingKalotte"  ON)
option(INSTALL_MOD_PP            "Install ModulePostProcessor"   ON)
option(INSTALL_MOD_STATISTICS    "Install ModuleStatistics"      ON)
option(INSTALL_MOD_REPORTER      "Install ModuleReporter"        ON)
option(INSTALL_MOD_FIXTURE       "Install ModuleFixture"         ON)
option(INSTALL_MOD_FILETRANSFER  "Install ModuleFileTransfer"    ON)
option(INSTALL_MOD_FITTING       "Install ModuleFittingAnalysis" ON)
option(INSTALL_MOD_UPDATER       "Install ModuleUpdater"         ON)

option(INSTALL_MOD_MILLING_DEPS  "Install ModuleMillingKalotte MW framework DLLs" ON)
option(INSTALL_MOD_PP_DEPS       "Install ModulePostProcessor MW framework + PyPy" ON)

set(INSTALL_APP_NAME "" CACHE STRING "Override applicationName written to mainAppConfig.json (empty = leave unchanged)")

configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/install_app.cmake.in"
  "${CMAKE_BINARY_DIR}/cmake/install_app.cmake"
  @ONLY
)

set(_install_script "${CMAKE_BINARY_DIR}/cmake/install_app.cmake")

add_custom_target(install_full
  DEPENDS MainApp Updater
  COMMAND ${CMAKE_COMMAND}
          -DINSTALL_MODE=full
          -DAPP_EXE=$<TARGET_FILE:MainApp>
          -DUPDATER_EXE=$<TARGET_FILE:Updater>
          "-DALL_DLLS=$<TARGET_RUNTIME_DLLS:MainApp>"
          -DBUILD_DIR=$<TARGET_FILE_DIR:MainApp>
          -DCONFIG=$<CONFIG>
          -P "${_install_script}"
  VERBATIM
  COMMENT "Full install -> ${INSTALL_DIR}"
)

add_custom_target(install_plugins
  DEPENDS MainApp Updater
  COMMAND ${CMAKE_COMMAND}
          -DINSTALL_MODE=plugins
          -DAPP_EXE=$<TARGET_FILE:MainApp>
          -DUPDATER_EXE=$<TARGET_FILE:Updater>
          "-DALL_DLLS=$<TARGET_RUNTIME_DLLS:MainApp>"
          -DBUILD_DIR=$<TARGET_FILE_DIR:MainApp>
          -DCONFIG=$<CONFIG>
          -P "${_install_script}"
  VERBATIM
  COMMENT "Plugins-only install -> ${INSTALL_DIR}"
)

# ============================================================
# Standalone "KLSOneAnalyse" install target (install_fitting)
# ============================================================
# Deploys MainApp into its own install directory (separate from INSTALL_DIR)
# with only ModuleView, ModuleStatistics and ModuleFittingAnalysis enabled,
# and applicationName forced to "KLSOneAnalyse" in mainAppConfig.json.

set(INSTALL_DIR_FITTING "D:/deployData/KLSOneAnalyse" CACHE PATH "Install destination for the standalone Fitting Analysis (KLSOneAnalyse) deployment")

# Override the shared options() variables just for this second configure_file()
# generation — the install_full / install_plugins script above was already
# configured with the original values, so this does not affect it.
set(INSTALL_DIR            "${INSTALL_DIR_FITTING}")
set(INSTALL_APP_NAME       "KLSOneAnalyse")
set(INSTALL_MOD_VIEW          ON)
set(INSTALL_MOD_OVERLAY       OFF)
set(INSTALL_MOD_MILLING       OFF)
set(INSTALL_MOD_PP            OFF)
set(INSTALL_MOD_STATISTICS    ON)
set(INSTALL_MOD_REPORTER      OFF)
set(INSTALL_MOD_FIXTURE       OFF)
set(INSTALL_MOD_FILETRANSFER  OFF)
set(INSTALL_MOD_FITTING       ON)
set(INSTALL_MOD_UPDATER       OFF)
set(INSTALL_MOD_MILLING_DEPS  OFF)
set(INSTALL_MOD_PP_DEPS       OFF)

configure_file(
  "${CMAKE_SOURCE_DIR}/cmake/install_app.cmake.in"
  "${CMAKE_BINARY_DIR}/cmake/install_app_fitting.cmake"
  @ONLY
)

set(_install_script_fitting "${CMAKE_BINARY_DIR}/cmake/install_app_fitting.cmake")

add_custom_target(install_fitting
  DEPENDS MainApp
  COMMAND ${CMAKE_COMMAND}
          -DINSTALL_MODE=full
          -DAPP_EXE=$<TARGET_FILE:MainApp>
          "-DALL_DLLS=$<TARGET_RUNTIME_DLLS:MainApp>"
          -DBUILD_DIR=$<TARGET_FILE_DIR:MainApp>
          -DCONFIG=$<CONFIG>
          -P "${_install_script_fitting}"
  VERBATIM
  COMMENT "KLSOneAnalyse (Fitting Analysis) standalone install -> ${INSTALL_DIR_FITTING}"
)

# ============================================================
# Visual Studio solution folders
# ============================================================
# Groups the generated projects in the VS Solution Explorer. Silently skips
# any target that doesn't exist in the current configuration (e.g. a module
# not added via add_subdirectory).
function(assign_solution_folder _folder)
  foreach(_target IN LISTS ARGN)
    if(TARGET ${_target})
      set_target_properties(${_target} PROPERTIES FOLDER "${_folder}")
    endif()
  endforeach()
endfunction()

# MainApp + shared/general libraries
assign_solution_folder("MainApp"
  MainApp
  Updater
  ModuleInterface
  BackendUtils
  ModuleUtils
  MeshLogic
  OpenXLSX
)

# One folder per module, backend + frontend grouped together
assign_solution_folder("Modules/ModuleView"           ModuleView)
assign_solution_folder("Modules/ModuleOverlayCritter" ModuleOverlayCritter)
assign_solution_folder("Modules/ModuleMillingKalotte" ModuleMillingKalotte MillingBackend MillingInterface)
assign_solution_folder("Modules/ModulePostProcessor"  ModulePostProcessor PostProcessorBackend)
assign_solution_folder("Modules/ModuleStatistics"     ModuleStatistics StatisticsBackend)
assign_solution_folder("Modules/ModuleReporter"       ModuleReporter ReporterBackend)
assign_solution_folder("Modules/ModuleFixture"        ModuleFixture FixtureBackend)
assign_solution_folder("Modules/ModuleFileTransfer"   ModuleFileTransfer FileTransferBackend FileTransferClient)
assign_solution_folder("Modules/ModuleFittingAnalysis" ModuleFittingAnalysis FittingAnalysisBackend)
assign_solution_folder("Modules/ModuleUpdater"        ModuleUpdater UpdaterBackend)

# Install / deploy custom targets
assign_solution_folder("Install" deploy install_full install_plugins install_fitting)

# ============================================================
# install_full must be self-sufficient
# ============================================================
# install_full declares only DEPENDS MainApp Updater. MainApp links neither the
# ten plugin DLLs nor the add_custom_target(... ALL) copy targets that populate
# modulesBert/<Module>/{config,deps,releaseNotes,interpreter}, so building the
# install target on its own stages whatever happens to be left in bin/ - which
# is how an incomplete package gets produced with nothing reporting an error.
#
# It also made the target unusable from the CMake Tools sidebar, which
# substitutes its own selected target into every build step of a workflow
# preset (see the gotchas in .vscode/OneMill-Setup-Ledger.md).
#
# Depend on every buildable target in the tree instead. Kept as a walk rather
# than a hand-written list so a new module is covered without touching this.
# The sibling orchestration targets are excluded: depending on them would run
# the other installs as a side effect of this one.
set(_onemill_orchestration deploy install_full install_plugins install_fitting)

function(onemill_collect_targets OUT_VAR _dir)
  set(_acc "")
  get_property(_here DIRECTORY "${_dir}" PROPERTY BUILDSYSTEM_TARGETS)
  list(APPEND _acc ${_here})
  get_property(_subs DIRECTORY "${_dir}" PROPERTY SUBDIRECTORIES)
  foreach(_sub IN LISTS _subs)
    onemill_collect_targets(_sub_targets "${_sub}")
    list(APPEND _acc ${_sub_targets})
  endforeach()
  set(${OUT_VAR} "${_acc}" PARENT_SCOPE)
endfunction()

# Scoped to Modules/ on purpose. A whole-tree walk also picks up third-party
# extras - OpenXLSX contributes a 'Documentation' target that shells out to
# Doxygen and EXCLUDE_FROM_ALL benchmarks. Those sit behind OPENXLSX_* options
# today, but depending on a third-party default is how a slow or broken install
# appears months later. The shared libraries need no mention either: the module
# DLLs link them, so they build regardless.
onemill_collect_targets(_onemill_targets "${CMAKE_SOURCE_DIR}/Modules")
list(APPEND _onemill_targets MainApp Updater)
list(REMOVE_ITEM _onemill_targets ${_onemill_orchestration})
list(REMOVE_DUPLICATES _onemill_targets)

# INTERFACE libraries build nothing, and an EXCLUDE_FROM_ALL target was excluded
# deliberately - depending on it here would quietly put it back into the build.
set(_onemill_install_deps "")
foreach(_t IN LISTS _onemill_targets)
  if(NOT TARGET ${_t})
    continue()
  endif()
  get_target_property(_t_type ${_t} TYPE)
  get_target_property(_t_excl ${_t} EXCLUDE_FROM_ALL)
  if(NOT _t_type STREQUAL "INTERFACE_LIBRARY" AND NOT _t_excl)
    list(APPEND _onemill_install_deps ${_t})
  endif()
endforeach()

if(_onemill_install_deps)
  # All three install targets had the same shallow DEPENDS and therefore the
  # same failure mode: run one on its own and it stages whatever is in bin/.
  # install_fitting installs only three modules but still depends on all of
  # them - it shares one build tree, so a partial build is a stale build.
  add_dependencies(install_full    ${_onemill_install_deps})
  add_dependencies(install_plugins ${_onemill_install_deps})
  add_dependencies(install_fitting ${_onemill_install_deps})
  list(LENGTH _onemill_install_deps _onemill_dep_count)
  message(STATUS "install targets depend on ${_onemill_dep_count} build targets")
endif()