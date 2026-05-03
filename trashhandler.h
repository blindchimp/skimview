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
