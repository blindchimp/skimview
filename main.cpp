#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFileInfoList>
#include <QStringList>
#include <QUrl>
#include <QDebug>
#include "trashhandler.h"
#include "cliphandler.h"
#include "tagsearchhandler.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    bool initial_folder = false;
    const char *path = 0;

    if(argc >= 2)
    {
      path = argv[1];
      initial_folder = true;
    }
    QString folderPath = QString::fromLocal8Bit(path);
    QDir dir(folderPath);

    if(initial_folder)
    {

        if (!dir.exists()) {
            qWarning() << "Folder does not exist:" << folderPath;
            initial_folder = false;
        }
    }

    QQmlApplicationEngine engine;
    QQmlContext *context = engine.rootContext();

    // Register TrashHandler for use in QML
    TrashHandler trashHandler;
    context->setContextProperty("trashHandler", &trashHandler);

    // Register ClipboardHandler for use in QML
    ClipboardHandler clipboardHandler;
    context->setContextProperty("clipboardHandler", &clipboardHandler);

    // Register TagSearchHandler for use in QML
    TagSearchHandler tagSearchHandler;
    context->setContextProperty("tagSearchHandler", &tagSearchHandler);

    // Pass the initial folder path to QML as a file:// URL
    if(initial_folder)
    {
        context->setContextProperty("initialFolder", QVariant::fromValue(QUrl::fromLocalFile(dir.absolutePath()).toString()));
    }
    else
    {
        context->setContextProperty("initialFolder", QVariant(""));

    }

    const QUrl url(QStringLiteral("qrc:/ImageViewer/ImageViewer.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
