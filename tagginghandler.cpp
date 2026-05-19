#include "tagginghandler.h"
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QUrl>
#include <QDebug>

TaggingHandler::TaggingHandler(QObject *parent)
    : QObject(parent)
    , m_process(nullptr)
{
}

TaggingHandler::~TaggingHandler()
{
    if (m_process)
    {
        m_process->kill();
        m_process->waitForFinished(3000);
    }
}

void TaggingHandler::start(const QString &folderUrl)
{
    if (m_process && m_process->state() != QProcess::NotRunning)
    {
        qWarning() << "Tagging already running";
        return;
    }

    m_errorMessage.clear();
    emit errorMessageChanged();

    QString folderPath = folderUrl;
    if (folderPath.startsWith("file://"))
        folderPath = QUrl(folderPath).toLocalFile();

    QString script = findScript();
    if (script.isEmpty())
    {
        m_errorMessage = "Could not find tools/tag_images.py. Make sure the tools directory is present.";
        emit errorMessageChanged();
        emit finished(false);
        return;
    }

    if (m_process)
    {
        m_process->deleteLater();
        m_process = nullptr;
    }

    m_process = new QProcess(this);
    connect(m_process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            this, &TaggingHandler::onProcessFinished);
    connect(m_process, &QProcess::errorOccurred,
            this, &TaggingHandler::onErrorOccurred);

    m_process->setProcessChannelMode(QProcess::MergedChannels);
    m_process->start("python3", {script, "--recursive", folderPath});
    emit runningChanged();
}

void TaggingHandler::cancel()
{
    if (!m_process || m_process->state() == QProcess::NotRunning)
        return;

    // Block signals so onProcessFinished doesn't override our message
    m_process->blockSignals(true);
    m_process->kill();
    m_process->waitForFinished(2000);
    m_process->deleteLater();
    m_process = nullptr;

    m_errorMessage = "Tagging cancelled.";
    emit errorMessageChanged();
    emit runningChanged();
    emit finished(false);
}

bool TaggingHandler::isRunning() const
{
    return m_process && m_process->state() != QProcess::NotRunning;
}

QString TaggingHandler::errorMessage() const
{
    return m_errorMessage;
}

void TaggingHandler::onProcessFinished(int exitCode, QProcess::ExitStatus status)
{
    QString output = m_process ? m_process->readAll().trimmed() : QString();

    // Capture output to /tmp/tag.out for debugging (always)
    QFile outFile("/tmp/tag.out");
    if (outFile.open(QIODevice::WriteOnly | QIODevice::Truncate))
    {
        outFile.write(output.toUtf8());
        outFile.close();
    }

    if (status == QProcess::CrashExit)
    {
        m_errorMessage = "The tagging process crashed.";
    }
    else if (exitCode != 0)
    {
        m_errorMessage = parseDependencyHint(output);
    }

    emit runningChanged();
    emit errorMessageChanged();
    emit finished(m_errorMessage.isEmpty());
}

void TaggingHandler::onErrorOccurred(QProcess::ProcessError error)
{
    if (error == QProcess::FailedToStart)
    {
        // FailedToStart is not followed by finished(), so clean up here
        m_errorMessage = "Python 3 is not installed or not in PATH.\n"
                         "Install Python 3 from https://python.org";
        if (m_process)
        {
            m_process->deleteLater();
            m_process = nullptr;
        }
        emit runningChanged();
        emit errorMessageChanged();
        emit finished(false);
    }
    else
    {
        // Other errors (Crashed, Timedout, etc.) are followed by finished()
        m_errorMessage = "The tagging process encountered an error.";
        emit errorMessageChanged();
    }
}

QString TaggingHandler::findScript() const
{
    // Try relative to executable directory
    QStringList searchPaths;
    QString appDir = QCoreApplication::applicationDirPath();
    
    searchPaths << appDir + "/tools/tag_images.py";
    searchPaths << appDir + "/../tools/tag_images.py";
    searchPaths << appDir + "/../../tools/tag_images.py";
    searchPaths << QDir::currentPath() + "/tools/tag_images.py";

#ifdef TOOLS_DIR
    searchPaths << QStringLiteral(TOOLS_DIR) + "/tag_images.py";
#endif

    for (const QString &path : searchPaths)
    {
        QFileInfo fi(path);
        if (fi.exists())
            return fi.absoluteFilePath();
    }

    return QString();
}

QString TaggingHandler::parseDependencyHint(const QString &output) const
{
    if (output.contains("No module named 'pytesseract'"))
        return "Missing Python package: pytesseract\n  Run: pip3 install pytesseract";

    if (output.contains("No module named 'PIL'") || output.contains("No module named 'Pillow'"))
        return "Missing Python package: Pillow\n  Run: pip3 install pillow";

    if (output.contains("No module named 'requests'"))
        return "Missing Python package: requests\n  Run: pip3 install requests";

    if (output.contains("TesseractNotFound") || output.contains("tesseract is not installed"))
        return "Tesseract OCR is not installed.\n  Run: brew install tesseract\n  Then: pip3 install pytesseract";

    if (output.contains("Connection refused") || output.contains("Cannot connect") || output.contains("Ollama"))
        return "Ollama is not running.\n  Install from: https://ollama.ai\n  Then run: ollama pull llava";

    return "Tagging failed. Dependencies needed:\n"
           "  - Python packages: pip3 install pytesseract pillow requests\n"
           "  - Tesseract OCR: brew install tesseract\n"
           "  - Ollama: https://ollama.ai + ollama pull llava";
}
