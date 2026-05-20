// Copyright (c) 2026-present, Dwyco, Inc.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

#include "cliphandler.h"
#include <QGuiApplication>
#include <QClipboard>
#include <QUrl>

ClipboardHandler::ClipboardHandler(QObject *parent)
    : QObject(parent)
{
}

void ClipboardHandler::copyToClipboard(const QUrl &url) const
{
    QGuiApplication::clipboard()->setText(url.toLocalFile());
}

void ClipboardHandler::copyToClipboard(const QString &text) const
{
    QGuiApplication::clipboard()->setText(text);
}
