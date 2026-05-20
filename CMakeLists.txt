cmake_minimum_required(VERSION 3.16)
project(ImageViewer VERSION 1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

#set(CMAKE_PREFIX_PATH "$ENV{HOME}/Qt/6.11.0/macos")

find_package(Qt6 REQUIRED COMPONENTS Core Quick QuickControls2 Sql)

qt_add_executable(ImageViewer
    main.cpp
    trashhandler.h
    trashhandler.cpp
    cliphandler.h
    cliphandler.cpp
    tagsearchhandler.h
    tagsearchhandler.cpp
    tagginghandler.h
    tagginghandler.cpp
    icon.icns
)

if(APPLE)
    set(MACOSX_BUNDLE_ICON_FILE "icon.icns")
set(app_icon "${CMAKE_CURRENT_SOURCE_DIR}/icon.icns")
set_source_files_properties(${app_icon} PROPERTIES
    MACOSX_PACKAGE_LOCATION "Resources"
)
endif()

set_target_properties(ImageViewer PROPERTIES
    MACOSX_BUNDLE TRUE
    MACOSX_BUNDLE_GUI_IDENTIFIER "com.example.ImageViewer"
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
   # MACOSX_BUNDLE_ICON_FILE icon.icns
)

qt_add_qml_module(ImageViewer
    URI ImageViewer
    VERSION 1.0
    QML_FILES
        ImageViewer.qml
)

# Copy tools to build directory so they're available at runtime
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/tools DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

target_compile_definitions(ImageViewer PRIVATE
    TOOLS_DIR="${CMAKE_CURRENT_BINARY_DIR}/tools"
)

if(APPLE)
    # Embed tag_images.py in the macOS app bundle's Resources/tools/
    set(tag_script "${CMAKE_CURRENT_SOURCE_DIR}/tools/tag_images.py")
    set_source_files_properties(${tag_script} PROPERTIES
        MACOSX_PACKAGE_LOCATION "Resources/tools"
    )
    target_sources(ImageViewer PRIVATE ${tag_script})
endif()

target_link_libraries(ImageViewer PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
)