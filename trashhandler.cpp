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
