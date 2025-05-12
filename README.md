# A simple SPIR-V Resource Compiler

Single CMake project that translates GLSL shaders into SPIR-V shader bytecode using glslangValidator and embeds them into a library to link against.
Shaders can be loaded at runtime using a relative path string.

## Getting Started
### CMakeLists.txt
```cmake
set(SPVRC_SHADER_ENV "vulkan1.3")
set(SPVRC_SHADER_BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/your/base/shader/dir")
set(SPVRC_SHADER_INCLUDE_DIRS
    "${CMAKE_CURRENT_SOURCE_DIR}/some/shader/dir/"
    "${CMAKE_CURRENT_SOURCE_DIR}/another/shader/dir/")
FetchContent_Declare(spvrc
    GIT_REPOSITORY "https://github.com/M2-TE/spvrc.git"
    GIT_TAG "v1.0.5"
    GIT_SHALLOW ON)
FetchContent_MakeAvailable(spvrc)
target_link_libraries(${PROJECT_NAME} PUBLIC spvrc::spvrc)
```
### C++
```cpp
#include <spvrc/spvrc.hpp>
void fnc() {
    std::vector<uint32_t> shader_data = spvrc::load("shadername.vert");
}
```
