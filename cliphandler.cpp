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
