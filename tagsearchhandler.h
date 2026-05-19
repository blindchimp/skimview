#ifndef TAGSEARCHHANDLER_H
#define TAGSEARCHHANDLER_H

#include <QObject>
#include <QStringList>

class TagSearchHandler : public QObject
{
    Q_OBJECT
public:
    explicit TagSearchHandler(QObject *parent = nullptr);

    Q_INVOKABLE QStringList search(const QString &folderUrl, const QString &query) const;
};

#endif // TAGSEARCHHANDLER_H
