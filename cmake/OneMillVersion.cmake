# OneMillVersion.cmake - the one product version every first-party binary carries.
#
# CI passes the version in: ONEMILL_VERSION is the build number CreateCadsVersion computed
# (GitVersion, default configuration), e.g. 2.2.0.60-alpha. Without it the version is derived
# from git with the rules the other CADS products use, so a local build reads the same:
#
#   main              the tag's version, no suffix
#   release/vX.Y.Z    X.Y.Z, suffix "beta" (hotfix/vX.Y.Z likewise)
#   develop           next minor, suffix "alpha"
#   detached HEAD     next minor, suffix "local"
#   any other branch  next minor, the branch name without "feature/" as suffix
#
# "Next minor" is the nearest vX.Y.Z tag with the minor raised and the patch reset: v2.1.0
# gives 2.2.0. The fourth number counts the commits since that tag. It is computed at configure
# time only, so a tree that is not reconfigured after new commits keeps its old count - CI
# configures fresh on every run, and only CI builds are delivered.
#
# A version that cannot be determined fails the configure. A build that claims 0.0.0 cannot be
# traced to anything, and OneMill is validated by the version it shows.
#
# Results, for the rest of the build:
#   ONEMILL_VERSION_FULL      2.2.0.60-alpha   what people see: title bar, artifact name
#   ONEMILL_VERSION_NUMERIC   2.2.0.60         four fields, each at most 65535
#   ONEMILL_VERSION_MAJOR, ONEMILL_VERSION_MINOR, ONEMILL_VERSION_PATCH, ONEMILL_VERSION_BUILD
#   ONEMILL_VERSION_HASH      short commit hash; empty when git is unavailable
#
# onemill_add_version_info(<target>...) stamps that version into binaries as a VERSIONINFO
# resource (cmake/VersionInfo.rc.in) - what Explorer's Details tab shows, and what AppLocker
# publisher rules read.

set(ONEMILL_VERSION "" CACHE STRING
  "Product version X.Y.Z[.N][-label], e.g. 2.2.0.60-alpha. Empty = derive from git. CI passes its build number.")

find_package(Git QUIET)

# Runs git in the source tree. Leaves the exit code in <rc_out>, so a caller can tell
# "no such tag" from success.
function(_onemill_git _out _rc_out)
  execute_process(
    COMMAND "${GIT_EXECUTABLE}" ${ARGN}
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    OUTPUT_VARIABLE _stdout
    ERROR_VARIABLE  _stderr
    RESULT_VARIABLE _rc
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_STRIP_TRAILING_WHITESPACE)
  set(${_out} "${_stdout}" PARENT_SCOPE)
  set(${_rc_out} "${_rc}" PARENT_SCOPE)
endfunction()

# Derives X.Y.Z.N[-label] from the nearest vX.Y.Z tag and the current branch.
function(_onemill_version_from_git _out_version _out_origin)
  set(_remedy
    "Fetch the tags (git fetch --tags), or pass the version explicitly: -DONEMILL_VERSION=2.2.0.0-local")
  if(NOT GIT_FOUND)
    message(FATAL_ERROR "Cannot determine the OneMill version: git was not found.\n${_remedy}")
  endif()

  _onemill_git(_tag _rc describe --tags --match "v[0-9]*.[0-9]*.[0-9]*" --abbrev=0 HEAD)
  if(NOT _rc EQUAL 0 OR NOT _tag MATCHES "^v([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
    message(FATAL_ERROR
      "Cannot determine the OneMill version: no tag of the form vX.Y.Z is reachable from HEAD"
      " (nearest: '${_tag}').\n${_remedy}")
  endif()
  set(_major "${CMAKE_MATCH_1}")
  set(_minor "${CMAKE_MATCH_2}")
  set(_patch "${CMAKE_MATCH_3}")

  _onemill_git(_count _rc rev-list --count "${_tag}..HEAD")
  if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "Cannot determine the OneMill version: counting commits since ${_tag} failed.")
  endif()

  _onemill_git(_branch _rc rev-parse --abbrev-ref HEAD)
  if(NOT _rc EQUAL 0)
    message(FATAL_ERROR "Cannot determine the OneMill version: the current branch is unknown.")
  endif()

  if(_branch STREQUAL "main")
    set(_label "")
  elseif(_branch MATCHES "^(release|hotfix)/v([0-9]+)\\.([0-9]+)\\.([0-9]+)$")
    set(_major "${CMAKE_MATCH_2}")
    set(_minor "${CMAKE_MATCH_3}")
    set(_patch "${CMAKE_MATCH_4}")
    set(_label "beta")
  elseif(_branch MATCHES "^(release|hotfix)/")
    # A release branch that names no version would otherwise be treated as a feature branch
    # and silently get a feature label.
    message(FATAL_ERROR
      "Cannot determine the OneMill version: branch '${_branch}' must be named release/vX.Y.Z or hotfix/vX.Y.Z.")
  else()
    math(EXPR _minor "${_minor} + 1")
    set(_patch 0)
    if(_branch STREQUAL "develop")
      set(_label "alpha")
    elseif(_branch STREQUAL "HEAD")
      set(_label "local")
    else()
      string(REGEX REPLACE "^features?[/-]" "" _label "${_branch}")
      string(REGEX REPLACE "[^0-9A-Za-z-]" "-" _label "${_label}")
    endif()
  endif()

  set(_version "${_major}.${_minor}.${_patch}.${_count}")
  if(NOT _label STREQUAL "")
    string(APPEND _version "-${_label}")
  endif()
  set(${_out_version} "${_version}" PARENT_SCOPE)
  if(_branch STREQUAL "HEAD")
    set(_where "a detached HEAD")
  else()
    set(_where "${_branch}")
  endif()
  set(${_out_origin} "git: ${_tag} + ${_count} commits on ${_where}" PARENT_SCOPE)
