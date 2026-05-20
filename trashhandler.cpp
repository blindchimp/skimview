// Copyright (c) 2026-present, Dwyco, Inc.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

#include "trashhandler.h"
#include <QFile>

TrashHandler::TrashHandler(QObject *parent)
    : QObject(parent)
{
}

bool TrashHandler::moveToTrash(const QUrl &url) const
{
    return QFile::moveToTrash(url.toLocalFile());
}
