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

target_link_libraries(ImageViewer PRIVATE
    Qt6::Core
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Sql
)