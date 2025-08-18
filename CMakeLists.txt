cmake_minimum_required(VERSION 3.16)
project(KLSOneMill)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)


set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /MT")
set(CMAKE_CXX_FLAGS_RELWITHDEBINFO "${CMAKE_CXX_FLAGS_RELWITHDEBINFO} /MT")
set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} /MTd")

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

find_package(VTK REQUIRED)
find_package(spdlog CONFIG REQUIRED)
find_package(Clipper2 CONFIG REQUIRED)
find_package(nlohmann_json CONFIG REQUIRED)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets OpenGL OpenGLWidgets)



# Define your global output structure
set(OUTPUT_BASE_DIR ${CMAKE_BINARY_DIR}/bin/${CMAKE_BUILD_TYPE})

# Pass these to subprojects
set(GLOBAL_RUNTIME_DIR ${OUTPUT_BASE_DIR})
set(GLOBAL_PLUGIN_DIR ${OUTPUT_BASE_DIR}/plugins)
set(GLOBAL_ARCHIVE_DIR ${CMAKE_BINARY_DIR}/lib)

add_subdirectory(ModuleInterface)
add_subdirectory(BackendUtils)
add_subdirectory(ModuleUtils)
add_subdirectory(MainApp)

set(MODULE_OUTPUT_FOLDER "${CMAKE_BINARY_DIR}/bin/$<CONFIG>/modulesBert")


add_subdirectory(Modules)


# ModuleWorks setup




