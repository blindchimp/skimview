// Copyright (c) 2026-present, Dwyco, Inc.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

#include "tagsearchhandler.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QUrl>
#include <QVariantMap>

static QString toLocalPath(const QString &url)
{
    if (url.startsWith("file://"))
        return QUrl(url).toLocalFile();
    return url;
}

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

bool TagSearchHandler::hasTagsDb(const QString &folderUrl) const
{
    QString path = toLocalPath(folderUrl);
    return QFile::exists(path + "/tags.db");
}

bool TagSearchHandler::deleteTagsDb(const QString &folderUrl) const
{
    QString path = toLocalPath(folderUrl);
    if (!QFile::exists(path + "/tags.db"))
        return false;
    bool ok = QFile::remove(path + "/tags.db");
    QFile::remove(path + "/tags.db-wal");
    QFile::remove(path + "/tags.db-shm");
    return ok;
}

QVariantMap TagSearchHandler::getImageInfo(const QString &imageUrl) const
{
    QVariantMap info;
    info["ocr_text"] = "";
    info["tags"] = "";

    if (imageUrl.isEmpty())
        return info;

    QString imagePath = imageUrl;
    if (imagePath.startsWith("file://"))
        imagePath = QUrl(imagePath).toLocalFile();

    QFileInfo fi(imagePath);
    QString dbPath = fi.dir().path() + "/tags.db";

    if (!QFile::exists(dbPath))
        return info;

    QString connName = QString("tagSearch_info_%1").arg(reinterpret_cast<quintptr>(this));

    {
        QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connName);
        db.setDatabaseName(dbPath);

        if (db.open())
        {
            QSqlQuery q(db);
            q.prepare("SELECT ocr_text, tags FROM images WHERE path = ?");
            q.addBindValue(imagePath);

            if (q.exec() && q.next())
            {
                info["ocr_text"] = q.value(0).toString();
                info["tags"] = q.value(1).toString();
            }
        }
    }

    QSqlDatabase::removeDatabase(connName);

    return info;
}
