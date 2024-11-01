# SPVRC

The SPIR-V Resource Compiler

## Description
Simple CMake project that translates GLSL shaders into SPIR-V shader bytecode using glslangValidator and embeds them into a library to link against.
Shaders can be loaded at runtime using a relative path string.

## Getting Started
### CMakeLists.txt
```
set(SPVRC_SHADER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/shaders")
set(SPVRC_SHADER_ENV "vulkan1.3")
FetchContent_Declare(spvrc
    GIT_REPOSITORY "https://github.com/M2-TE/spvrc.git"
    GIT_TAG "main"
    GIT_SHALLOW ON)
FetchContent_MakeAvailable(spvrc)
target_link_libraries(${PROJECT_NAME} PUBLIC spvrc::spvrc)
```
### C++
```
#include <spvrc/spvrc.hpp>
void fnc() {
    std::vector<uint32_t> shader_data = spvrc::load("shadername.vert");
}
```
