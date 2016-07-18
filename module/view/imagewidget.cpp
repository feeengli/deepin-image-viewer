#include "imagewidget.h"
#include "controller/databasemanager.h"
#include "utils/imageutils.h"
#include <QApplication>
#include <QDebug>
#include <QDesktopWidget>
#include <QFileInfo>
#include <QMouseEvent>
#include <QPainter>

ImageWidget::ImageWidget(QWidget *parent)
    : QWidget(parent)
{
    setMouseTracking(true);
}

void ImageWidget::setImage(const QString &path)
{
    setImage(QImage(path));
    m_path = path;
}

QString ImageWidget::imagePath() const
{
    return m_path;
}

void ImageWidget::setImage(const QImage &image)
{
    m_image = image;
    m_pixmap = QPixmap::fromImage(m_image);
    resetTransform();
}

QString ImageWidget::imageName() const
{
    return QFileInfo(m_path).fileName();
}

/*!
 * \brief ImageWidget::resetTransform
 * Reset transform to fit main widget
 */
void ImageWidget::resetTransform()
{
    m_o_dev = rect().center();
    m_flipX = m_flipY = 1;
    m_rot = 0;
    if (m_image.isNull())
        return;
    m_o_img = QPoint(m_image.width()/2, m_image.height()/2);
    m_scale = windowRelativeScale();
    updateTransform();
}

qreal ImageWidget::scaleValue() const
{
    if (m_image.isNull())
        return 0;
    // m_scale is relate on window's size, it need to be relate on image
    return m_scale / windowRelativeScale();
}

void ImageWidget::setImageMove(int x, int y)
{
    setTransformOrigin(QPoint(x, y), QPoint());
}

void ImageWidget::setScaleValue(qreal value)
{
    if (m_image.isNull())
        return;

    // Move back to center of window if image scale smaller than window
    if (value <= 1) {
        m_o_dev = rect().center();    m_flipX = m_flipY = 1;
        m_o_img = QPoint(m_image.width()/2, m_image.height()/2);
    }

    // value is relate on image's size, it need to be relate on window
    m_scale = windowRelativeScale() * value;
    Q_EMIT scaleValueChanged(value);
    updateTransform();
}

void ImageWidget::rotateClockWise()
{
    rotate(m_rot+90);
    utils::image::rotate(m_path, 90);
    setImage(QString(m_path));
    DatabaseManager::instance()->updateThumbnail(imageName());
}

void ImageWidget::rotateCounterclockwise()
{
    rotate(m_rot-90);
    utils::image::rotate(m_path, -90);
    setImage(QString(m_path));
    DatabaseManager::instance()->updateThumbnail(imageName());
}

void ImageWidget::rotate(int deg)
{
    if (m_rot == deg%360)
        return;
    m_rot = deg%360;
    updateTransform();
}

void ImageWidget::flipX()
{
    m_flipX = -m_flipX;
    updateTransform();
    Q_EMIT fliped(m_flipX < 0, m_flipY < 0);
}

void ImageWidget::flipY()
{
    m_flipY = -m_flipY;
    updateTransform();
    Q_EMIT fliped(m_flipX < 0, m_flipY < 0);
}

void ImageWidget::setTransformOrigin(const QPoint& imageP, const QPoint& deviceP)
{
    if (m_o_dev == deviceP && m_o_img == imageP)
        return;
    m_o_dev = deviceP;
    m_o_img = imageP;
    updateTransform();
}

QPoint ImageWidget::mapToImage(const QPoint &p) const
{
    return m_mat.inverted().map(p);
}

QRect ImageWidget::mapToImage(const QRect& r) const
{
    return m_mat.inverted().mapRect(r);
}

QRect ImageWidget::visibleImageRect() const
{
    return mapToImage(rect()) & QRect(0, 0, m_image.width(), m_image.height());
}

bool ImageWidget::isWholeImageVisible() const
{
    return visibleImageRect().size() == m_image.size();
}

bool ImageWidget::isMoving() const
{
    return m_moving;
}

