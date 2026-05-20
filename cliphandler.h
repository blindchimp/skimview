// Copyright (c) 2026-present, Dwyco, Inc.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

#ifndef CLIPHANDLER_H
#define CLIPHANDLER_H

#include <QObject>
#include <QClipboard>
#include <QUrl>

class ClipboardHandler : public QObject
{
    Q_OBJECT
public:
    explicit ClipboardHandler(QObject *parent = nullptr);

    Q_INVOKABLE void copyToClipboard(const QUrl &url) const;
    Q_INVOKABLE void copyToClipboard(const QString &text) const;
};

#endif // CLIPHANDLER_H
