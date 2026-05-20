// Copyright (c) 2026-present, Dwyco, Inc.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

#ifndef TRASHHANDLER_H
#define TRASHHANDLER_H

#include <QObject>
#include <QUrl>

class TrashHandler : public QObject
{
    Q_OBJECT
public:
    explicit TrashHandler(QObject *parent = nullptr);

    Q_INVOKABLE bool moveToTrash(const QUrl &url) const;
};

#endif // TRASHHANDLER_H
