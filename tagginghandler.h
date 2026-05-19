#ifndef TAGGINGHANDLER_H
#define TAGGINGHANDLER_H

#include <QObject>
#include <QProcess>

class TaggingHandler : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
public:
    explicit TaggingHandler(QObject *parent = nullptr);
    ~TaggingHandler();

    Q_INVOKABLE void start(const QString &folderUrl);
    Q_INVOKABLE void cancel();

    bool isRunning() const;
    QString errorMessage() const;

signals:
    void runningChanged();
    void errorMessageChanged();
    void finished(bool success);

private slots:
    void onProcessFinished(int exitCode, QProcess::ExitStatus status);
    void onErrorOccurred(QProcess::ProcessError error);

private:
    QString findScript() const;
    QString parseDependencyHint(const QString &output) const;

    QProcess *m_process;
    QString m_errorMessage;
};

#endif // TAGGINGHANDLER_H
