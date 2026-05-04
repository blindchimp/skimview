#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFileInfoList>
#include <QStringList>
#include <QUrl>
#include <QDebug>
#include "trashhandler.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    const char *path = ".";
    if (argc < 2) {
        qWarning() << "Usage: ImageViewer <folder_path>";
    }
    else
    {
      path = argv[1];
    }

    QString folderPath = QString::fromLocal8Bit(path);
    QDir dir(folderPath);

    if (!dir.exists()) {
        qWarning() << "Folder does not exist:" << folderPath;
        return 1;
    }

    // QStringList imageExtensions = {"*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp", "*.webp", "*.tiff", "*.heic", "*.heif"};
    // QFileInfoList imageFiles = dir.entryInfoList(imageExtensions, QDir::Files);

    // QStringList imageUrls;
    // for (const QFileInfo &fileInfo : imageFiles) {
    //     imageUrls.append(QUrl::fromLocalFile(fileInfo.absoluteFilePath()).toString());
    // }

    QQmlApplicationEngine engine;
    QQmlContext *context = engine.rootContext();

    // Register TrashHandler for use in QML
    TrashHandler trashHandler;
    context->setContextProperty("trashHandler", &trashHandler);

    // Pass the initial folder path to QML as a file:// URL
    context->setContextProperty("initialFolder", QVariant::fromValue(QUrl::fromLocalFile(dir.absolutePath()).toString()));

    const QUrl url(QStringLiteral("qrc:/ImageViewer/ImageViewer.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}
