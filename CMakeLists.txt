cmake_minimum_required(VERSION 3.22) # check which the min version actually is
project(spvrc LANGUAGES CXX)

# check if top level project
set (SPVRC_TOP_LEVEL_PROJECT OFF)
if (CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    set(SPVRC_TOP_LEVEL_PROJECT ON)
endif()

# check if options are undefined
if (NOT DEFINED SPVRC_SHADER_DIR)
    if (NOT SPVRC_TOP_LEVEL_PROJECT)
        message(FATAL_ERROR "SPVRC_SHADER_DIR must be defined")
    else()
        set(SPVRC_SHADER_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    endif()
endif()
if (NOT DEFINED SPVRC_SHADER_ENV)
    set(SPVRC_SHADER_ENV "vulkan1.3")
endif()

# glslangValidator for runtime/static shader compilation (glsl to spirv)
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/shaders")
file(GLOB_RECURSE GLSL_SOURCE_FILES CONFIGURE_DEPENDS
    "${SPVRC_SHADER_DIR}/*.vert"
    "${SPVRC_SHADER_DIR}/*.frag"
    "${SPVRC_SHADER_DIR}/*.comp")
find_package(Vulkan COMPONENTS glslangValidator)
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/shaders")
set(GLSLANG_CLI_PARAMS 
    # --keep-uncalled
    --enhanced-msgs
    # --spirv-val
    --quiet
    -Os
    -I"${SPVRC_SHADER_DIR}"
    --target-env "${SPVRC_SHADER_ENV}")
if (${Vulkan_glslangValidator_FOUND})
    # compile glsl to spirv
    foreach(GLSL_FILE ${GLSL_SOURCE_FILES})
        file(RELATIVE_PATH FILE_NAME "${CMAKE_CURRENT_SOURCE_DIR}/shaders" "${GLSL_FILE}")
        set(SPIRV_FILE "${CMAKE_CURRENT_BINARY_DIR}/shaders/${FILE_NAME}.hpp")
        string(REPLACE "/" "_" SPV_VAR_NAME "${FILE_NAME}")
        string(REPLACE "." "_" SPV_VAR_NAME "${SPV_VAR_NAME}")
        add_custom_command(
            COMMENT "Compiling shader: ${FILE_NAME}"
            OUTPUT  "${SPIRV_FILE}"
            COMMAND ${Vulkan_GLSLANG_VALIDATOR_EXECUTABLE} ${GLSLANG_CLI_PARAMS} --depfile "${SPIRV_FILE}.d" --vn "${SPV_VAR_NAME}" "${GLSL_FILE}" -o "${SPIRV_FILE}"
            DEPFILE "${SPIRV_FILE}.d"
            DEPENDS "${GLSL_FILE}")
        list(APPEND SPIRV_HEADER_PATHS_REL "${FILE_NAME}")
        list(APPEND SPIRV_HEADER_PATHS_FULL "${SPIRV_FILE}")
        list(APPEND SPIRV_VARIABLE_NAMES "${SPV_VAR_NAME}")
    endforeach(GLSL_FILE)
else()
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
        SYSTEM)
    FetchContent_Declare(spirv-tools
        GIT_REPOSITORY "https://github.com/KhronosGroup/SPIRV-Tools.git"
        GIT_TAG "vulkan-sdk-1.3.290.0"
        GIT_SHALLOW ON
        OVERRIDE_FIND_PACKAGE
        SYSTEM)
    FetchContent_MakeAvailable(spirv-headers spirv-tools)
    # glslang for runtime/static shader compilation
    set(ENABLE_OPT ON)
    set(ENABLE_HLSL OFF)
    set(ENABLE_GLSLANG_JS OFF)
    set(ENABLE_GLSLANG_BINARIES ON) # enable/disable standalone GLSL compiler
    set(ENABLE_SPVREMAPPER OFF)
    set(GLSLANG_ENABLE_INSTALL OFF)
    set(GLSLANG_TESTS OFF)
    set(BUILD_EXTERNAL OFF)
    FetchContent_Declare(glslang
        GIT_REPOSITORY "https://github.com/KhronosGroup/glslang.git"
        GIT_TAG "vulkan-sdk-1.3.290.0"
        GIT_SHALLOW ON
        OVERRIDE_FIND_PACKAGE
        SYSTEM)
    FetchContent_MakeAvailable(glslang)

    # # compile glsl to spirv
    # foreach(GLSL_FILE ${GLSL_SOURCE_FILES})
    #     file(RELATIVE_PATH FILE_NAME "${CMAKE_CURRENT_SOURCE_DIR}/shaders" "${GLSL_FILE}")
    #     set(SPIRV_FILE "${CMAKE_CURRENT_BINARY_DIR}/shaders/${FILE_NAME}")
    #     add_custom_command(
    #         COMMENT "Compiling shader: ${FILE_NAME}"
    #         OUTPUT  "${SPIRV_FILE}"
    #         COMMAND glslang-standalone ${GLSLANG_CLI_PARAMS} --depfile "${SPIRV_FILE}.d" "${GLSL_FILE}" -o "${SPIRV_FILE}"
    #         DEPFILE "${SPIRV_FILE}.d"
    #         DEPENDS "${GLSL_FILE}" glslang-standalone)
    #     list(APPEND SPIRV_BINARY_FILES "${SPIRV_FILE}")
    # endforeach(GLSL_FILE)
endif()

# create source file dynamically
set(SPVRC_SRC "${CMAKE_CURRENT_SOURCE_DIR}/src/spvrc.cpp")
file(WRITE "${SPVRC_SRC}"
"#include <string_view>
#include <cstdint>
#include <vector>
#include \"spvrc.hpp\"
")
# include shader headers
foreach(HEADER_PATH ${SPIRV_HEADER_PATHS_FULL})
    file(APPEND "${SPVRC_SRC}" "#include \"${HEADER_PATH}\"\n")
endforeach(HEADER_PATH)
# add namespace and shader load function
file(APPEND "${SPVRC_SRC}" "
// https://stackoverflow.com/a/46711735
constexpr uint32_t hash(std::string_view data) noexcept {
    uint32_t hash = 5381;
    for (const char &c : data) {
        hash = ((hash << 5) + hash) + static_cast<unsigned char>(c);
    }
    return hash;
}

namespace spvrc {
    auto load(std::string_view path) -> std::vector<uint32_t> {
        std::vector<uint32_t> data;
        switch (hash(path)) {
")
# insert shader data
foreach(PATH_REL VAR_NAME IN ZIP_LISTS SPIRV_HEADER_PATHS_REL SPIRV_VARIABLE_NAMES)
    file(APPEND "${SPVRC_SRC}"
"            case hash(\"${PATH_REL}\"): data = { ${VAR_NAME}, ${VAR_NAME} + std::size(${VAR_NAME})}; break;\n"
    )
endforeach(PATH_REL VAR_NAME)
# end namespace
file(APPEND "${SPVRC_SRC}" "
            default: break;
        }
        return data;
    }
}")

add_library(${PROJECT_NAME} "${CMAKE_CURRENT_SOURCE_DIR}/src/spvrc.cpp" ${SPIRV_HEADER_PATHS_FULL})
add_library(${PROJECT_NAME}::spvrc ALIAS ${PROJECT_NAME})
target_include_directories(${PROJECT_NAME} PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")

# TESTING
# add_executable(test_spvrc "${CMAKE_CURRENT_SOURCE_DIR}/src/main.cpp")
# target_link_libraries(test_spvrc PRIVATE spvrc::spvrc)