endfunction()

# Splits X.Y.Z[.N][-label] into the result variables. A Windows version resource holds at
# most 65535 per field, so a larger number is clamped - with a warning, because the numeric
# version then no longer matches the informational one.
function(_onemill_publish_version _version _origin)
  if(NOT _version MATCHES "^([0-9]+)\\.([0-9]+)\\.([0-9]+)(\\.([0-9]+))?(-[0-9A-Za-z.-]+)?$")
    message(FATAL_ERROR
      "OneMill version '${_version}' (${_origin}) is not of the form X.Y.Z[.N][-label].")
  endif()
  set(_major "${CMAKE_MATCH_1}")
  set(_minor "${CMAKE_MATCH_2}")
  set(_patch "${CMAKE_MATCH_3}")
  set(_build "${CMAKE_MATCH_5}")
  if(_build STREQUAL "")
    set(_build 0)
  endif()
  foreach(_field _major _minor _patch _build)
    if(${_field} GREATER 65535)
      message(WARNING
        "OneMill version '${_version}': ${${_field}} exceeds 65535, the version resource carries 65535.")
      set(${_field} 65535)
    endif()
  endforeach()

  set(ONEMILL_VERSION_FULL    "${_version}"                               PARENT_SCOPE)
  set(ONEMILL_VERSION_NUMERIC "${_major}.${_minor}.${_patch}.${_build}"   PARENT_SCOPE)
  set(ONEMILL_VERSION_MAJOR   "${_major}"                                 PARENT_SCOPE)
  set(ONEMILL_VERSION_MINOR   "${_minor}"                                 PARENT_SCOPE)
  set(ONEMILL_VERSION_PATCH   "${_patch}"                                 PARENT_SCOPE)
  set(ONEMILL_VERSION_BUILD   "${_build}"                                 PARENT_SCOPE)
endfunction()

if(NOT ONEMILL_VERSION STREQUAL "")
  _onemill_publish_version("${ONEMILL_VERSION}" "from ONEMILL_VERSION")
  set(_onemill_version_origin "from ONEMILL_VERSION")
else()
  _onemill_version_from_git(_onemill_version _onemill_version_origin)
  _onemill_publish_version("${_onemill_version}" "${_onemill_version_origin}")
endif()

set(ONEMILL_VERSION_HASH "")
if(GIT_FOUND)
  _onemill_git(_onemill_hash _onemill_rc rev-parse --short HEAD)
  if(_onemill_rc EQUAL 0)
    set(ONEMILL_VERSION_HASH "${_onemill_hash}")
  endif()
endif()

message(STATUS "OneMill version: ${ONEMILL_VERSION_FULL}  "
               "(numeric ${ONEMILL_VERSION_NUMERIC}, commit ${ONEMILL_VERSION_HASH}; ${_onemill_version_origin})")

unset(_onemill_version)
unset(_onemill_version_origin)
unset(_onemill_hash)
unset(_onemill_rc)

# Gives every listed executable and shared or module library a VERSIONINFO resource carrying the
# product version. Anything else - static libraries, custom targets - is skipped, so a caller can
# pass a whole target walk. The .rc is rewritten only when its content changes, so an unchanged
# version relinks nothing.
function(onemill_add_version_info)
  if(NOT WIN32)
    return()
  endif()

  # A suffix (alpha, beta, a branch name, local) marks a build that is not a release.
  if(ONEMILL_VERSION_FULL MATCHES "-")
    set(_rc_flags "VS_FF_PRERELEASE")
  else()
    set(_rc_flags "0x0L")
  endif()
  set(_rc_comments "${ONEMILL_VERSION_FULL}")
  if(NOT ONEMILL_VERSION_HASH STREQUAL "")
    string(APPEND _rc_comments " (${ONEMILL_VERSION_HASH})")
  endif()

  foreach(_target IN LISTS ARGN)
    get_target_property(_type ${_target} TYPE)
    if(_type STREQUAL "EXECUTABLE")
      set(_rc_type "VFT_APP")
      set(_suffix ".exe")
    elseif(_type STREQUAL "SHARED_LIBRARY" OR _type STREQUAL "MODULE_LIBRARY")
      set(_rc_type "VFT_DLL")
      set(_suffix ".dll")
    else()
      continue()
    endif()

    get_target_property(_rc_name ${_target} OUTPUT_NAME)
    if(NOT _rc_name)
      set(_rc_name "${_target}")
    endif()
    set(_rc_filename "${_rc_name}${_suffix}")

    if(_target STREQUAL "MainApp")
      set(_rc_description "KLSOneMill")
    elseif(_target MATCHES "^Module(.+)$")
      # Plugin targets are all named Module<Name>; "Module ModuleView" would say it twice.
      set(_rc_description "KLSOneMill Module ${CMAKE_MATCH_1}")
    else()
      set(_rc_description "KLSOneMill ${_target}")
    endif()

    set(_rc "${CMAKE_BINARY_DIR}/versioninfo/${_target}.rc")
    configure_file("${CMAKE_SOURCE_DIR}/cmake/VersionInfo.rc.in" "${_rc}" @ONLY)
    target_sources(${_target} PRIVATE "${_rc}")
  endforeach()
endfunction()
