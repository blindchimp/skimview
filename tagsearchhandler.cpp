#include "tagsearchhandler.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QUrl>

TagSearchHandler::TagSearchHandler(QObject *parent)
    : QObject(parent)
{
}

QStringList TagSearchHandler::search(const QString &folderUrl, const QString &query) const
{
    QStringList results;

    if (query.trimmed().isEmpty())
        return results;

    QString folderPath = folderUrl;
    if (folderPath.startsWith("file://"))
        folderPath = QUrl(folderPath).toLocalFile();

    QDir dir(folderPath);
    QString dbPath = dir.filePath("tags.db");

    if (!QFile::exists(dbPath))
        return results;

    // Unique name per call avoids "connection still in use" errors
    QString connName = QString("tagSearch_%1").arg(reinterpret_cast<quintptr>(this));

    {
        QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connName);
        db.setDatabaseName(dbPath);

        if (db.open())
        {
            QSqlQuery q(db);
            q.prepare("SELECT path FROM images WHERE tags LIKE ? OR ocr_text LIKE ? OR description LIKE ?");
            QString pattern = "%" + query + "%";
            q.addBindValue(pattern);
            q.addBindValue(pattern);
            q.addBindValue(pattern);

            if (q.exec())
            {
                while (q.next())
                {
                    QString fullPath = q.value(0).toString();
                    results.append(QFileInfo(fullPath).fileName());
                }
            }
        }
        // q and db destroyed here, before removeDatabase
    }

    QSqlDatabase::removeDatabase(connName);

    return results;
}
