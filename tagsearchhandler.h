#ifndef TAGSEARCHHANDLER_H
#define TAGSEARCHHANDLER_H

#include <QObject>
#include <QStringList>
#include <QVariant>

class TagSearchHandler : public QObject
{
    Q_OBJECT
public:
    explicit TagSearchHandler(QObject *parent = nullptr);

    Q_INVOKABLE QStringList search(const QString &folderUrl, const QString &query) const;
    Q_INVOKABLE QVariantMap getImageInfo(const QString &imageUrl) const;
};

#endif // TAGSEARCHHANDLER_H
