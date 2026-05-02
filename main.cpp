#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDir>
#include <QFileInfoList>
#include <QStringList>
#include <QUrl>
#include <QDebug>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    if (argc < 2) {
        qWarning() << "Usage: ImageViewer <folder_path>";
        return 1;
    }

    QString folderPath = QString::fromLocal8Bit(argv[1]);
    QDir dir(folderPath);

    if (!dir.exists()) {
        qWarning() << "Folder does not exist:" << folderPath;
        return 1;
    }

    QStringList imageExtensions = {"*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp", "*.webp", "*.tiff", "*.heic", "*.heif"};
    QFileInfoList imageFiles = dir.entryInfoList(imageExtensions, QDir::Files);

    QStringList imageUrls;
    for (const QFileInfo &fileInfo : imageFiles) {
        imageUrls.append(QUrl::fromLocalFile(fileInfo.absoluteFilePath()).toString());
    }

    QQmlApplicationEngine engine;
    QQmlContext *context = engine.rootContext();
    context->setContextProperty("imageUrls", QVariant::fromValue(imageUrls));

    const QUrl url(QStringLiteral("qrc:/ImageViewer/ImageViewer.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl)
            QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    return app.exec();
}