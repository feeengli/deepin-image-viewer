#include "toptoolbar.h"
#include "controller/importer.h"
#include "controller/popupmenumanager.h"
#include "controller/signalmanager.h"
#include "controller/importer.h"
#include "frame/mainwindow.h"
#include "widgets/progressdialog.h"
#include <dcircleprogress.h>
#include <dwindowminbutton.h>
#include <dwindowclosebutton.h>
#include <dwindowoptionbutton.h>
#include <dwindowrestorebutton.h>
#include <QDebug>
#include <QGradient>
#include <QResizeEvent>
#include <QApplication>
#include <QStackedWidget>
#include <QPainter>

using namespace Dtk::Widget;

namespace {

const int TOP_TOOLBAR_HEIGHT = 40;
const int ICON_MARGIN = 6;
}  // namespace

TopToolbar::TopToolbar(QWidget *parent, QWidget *source)
    :BlureFrame(parent, source)
{
    QLinearGradient linearGrad;
    linearGrad.setColorAt(0, QColor(15, 15, 15, 178));
    linearGrad.setColorAt(1, QColor(15, 15, 15, 204));

    setCoverBrush(QBrush(linearGrad));

    m_about = new AboutWindow(parent, source);
    m_about->hide();

    initWidgets();
    initMenu();

    parent->installEventFilter(this);
    connect(this, SIGNAL(moving()),
            parentWidget()->parentWidget(), SLOT(startMoving()));
    connect(Importer::instance(), &Importer::importStart, this,
            &TopToolbar::initProgressDailog);
}

void TopToolbar::setLeftContent(QWidget *content)
{
    QLayoutItem *child;
    while ((child = m_leftLayout->takeAt(0)) != 0) {
        if (child->widget())
            child->widget()->deleteLater();
        delete child;
    }
    m_leftLayout->addWidget(content);
}

void TopToolbar::setMiddleContent(QWidget *content)
{
    QLayoutItem *child;
    while ((child = m_middleLayout->takeAt(0)) != 0) {
        if (child->widget())
            child->widget()->deleteLater();
        delete child;
    }

    m_middleLayout->addWidget(content);
}

bool TopToolbar::eventFilter(QObject *obj, QEvent *e)
{
    Q_UNUSED(obj)
    if (e->type() == QEvent::Resize) {
        if (window()->isMaximized() != m_maxb->isMaximized()) {
            m_maxb->clicked();
        }
    }
    return false;
}

void TopToolbar::resizeEvent(QResizeEvent *e)
{
    m_leftContent->setFixedWidth(e->size().width() / 3);
    m_middleContent->setFixedWidth(e->size().width() / 3);
    m_rightContent->setFixedWidth(e->size().width() / 3);
}

void TopToolbar::mouseMoveEvent(QMouseEvent *event)
{
    Q_UNUSED(event);
    emit moving();
}

void TopToolbar::mouseDoubleClickEvent(QMouseEvent *e)
{
    if (e->button() == Qt::LeftButton) {
        if (window()->isMaximized())
            window()->showNormal();
        else if (! window()->isFullScreen())  // It would be normal state
            window()->showMaximized();
    }
}

void TopToolbar::paintEvent(QPaintEvent *e)
{
    BlureFrame::paintEvent(e);

    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);

    // Draw inside top border
    const QColor tc(255, 255, 255, 56);
    const int borderHeight = 1;
    QPainterPath tPath;
    tPath.moveTo(x(), y() + borderHeight);
    tPath.lineTo(x() + width(), y() + borderHeight);

    QPen tPen(tc, borderHeight);
    QLinearGradient linearGrad;
    linearGrad.setStart(x(), y() + borderHeight);
    linearGrad.setFinalStop(x() + width(), y() + borderHeight);
    linearGrad.setColorAt(0, Qt::transparent);
    linearGrad.setColorAt(0.01, tc);
    linearGrad.setColorAt(0.99, tc);
    linearGrad.setColorAt(1, Qt::transparent);
    tPen.setBrush(QBrush(linearGrad));
    p.setPen(tPen);
    p.drawPath(tPath);

    // Draw inside bottom border
    QPainterPath bPath;
    bPath.moveTo(x(), y() + height() - borderHeight);
    bPath.lineTo(x() + width(), y() + height() - borderHeight);
    QPen bPen(QColor(0, 0, 0, 25), borderHeight);
    p.setPen(bPen);
    p.drawPath(bPath);
}

