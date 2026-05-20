// Copyright (c) 2026-present, Dwyco, Inc.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

#ifndef TAGSEARCHHANDLER_H
#define TAGSEARCHHANDLER_H

#include <QObject>
#include <QStringList>
#include <QVariant>

class TagSearchHandler : public QObject
{
    Q_OBJECT
public:
    explicit TagSearchHandler(QObject *parent = nullptr);

    Q_INVOKABLE QStringList search(const QString &folderUrl, const QString &query) const;
    Q_INVOKABLE QVariantMap getImageInfo(const QString &imageUrl) const;
    Q_INVOKABLE bool hasTagsDb(const QString &folderUrl) const;
    Q_INVOKABLE int tagCount(const QString &folderUrl) const;
    Q_INVOKABLE bool deleteTagsDb(const QString &folderUrl) const;
};

#endif // TAGSEARCHHANDLER_H
