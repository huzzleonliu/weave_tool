#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QDebug>
#include <QObject>
#include <QObject>
#include <QCoreApplication>
#include "generated/viewer_cxx.h"
#include <cstdlib>

// 旧桥接已移除；使用生成的 ImageViewer 直接在 QML 中调用

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    QQmlApplicationEngine engine;
    ImageViewer viewer;
    engine.rootContext()->setContextProperty("viewer", &viewer);

    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    if (argc > 1) {
        const QString path = QString::fromLocal8Bit(argv[1]);
        engine.rootContext()->setContextProperty("argvPath", path);
        viewer.set_image_path(path);
    }


    return app.exec();
}

// main.moc 不需要，因为没有 Q_OBJECT 宏


