#include "livetextanalyzer.h"

#include <QVariant>

#include <deepin-ocr-plugin-manager/deepinocrplugindef.h>
#include <deepin-ocr-plugin-manager/deepinocrplugin.h>

#include <QtConcurrent/QtConcurrent>

LiveTextAnalyzer::LiveTextAnalyzer(QObject *parent)
    : QObject(parent)
    , QQuickImageProvider(Image)
    , ocrDriver(new DeepinOCRPlugin::DeepinOCRDriver)
{
    ocrDriver->loadDefaultPlugin();
    ocrDriver->setUseHardware({{DeepinOCRPlugin::HardwareID::GPU_Vulkan, 0}});
}

void LiveTextAnalyzer::setImage(const QImage &image)
{
    imageCache = image;
    QImage image_copy = image.convertToFormat(QImage::Format_RGB888);
    ocrDriver->setMatrix(image_copy.height(), image_copy.width(), image_copy.bits(),
                         static_cast<size_t>(image_copy.bytesPerLine()), DeepinOCRPlugin::PixelType::Pixel_RGB);
}

void LiveTextAnalyzer::analyze()
{
    //FIXME: 多线程同步存在问题，导致切换图片的时候可能会出现未及时清理旧的Live Block的情况，暂无处理办法
    //关闭多线程即可消除BUG，但界面会变得卡顿
    QtConcurrent::run([this]() {
        while(ocrDriver->isRunning()) {}; //等待之前的分析结束
        emit analyzeFinished(ocrDriver->analyze());
    });
}

void LiveTextAnalyzer::breakAnalyze()
{
    ocrDriver->breakAnalyze();
}

QVariant LiveTextAnalyzer::liveBlock() const
{
    auto boxes = ocrDriver->getTextBoxes();

    QList<QVariant> result;
    for(auto &box : boxes) {
        QList<QVariant> temp;
        for(size_t i = 0;i != box.points.size();++i) {
            temp.push_back(box.points[i].first);
            temp.push_back(box.points[i].second);
        }
        temp.push_back(box.angle);
        result.push_back(temp);
    }

    return result;
}

QVariant LiveTextAnalyzer::charBox(int blockIndex) const
{
    if(static_cast<size_t>(blockIndex) >= ocrDriver->getTextBoxes().size()) {
        return QVariant();
    }

    auto boxes = ocrDriver->getCharBoxes(static_cast<size_t>(blockIndex));

    QList<QVariant> result;

    float base = boxes[0].points[0].first;
    result.push_back(0);
    for(auto &box : boxes) {
        result.push_back(box.points[1].first - base);
    }

    return result;
}

QString LiveTextAnalyzer::textResult(int blockIndex, int startIndex, int len) const
{
    if(static_cast<size_t>(blockIndex) >= ocrDriver->getTextBoxes().size() || startIndex < 0 || len <= 0) {
        return "";
    }

    QString fullStr(ocrDriver->getResultFromBox(static_cast<size_t>(blockIndex)).c_str());
    return fullStr.mid(startIndex, len);
}

//格式：random_index
QImage LiveTextAnalyzer::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    auto startIndex = id.indexOf("_") + 1;
    size_t index = id.mid(startIndex).toUInt();

    if(index >= ocrDriver->getTextBoxes().size()) {
        return QImage();
    }

    auto box = ocrDriver->getTextBoxes()[index];
    QRect rect(QPoint(static_cast<int>(box.points[0].first), static_cast<int>(box.points[0].second)),
               QPoint(static_cast<int>(box.points[2].first), static_cast<int>(box.points[2].second)));
    QImage image = imageCache.copy(rect);
    if(size != nullptr)
    {
        *size = image.size();
    }
    if(requestedSize.width() > 0 && requestedSize.height() > 0) {
        return image.scaled(requestedSize);
    } else {
        return image;
    }
}
