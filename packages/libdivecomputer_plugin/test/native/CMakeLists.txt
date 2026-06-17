cmake_minimum_required(VERSION 3.18)
project(libdc_wrapper_tests LANGUAGES C)

set(WRAPPER_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../macos/Classes")
set(LIBDC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/libdivecomputer")
set(CONFIG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../macos/config")

# Test the wrapper struct definitions and sentinel conventions.
add_executable(test_dive_converter
    test_dive_converter.c
)
target_include_directories(test_dive_converter PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)

add_executable(test_serial_callbacks
    test_serial_callbacks.c
)
target_include_directories(test_serial_callbacks PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)

add_executable(test_descriptor_matcher
    test_descriptor_matcher.c
)
target_include_directories(test_descriptor_matcher PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${CONFIG_DIR}
)

# test_parse_raw_dive requires the full libdivecomputer + wrapper linked in.
# Use the Windows config on Windows, macOS config otherwise.
if(WIN32)
    set(PLATFORM_CONFIG_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../windows/config")
else()
    set(PLATFORM_CONFIG_DIR "${CONFIG_DIR}")
endif()

# Collect libdivecomputer sources needed for parsing (exclude platform I/O
# files that don't compile cross-platform).
file(GLOB LIBDC_ALL_SOURCES "${LIBDC_DIR}/src/*.c")
list(FILTER LIBDC_ALL_SOURCES EXCLUDE REGEX "serial_posix\\.c$")
if(NOT WIN32)
    list(FILTER LIBDC_ALL_SOURCES EXCLUDE REGEX "serial_win32\\.c$")
endif()

add_executable(test_parse_raw_dive
    test_parse_raw_dive.c
    ${WRAPPER_DIR}/libdc_wrapper.c
    ${WRAPPER_DIR}/libdc_download.c
    ${LIBDC_ALL_SOURCES}
)
target_include_directories(test_parse_raw_dive PRIVATE
    ${WRAPPER_DIR}
    ${LIBDC_DIR}/include
    ${LIBDC_DIR}/src
    ${PLATFORM_CONFIG_DIR}
)
target_compile_definitions(test_parse_raw_dive PRIVATE HAVE_CONFIG_H)
if(WIN32)
    target_compile_definitions(test_parse_raw_dive PRIVATE _CRT_SECURE_NO_WARNINGS)
    target_link_libraries(test_parse_raw_dive PRIVATE SetupAPI.lib ws2_32.lib)
endif()

enable_testing()
add_test(NAME test_dive_converter COMMAND test_dive_converter)
add_test(NAME test_serial_callbacks COMMAND test_serial_callbacks)
add_test(NAME test_descriptor_matcher COMMAND test_descriptor_matcher)
add_test(NAME test_parse_raw_dive COMMAND test_parse_raw_dive
    WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
)
