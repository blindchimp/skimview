#include "cliphandler.h"
#include <QGuiApplication>
#include <QClipboard>

ClipboardHandler::ClipboardHandler(QObject *parent)
    : QObject(parent)
{
}

void ClipboardHandler::copyToClipboard(const QString &text) const
{
    QGuiApplication::clipboard()->setText(text);
}
