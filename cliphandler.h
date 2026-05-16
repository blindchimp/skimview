#ifndef CLIPHANDLER_H
#define CLIPHANDLER_H

#include <QObject>
#include <QClipboard>

class ClipboardHandler : public QObject
{
    Q_OBJECT
public:
    explicit ClipboardHandler(QObject *parent = nullptr);

    Q_INVOKABLE void copyToClipboard(const QString &text) const;
};

#endif // CLIPHANDLER_H
