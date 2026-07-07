// Copyright (c) 2026-present, Dwyco, Inc.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this file,
// You can obtain one at https://mozilla.org/MPL/2.0/.

#ifndef TAGGINGHANDLER_H
#define TAGGINGHANDLER_H

#include <QObject>
#include <QProcess>

class TaggingHandler : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ isRunning NOTIFY runningChanged)
    Q_PROPERTY(QString errorMessage READ errorMessage NOTIFY errorMessageChanged)
    Q_PROPERTY(int ocrCompleted READ ocrCompleted NOTIFY progressChanged)
    Q_PROPERTY(int ocrTotal READ ocrTotal NOTIFY progressChanged)
    Q_PROPERTY(int tagCompleted READ tagCompleted NOTIFY progressChanged)
    Q_PROPERTY(int tagTotal READ tagTotal NOTIFY progressChanged)
public:
    explicit TaggingHandler(QObject *parent = nullptr);
    ~TaggingHandler();

    Q_INVOKABLE void start(const QString &folderUrl);
    Q_INVOKABLE void startForFile(const QString &fileUrl);
    Q_INVOKABLE void cancel();

    bool isRunning() const;
    QString errorMessage() const;
    int ocrCompleted() const;
    int ocrTotal() const;
    int tagCompleted() const;
    int tagTotal() const;

signals:
    void runningChanged();
    void errorMessageChanged();
    void progressChanged();
    void finished(bool success);

private slots:
    void onProcessFinished(int exitCode, QProcess::ExitStatus status);
    void onErrorOccurred(QProcess::ProcessError error);
    void onReadyReadStdout();

private:
    void parseProgressLine(const QByteArray &line);
    void killProcessGroup();
    QString findScript() const;
    QString parseDependencyHint(const QString &output) const;

    QProcess *m_process;
    QString m_errorMessage;
    QByteArray m_readBuffer;
    int m_ocrCompleted = 0;
    int m_ocrTotal = 0;
    int m_tagCompleted = 0;
    int m_tagTotal = 0;
};

#endif // TAGGINGHANDLER_H