void ImageWidget::timerEvent(QTimerEvent *e)
{
    if (e->timerId() != m_tid)
        return;
    m_scaling = false;
    update();
}

void ImageWidget::paintEvent(QPaintEvent *)
{
    QPainter p(this);
    p.save();

    p.setRenderHint(QPainter::Antialiasing);
    p.setRenderHint(QPainter::SmoothPixmapTransform);

    p.setTransform(m_mat);
    p.drawPixmap(0, 0, m_pixmap);
    p.restore();
}

void ImageWidget::mousePressEvent(QMouseEvent *event)
{
    if (event->button() == Qt::LeftButton) {
        m_pos = event->pos();
        m_posG = event->globalPos();
        m_moving = true;
    }
}

void ImageWidget::mouseReleaseEvent(QMouseEvent *event)
{
    Q_UNUSED(event);
    m_pos = m_posG = QPoint();
    m_moving = false;
}

void ImageWidget::mouseMoveEvent(QMouseEvent *event)
{
    if (m_moving && ! m_inSlideShow) {
        QPoint dp = event->globalPos() - m_posG;

        // To ensure that pictures are not being dragged out of the window edge
        QPoint img_o = QTransform().rotate(m_rot).
                scale(m_scale*m_flipX, m_scale*m_flipY).map(m_o_img);
        QPoint deviceP = m_o_dev + dp;
        qreal dx = deviceP.x() - (qreal)img_o.x();
        qreal dy = deviceP.y() - (qreal)img_o.y();
        const int imgW = (m_image.size() * m_scale).width();
        const int imgH = (m_image.size() * m_scale).height();
        if (imgW >= width() || imgH >= height()) {
            if (dx > 0 || (dx <= 0 && (dx + imgW) < width()))
                deviceP.setX(m_o_dev.x());
            if (dy > 0 || (dy <= 0 && (dy + imgH) < height()))
                deviceP.setY(m_o_dev.y());
        }
        else {
            // Prohibit drag the image if it's size small than window's
            return;
        }

        setTransformOrigin(m_o_img, deviceP);
        m_pos = event->pos();
        m_posG = event->globalPos();
    }

    QWidget::mouseMoveEvent(event);
}

void ImageWidget::wheelEvent(QWheelEvent *event)
{
    if (m_inSlideShow)
        return;
    m_scaling = true;
    killTimer(m_tid);
    m_tid = startTimer(500);
    setTransformOrigin(mapToImage(event->pos()), event->pos());
    qreal deg = event->angleDelta().y()/8;
    QPoint dp = event->pixelDelta();
    qreal zoom = m_scale / windowRelativeScale();
    if (dp.isNull())
        zoom += deg*3.14/180.0;
    else
        zoom += dp.y()/100.0;

    zoom = qBound(qreal(0.5), zoom, qreal(10));
    setScaleValue(zoom);
}

void ImageWidget::updateTransform()
{
    if (m_image.isNull())
        return;
    const QTransform old = m_mat;
    m_mat.reset();
    QPoint img_o = QTransform().rotate(m_rot).scale(m_scale*m_flipX, m_scale*m_flipY).map(m_o_img);
    const int dx = m_o_dev.x() - (qreal)img_o.x();
    const int dy = m_o_dev.y() - (qreal)img_o.y();
    m_mat.translate(dx, dy);
    m_mat.rotate(m_rot);
    m_mat.scale(m_scale*m_flipX, m_scale*m_flipY);
    update();
    if (m_mat != old) {
        Q_EMIT transformChanged(m_mat);
    }
}

qreal ImageWidget::windowRelativeScale() const
{
    if (m_image.isNull())
        return 1;
    const QSize s = m_image.size().scaled(rect().size(), Qt::KeepAspectRatio);
    if (m_image.width() > m_image.height()) {
        return 1.0 * s.width() / m_image.width();
    }
    else {
        return 1.0 * s.height() / m_image.height();
    }
}

bool ImageWidget::inSlideShow() const
{
    return m_inSlideShow;
}

void ImageWidget::setInSlideShow(bool inSlideShow)
{
    m_inSlideShow = inSlideShow;
}