void TopToolbar::initWidgets()
{
    QHBoxLayout *mainLayout = new QHBoxLayout(this);
    mainLayout->setContentsMargins(0, 0, 0, 0);
    mainLayout->setSpacing(0);

    DCircleProgress *importProgress = new DCircleProgress;
    importProgress->setValue(0);
    importProgress->setFixedSize(21, 21);
    importProgress->setVisible(false);
    connect(Importer::instance(), &Importer::importProgressChanged,
            this, [=] (double progress) {
        importProgress->setVisible(progress != 1);
        importProgress->setValue(progress * 100);
    });

    DWindowOptionButton *ob = new DWindowOptionButton;
    connect(ob, &DWindowOptionButton::clicked, this, [=] {
        if (parentWidget()) {
            m_popupMenu->setMenuContent(createMenuContent());
            m_popupMenu->showMenu();
        }
    });
    connect(SignalManager::instance(), &SignalManager::enableMainMenu,
            this, [=] (bool enable) {
        ob->setVisible(enable);
        ob->setEnabled(enable);
        });

    DWindowMinButton *minb = new DWindowMinButton;
    connect(minb, SIGNAL(clicked()), parentWidget()->parentWidget(), SLOT(showMinimized()));

    m_maxb = new DWindowMaxButton;
    connect(m_maxb, &DWindowMaxButton::maximum, window(), &QWidget::showMaximized);
    connect(m_maxb, &DWindowMaxButton::restore, window(), &QWidget::showNormal);

    DWindowCloseButton *cb = new DWindowCloseButton;
    connect(cb, &DWindowCloseButton::clicked, qApp, &QApplication::quit);

    m_rightContent = new QWidget;
    QHBoxLayout *rightLayout = new QHBoxLayout(m_rightContent);
    rightLayout->setContentsMargins(0, 0, 0, 0);
    rightLayout->setSpacing(0);
    rightLayout->addStretch(1);
    rightLayout->addWidget(importProgress);
    rightLayout->addSpacing(38);
    rightLayout->addWidget(ob);
    rightLayout->addWidget(minb);
    rightLayout->addWidget(m_maxb);
    rightLayout->addWidget(cb);

    m_leftContent = new QWidget;
    m_leftLayout = new QHBoxLayout(m_leftContent);
    m_leftLayout->setContentsMargins(0, 0, 0, 0);
    m_leftLayout->setSpacing(0);

    m_middleContent = new QWidget;
    m_middleLayout = new QHBoxLayout(m_middleContent);
    m_middleLayout->setContentsMargins(0, 0, 0, 0);
    m_middleLayout->setSpacing(0);

    mainLayout->addWidget(m_leftContent);
    mainLayout->addWidget(m_middleContent);
    mainLayout->addWidget(m_rightContent);
    mainLayout->addSpacing(ICON_MARGIN);
}

void TopToolbar::initMenu()
{
    m_popupMenu = new PopupMenuManager(this);
    connect(m_popupMenu, &PopupMenuManager::menuItemClicked,
            this, &TopToolbar::onMenuItemClicked);
    m_popupMenu->setMenuContent(createMenuContent());
}

QString TopToolbar::createMenuContent()
{
    QJsonArray items;
    items.append(createMenuItem(IdCreateAlbum, tr("New album"), false,
                                "Ctrl+Shift+N"));
    items.append(createMenuItem(IdImport, tr("Import"), false, "Ctrl+I"));

    items.append(createMenuItem(IdSeparator, "", true));

    items.append(createMenuItem(IdHelp, tr("Help"), false, "F1"));
    items.append(createMenuItem(IdAbout, tr("About")));
    items.append(createMenuItem(IdQuick, tr("Exit"), false, "Ctrl+Q"));

    QJsonObject contentObj;
    const QPoint gp = this->mapToGlobal(QPoint(0, 0));
    const QSize ms = m_popupMenu->sizeHint();
    contentObj["x"] = gp.x() + width() - ms.width() - 14;
    contentObj["y"] = gp.y() + TOP_TOOLBAR_HEIGHT - 10;
    contentObj["items"] = QJsonValue(items);

    QJsonDocument document(contentObj);

    return QString(document.toJson());
}

QJsonValue TopToolbar::createMenuItem(const MenuItemId id,
                                     const QString &text,
                                     const bool isSeparator,
                                     const QString &shortcut,
                                     const QJsonObject &subMenu)
{
    return QJsonValue(m_popupMenu->createItemObj(id,
                                                 text,
                                                 isSeparator,
                                                 shortcut,
                                                 subMenu));
}

void TopToolbar::onMenuItemClicked(int menuId, const QString &text)
{
    Q_UNUSED(text);

    switch (MenuItemId(menuId)) {
    case IdCreateAlbum:
        emit SignalManager::instance()->createAlbum();
        break;
    case IdImport:
        Importer::instance()->showImportDialog();
        break;
    case IdHelp:
        showManual();
        break;
    case IdAbout:
        m_about->move((width() - m_about->width()) / 2 +
                      mapToGlobal(QPoint(0, 0)).x(),
                      (window()->height() - m_about->height()) / 2 +
                      mapToGlobal(QPoint(0, 0)).y());
        m_about->show();
        break;
    case IdQuick:
        qApp->quit();
    default:
        break;
    }
}

void TopToolbar::showManual()
{
    if (m_manualPro.isNull()) {
        const QString pro = "dman";
        const QStringList args("deepin-image-viewer");
        m_manualPro = new QProcess(this);
        connect(m_manualPro.data(), SIGNAL(finished(int)), m_manualPro.data(), SLOT(deleteLater()));
        m_manualPro->start(pro, args);
    }
}

void TopToolbar::initProgressDailog() {
    ProgressDialog* proDailog =  new ProgressDialog;

    proDailog->setTitle(tr("Importing images"));
    proDailog->setTips(QString(tr("%1 image(s) imported, please wait")).arg(0));
    proDailog->show();
    connect(Importer::instance(), &Importer::importProgressChanged, [=](double per) {
        if (per == 1) {
            proDailog->close();
        }
        proDailog->setValue(int(per*100));
        proDailog->setTips(QString("%1 image(s) imported, please wait").arg(Importer::instance()->finishedCount()));
    });

    connect(proDailog, &ProgressDialog::stopProgress, Importer::instance(), &Importer::stopImport);
}
