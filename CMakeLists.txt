cmake_minimum_required(VERSION 3.16...3.24)
project(spvrc LANGUAGES CXX)

# check if top level project
set (SPVRC_TOP_LEVEL_PROJECT OFF)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(SPVRC_TOP_LEVEL_PROJECT ON)
    set(SPVRC_SHADER_ENV "vulkan1.3")
    set(SPVRC_SHADER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/shaders")
endif()

# check if options are undefined
if(NOT DEFINED SPVRC_SHADER_DIR)
    message(FATAL_ERROR "SPVRC_SHADER_DIR must be defined, set it to the directory containing the shaders")
endif()
if(NOT DEFINED SPVRC_SHADER_ENV)
    message(FATAL_ERROR "SPVRC_SHADER_ENV is not set, a good default would be vulkan1.3")
endif()

set(SPVRC_GLSLANG_VALIDATOR "")
find_package(Vulkan COMPONENTS glslangValidator)
if(Vulkan_glslangValidator_FOUND)
    # use the found glslangValidator from find_package()
    set(SPVRC_GLSLANG_VALIDATOR ${Vulkan_GLSLANG_VALIDATOR_EXECUTABLE})
    set(SPVRC_GLSLANG_VALIDATOR_OPTIMIZER ON)
else()
    # try to find glslang validator on cmd line
    find_program(GLSLANG_VALIDATOR_FOUND glslangValidator)
    if (NOT ${GLSLANG_VALIDATOR_FOUND} STREQUAL "GLSLANG_VALIDATOR_FOUND-NOTFOUND")
        set(SPVRC_GLSLANG_VALIDATOR ${GLSLANG_VALIDATOR_FOUND})
        # the optimizer likely won't be available
        set(SPVRC_GLSLANG_VALIDATOR_OPTIMIZER OFF)
    endif()
endif()

# build glslangValidator if not found
if(SPVRC_GLSLANG_VALIDATOR STREQUAL "")
    include(FetchContent)
    # SPIRV-Tools for glslang compiler
    set(SKIP_SPIRV_TOOLS_INSTALL ON)
    set(SPIRV_BUILD_FUZZER OFF)
    set(SPIRV_COLOR_TERMINAL OFF)
    set(SPIRV_SKIP_TESTS ON)
    set(SPIRV_SKIP_EXECUTABLES ON)
    set(SPIRV_USE_SANITIZER "")
    set(SPIRV_WARN_EVERYTHING OFF)
    set(SPIRV_WERROR OFF)
    set(SPIRV_CHECK_CONTEXT OFF)
    set(SPIRV_TOOLS_BUILD_STATIC ON)
    FetchContent_Declare(spirv-headers
        GIT_REPOSITORY "https://github.com/KhronosGroup/SPIRV-Headers.git"
        GIT_TAG "vulkan-sdk-1.3.290.0"
        GIT_SHALLOW ON
        OVERRIDE_FIND_PACKAGE
        EXCLUDE_FROM_ALL
        SYSTEM)
    FetchContent_Declare(spirv-tools
        GIT_REPOSITORY "https://github.com/KhronosGroup/SPIRV-Tools.git"
        GIT_TAG "vulkan-sdk-1.3.290.0"
        GIT_SHALLOW ON
        OVERRIDE_FIND_PACKAGE
        EXCLUDE_FROM_ALL
        SYSTEM)
    # glslangValidator for runtime/static shader compilation
    set(ENABLE_OPT ON)
    set(ENABLE_HLSL OFF)
    set(ENABLE_GLSLANG_JS OFF)
    set(ENABLE_GLSLANG_BINARIES ON)
    set(ENABLE_SPVREMAPPER OFF)
    set(GLSLANG_ENABLE_INSTALL OFF)
    set(GLSLANG_TESTS OFF)
    set(BUILD_EXTERNAL OFF)
    FetchContent_Declare(glslang
        GIT_REPOSITORY "https://github.com/KhronosGroup/glslang.git"
        GIT_TAG "vulkan-sdk-1.3.290.0"
        GIT_SHALLOW ON
        OVERRIDE_FIND_PACKAGE
        EXCLUDE_FROM_ALL
        SYSTEM)
    FetchContent_MakeAvailable(spirv-headers spirv-tools glslang)
    set(SPVRC_GLSLANG_VALIDATOR glslang-standalone)
    set(SPVRC_GLSLANG_VALIDATOR_OPTIMIZER ON)
endif()

# compile glsl to spirv
file(GLOB_RECURSE GLSL_SOURCE_FILES CONFIGURE_DEPENDS
    "${SPVRC_SHADER_DIR}/*.vert"
    "${SPVRC_SHADER_DIR}/*.frag"
    "${SPVRC_SHADER_DIR}/*.comp")
set(GLSLANG_CLI_PARAMS 
    # --keep-uncalled
    # --spirv-val
    --enhanced-msgs --quiet
    --target-env "${SPVRC_SHADER_ENV}"
    -I"${SPVRC_SHADER_DIR}")
if(SPVRC_GLSLANG_VALIDATOR_OPTIMIZER)
    list(APPEND GLSLANG_CLI_PARAMS -Os)
endif()
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/shaders")
foreach(GLSL_FILE ${GLSL_SOURCE_FILES})
    # get shortened path relative to shader directory root
    cmake_path(RELATIVE_PATH GLSL_FILE BASE_DIRECTORY "${CMAKE_SOURCE_DIR}/shaders" OUTPUT_VARIABLE FILE_NAME)
    set(SPIRV_HEADER "${CMAKE_CURRENT_BINARY_DIR}/shaders/${FILE_NAME}.hpp")
    string(REPLACE "/" "_" SPV_VAR_NAME "${FILE_NAME}")
    string(REPLACE "." "_" SPV_VAR_NAME "${SPV_VAR_NAME}")
    # create potentially missing directory for generated header
    cmake_path(GET SPIRV_HEADER PARENT_PATH SPIRV_HEADER_DIR)
    file(MAKE_DIRECTORY ${SPIRV_HEADER_DIR})
    # compile shader into header file
    add_custom_command(
        COMMENT "Compiling shader: ${FILE_NAME}"
        OUTPUT  "${SPIRV_HEADER}"
        COMMAND ${SPVRC_GLSLANG_VALIDATOR} ${GLSLANG_CLI_PARAMS} --depfile "${SPIRV_HEADER}.d" --vn "${SPV_VAR_NAME}" "${GLSL_FILE}" -o "${SPIRV_HEADER}"
        DEPFILE "${SPIRV_HEADER}.d"
        DEPENDS ${SPVRC_GLSLANG_VALIDATOR} "${GLSL_FILE}")
    list(APPEND SPVRC_SPIRV_HEADERS "${SPIRV_HEADER}")
    list(APPEND SPVRC_SPIRV_FILES "${FILE_NAME}")
    list(APPEND SPVRC_SPIRV_SYMBOLS "${SPV_VAR_NAME}")
endforeach(GLSL_FILE)

# create a command to generate the source file that depends on the shader headers
set(SPVRC_SRC "${CMAKE_CURRENT_BINARY_DIR}/spvrc.cpp")
add_custom_command(
    COMMAND_EXPAND_LISTS
    COMMAND ${CMAKE_COMMAND}
        -DSPVRC_SRC=${SPVRC_SRC}
        -DSPVRC_SPIRV_HEADERS="${SPVRC_SPIRV_HEADERS}"
        -DSPVRC_SPIRV_FILES="${SPVRC_SPIRV_FILES}"
        -DSPVRC_SPIRV_SYMBOLS="${SPVRC_SPIRV_SYMBOLS}"
        -P "${CMAKE_CURRENT_SOURCE_DIR}/cmake/generate_spvrc_source.cmake"
    DEPENDS ${SPVRC_SPIRV_HEADERS}
    OUTPUT ${SPVRC_SRC}
)
# library will depend on source file output
add_library(${PROJECT_NAME} "${SPVRC_SRC}")
add_library(${PROJECT_NAME}::spvrc ALIAS ${PROJECT_NAME})
target_include_directories(${PROJECT_NAME} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")

# testing
if(SPVRC_TOP_LEVEL_PROJECT)
    add_executable(test_spvrc "${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp")
    target_link_libraries(test_spvrc PRIVATE spvrc::spvrc)
endif()