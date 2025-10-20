// 程序入口：创建 QML 引擎，注入由生成器提供的 ImageViewer 对象供 QML 调用
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
    // 由 rust_qt_binding_generator 生成的 C++ 包装类
    ImageViewer viewer;
    engine.rootContext()->setContextProperty("viewer", &viewer);

    // 主 QML 文件通过资源系统加载
    const QUrl url(QStringLiteral("qrc:/qml/main.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated, &app, [url](QObject *obj, const QUrl &objUrl) {
        if (!obj && url == objUrl) QCoreApplication::exit(-1);
    }, Qt::QueuedConnection);

    engine.load(url);

    // 可选：从命令行传入要打开的 PNG 路径
    if (argc > 1) {
        const QString path = QString::fromLocal8Bit(argv[1]);
        engine.rootContext()->setContextProperty("argvPath", path);
        viewer.set_image_path(path);
    }


    return app.exec();
}

// main.moc 不需要，因为没有 Q_OBJECT 宏


