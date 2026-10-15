# Run via `cmake -P` from onemill_shared_package()'s staging step (cmake/SharedDeps.cmake).
#   -DMODULES_ROOT=<bin/<CONFIG>/modulesBert>
#   -DFILE_NAMES=<name1,name2,...>   file names belonging to the shared package just staged
#
# Removes those file names from every module's private deps/ folder - stale copies from the
# old one-full-copy-per-module layout. Left in place, the same DLL would exist in two
# AddDllDirectory folders, and which one Windows loads is undefined.

if(NOT DEFINED MODULES_ROOT OR NOT EXISTS "${MODULES_ROOT}")
    return()
endif()

string(REPLACE "," ";" _names "${FILE_NAMES}")
file(GLOB _module_deps_dirs LIST_DIRECTORIES true "${MODULES_ROOT}/*/deps")

foreach(_dir IN LISTS _module_deps_dirs)
    if(NOT IS_DIRECTORY "${_dir}")
        continue()
    endif()
    set(_removed 0)
    foreach(_n IN LISTS _names)
        if(EXISTS "${_dir}/${_n}")
            file(REMOVE "${_dir}/${_n}")
            math(EXPR _removed "${_removed} + 1")
        endif()
    endforeach()
    if(_removed GREATER 0)
        message(STATUS "Pruned ${_removed} stale shared-package file(s) from ${_dir}")
    endif()
    # An emptied deps/ is removed too - MainApp only adds deps/ folders that exist.
    file(GLOB _left "${_dir}/*")
    if(NOT _left)
        file(REMOVE_RECURSE "${_dir}")
    endif()
endforeach()
