import QtQuick 2.11
import QtQuick.Window 2.11
import QtQuick.Controls 2.4
//import QtQuick.Controls 1.4
import QtQuick.Layouts 1.11
import org.deepin.dtk 1.0

Rectangle {

    // Indicates the minimum number of zooms
    property int minScaleLevel: 10
    // Indicates the maximum number of zooms
    property int maxScaleLevel: 30
    // Indicates the current scaleLevel of zooms
    property int currentScaleLevel: 0
    //current rotate
    property int currentRotate: 0

    // Indicates the current image path
    property var source
    /*: showImg.source*/
    property var sourcePaths

    // 当前源图片宽度
    property int currentSourceWidth : 0;
    // 当前源图片高度
    property int currentSourceHeight : 0;

    property int index: 0
    property alias swipeIndex: view.currentIndex

    // 用于多页图的标识 包括是否为多页图、多页图帧数、当前帧号
    property bool currentIsMultiImage: fileControl.isMultiImage(source)
    property int frameCount: currentIsMultiImage ? fileControl.getImageCount(source) : 1
    property int frameIndex: 0

    //是否显示和隐藏导航栏，从配置文件中读取初始配置
    property bool  isNavShow: fileControl.isEnableNavigation()

    property double  currentScale : 1.0

    property double  currentimgX : 0.0

    property double  currentimgY : 0.0

    property double  currenImageScale : currentScale / CodeImage.getFitWindowScale(source,root.width, root.height) * 100

    property bool isMousePinchArea: true

    property double readWidthHeightRatio: CodeImage.getrealWidthHeightRatio(imageViewer.source)

    //导航蒙皮位置
    property double  m_NavX : 0.0
    property double  m_NavY : 0.0

    //用于记录normal状态的宽高
    property int normalWidth: 0
    property int normalHeight: 0

    // 记录放大图片(在qml中像素)和显示窗口像素的比值，用于蒙皮获取准确区域
    property real viewImageWidthRatio : 0
    property real viewImageHeightRatio : 0

    // 标识当前是否处于全屏缩放状态，缩放前后部分控件需重置，例如缩略图栏重新居中设置
    property bool isFullNormalSwitchState: showFulltimer.running || showfullAnimation.running

    signal sigWheelChange
    signal sigImageShowFullScreen
    signal sigImageShowNormal
    signal sigSourceChange

    color: backcontrol.ColorSelector.backgroundColor
    ViewRightMenu {
        id: option_menu
    }
    Connections {
        target: root
        onSigTitlePress: {
            infomationDig.hide()
        }

        onWidthChanged: {
            fitWindow()
        }

        onHeightChanged: {
            fitWindow()
        }
    }

    function showFloatLabel() {
        console.info("scale value:", currenImageScale.toFixed(0))
        if(currenImageScale.toFixed(0) > 2000 && currenImageScale.toFixed(0) <= 3000){
            floatLabel.displayStr = "2000%"
        }else if(currenImageScale.toFixed(0)<2 && currenImageScale.toFixed(0) >=0 ){
            floatLabel.displayStr = "2%"
        }else if(currenImageScale.toFixed(0) >=2 && currenImageScale.toFixed(0) <= 2000 ){
            floatLabel.displayStr = currenImageScale.toFixed(0) + "%"
        }
        floatLabel.visible = CodeImage.imageIsNull(source)||currenImageScale.toFixed(0)<0 ||currenImageScale.toFixed(0)>2000 ? false : true
    }

    onCurrenImageScaleChanged: {
        showFloatLabel()
    }

    onCurrentScaleChanged: {
        // 单独计算图片缩放比，防止属性绑定循环计算，数据异常
        var calcImageScale = currentScale / CodeImage.getFitWindowScale(source, root.width, root.height) * 100;
        if(calcImageScale > 2000) {
            currentScale = 20 * CodeImage.getFitWindowScale(source,root.width, root.height)
        } else if(calcImageScale < 2 && calcImageScale > 0){
            currentScale = 0.02 * CodeImage.getFitWindowScale(source,root.width, root.height)
        }

        // 设置隐藏导航窗口时，不处理展示
        if (isNavShow) {
            // 缩放比例变更时（图像适应窗口、全屏展示...），根据缩放比例判断是否需要显示导航窗口
            idNavWidget.visible = currentScale > 1
            // 设置缩放后更新导航窗口
            idNavWidget.setRectPec(currentScale, viewImageWidthRatio, viewImageHeightRatio)
        }
    }

    // 多页图当前图片帧号发生变更，更新当前界面维护的数据信息
    onFrameIndexChanged: {
        // 当前为多页图
        if (currentIsMultiImage) {
            // 设置 fileControl 维护的多页图信息
            fileControl.setCurrentFrameIndex(frameIndex)
            CodeImage.setMultiFrameIndex(frameIndex)
        }
    }

    // 图片源发生改变，隐藏导航区域，重置图片缩放比例
    onSourceChanged: {
        // 多页图索引不在此处进行复位，鼠标点击，按钮切换等不同方式切换显示不同的多页图帧号

        // 保存之前文件的旋转操作(保存前未更新图片需要缓存角度信息)
        fileControl.cacheCurrentImageAngle()
        fileControl.slotRotatePixCurrent()
        CodeImage.setReverseHeightWidth(false)

        // 设置图片状态
        fileControl.setCurrentImage(source)
        CodeImage.setMultiFrameIndex(fileControl.isMultiImage(source) ? 0 : -1)
        // 复位图片旋转状态
        imageViewer.currentRotate = 0
        // 图片重新加载完成，旋转角度恢复，获取当前图片缓存的角度信息(若无返回 0 )
        fileControl.takeCachedImageAngle(source)

        // 默认隐藏导航区域
        idNavWidget.visible = false
        // 判断图片大小是否超过了允许显示的展示区域
        if (fileControl.getFitWindowScale(root.width, root.height - titleRect.height * 2) > 1) {
            fitWindow()
        }
        else {
            fitImage()
        }

        // 设置标题栏
        root.title = fileControl.slotGetFileName(source) + fileControl.slotFileSuffix(source)
        // 显示缩放比例提示框
        showFloatLabel()

        sigSourceChange()

        // 重设工具/菜单栏的隐藏/弹出
        mainView.animationAll()
    }

    // 部分图片存在加载图片过程，重设图片大小调整到图片加载完成后处理 Image.Ready --> onImageReady()
    function onImageReady()
    {
        // 复位图片旋转角度
        imageViewer.currentRotate = 0

        // 取得图片的真实大小，部分格式不支持直接获取图片数据，若数据异常，需要从加载缓存中读取
        currentSourceWidth = fileControl.getCurrentImageWidth()
        currentSourceHeight = fileControl.getCurrentImageHeight()
        if ((currentSourceWidth <= 0)
                || (currentSourceHeight <= 0)) {
            currentSourceWidth = CodeImage.getImageWidth(source)
            currentSourceHeight = CodeImage.getImageHeight(source)
        }

        // 判断图片大小是否超过了允许显示的展示区域
        if (currentSourceHeight > root.height - titleRect.height * 2
                || currentSourceWidth > root.width) {
            fitWindow()
        }
        else {
            fitImage()
        }
    }

    function fitImage()
    {
        // 优先采用图片实际加载的数据，若图片未加载完成，采用文件基本信息
        if (CodeImage.getImageWidth(source) <= 0
                || CodeImage.getImageHeight(source) <= 0) {
            currentScale = fileControl.getFitWindowScale(root.width, root.height)
        } else {
            // 图片数据异常需要从加载完成图片信息中获取
            currentScale = CodeImage.getFitWindowScale(source, root.width, root.height)
        }
    }

    function fitWindow()
    {
        // 调整位置，图片恢复显示到中心
        sigSourceChange()

        // 根据图片大小进行调整，使得对较长图片能顶满看图左右两侧边框
        if (Window.FullScreen == root.visibility) {
            currentScale = 1.0
        } else {
            // 将图片调整在 root.width x enableRootHeight 的区域显示
            var enableRootHeight = (root.height - titleRect.height * 2)
            var imageRatio = fileControl.getCurrentImageHeight() / fileControl.getCurrentImageWidth()
            var rootRatio = enableRootHeight / root.width

            // 取得当前图片相对显示宽度
            var curViewImageHeight = root.width * imageRatio
            // 判断高度是否无需调整(即图片高度小于展示区域高度，则无需继续压缩显示区域)
            var useHeight = (curViewImageHeight / rootRatio) <= root.width

            currentScale = useHeight ? 1.0 : (enableRootHeight / root.height)
        }
    }

    function rotateImage(x)
    {
        // 判断是否为首次进行图片旋转
        var needResetBar = (currentRotate == 0)

        // 更新当前图片的旋转角度
        fileControl.rotateFile(source, x)
        currentRotate = fileControl.currentAngle()
        CodeImage.setReverseHeightWidth(fileControl.isReverseHeightWidth())

        // 判断图片大小是否超过了允许显示的展示区域
        if (fileControl.getFitWindowScale(root.width, root.height - titleRect.height * 2) > 1) {
            fitWindow()
        }
        else {
            fitImage()
        }

        if (needResetBar) {
            // 重设工具/菜单栏的隐藏/弹出
            mainView.animationAll()
        }
    }

    function deleteItem(item, list)
    {
        // 先遍历list里面的每一个元素，对比item与每个元素的id是否相等，再利用splice的方法删除
        for (var key in fileList) {
            if (list[key].id === item) {
                list.splice(key, 1)
            }
        }
    }

    function startSliderShow()
    {
        if (sourcePaths.length > 0) {

            normalWidth = root.width
            normalHeight = root.height

            showFullScreen()
            sliderMainShow.images = sourcePaths
            sliderMainShow.modelCount = sourcePaths.length
            sliderMainShow.autoRun = true
            sliderMainShow.indexImg = view.currentIndex
            sliderMainShow.restart()
            stackView.currentWidgetIndex = 2
        }

    }

    PropertyAnimation {
        id :showfullAnimation
        target: root
        from: 0
        to: 1
        property: "opacity"
        duration: 200
        easing.type: Easing.InExpo
    }
    Timer {
        id: showFulltimer
        interval: 200
        running: false
        repeat: false

        onTriggered: {
            root.visibility != Window.FullScreen ? showPanelFullScreen() : imageViewer.escBack()
        }
    }
    function showPanelFullScreen()
    {
        normalWidth = root.width
        normalHeight = root.height

        showFullScreen()
        view.contentItem.forceActiveFocus()
        showfullAnimation.start()

        //如果是初始界面只全屏
        if (stackView.currentWidgetIndex != 0) {
            stackView.currentWidgetIndex = 1
            currentScale = 1.0
            sigImageShowFullScreen()
        }
    }

    function escBack()
    {
        showNormal()
        showfullAnimation.start()
        //如果是初始界面只正常大小
        if (stackView.currentWidgetIndex != 0) {
            sliderMainShow.autoRun = false
            sliderMainShow.backtrack()
            if (stackView.currentWidgetIndex == 2) {
                mainView.currentIndex = sliderMainShow.indexImg
            }

            stackView.currentWidgetIndex = 1
            currentScale = 1.0 * (normalHeight - titleRect.height * 2) / normalHeight

            sigImageShowNormal()
        }
    }
    //缩放快捷键
    Shortcut {
        sequence: "Ctrl+="
        onActivated: {
            currentScale =  currentScale / 0.9
        }
    }

    Shortcut {
        sequence: "Ctrl+-"
        onActivated: {
            currentScale =  currentScale * 0.9
        }
    }

    Shortcut {
        sequence: "Up"
        onActivated: {
            currentScale =  currentScale / 0.9
        }
    }


    Shortcut {
        sequence: "Down"
        onActivated: {
            currentScale =  currentScale * 0.9
        }
    }

    /*
       @brief: 图片展示组件
            需要注意的是，此图片展示组件会被缩略图栏滑动视图和多页图滑动视图使用，
            需要区分其中变量在不同滑动视图下的含义
    */
    Component {
        id: imageShowComp
        Rectangle {
            id: flickableL
            width: view.width
            height: view.height
            clip: true
            color: backcontrol.ColorSelector.backgroundColor

            // 当前 item 使用的图片源，非当前展示图片，可能为预先加载的图片
            property var curImageSource
            // 用于标识当前图片是否为空
            property bool curSourceIsNullImage: CodeImage.imageIsNull(curImageSource)
            // 用于标识当前图片是否为普通静态图片
            property bool curSourceIsNormalStaticImage: fileControl.isNormalStaticImage(curImageSource)
            // 用于标识当前图片是否为多页图
            property bool curSourceIsMultiImage: fileControl.isMultiImage(curImageSource)
            // 用于标识当前图片是否为Svg图片
            property bool curSourceIsSvgImage: fileControl.isSvgImage(curImageSource)
            // 用于标识当前图片是否为动图
            property bool curSourceIsDynamicImage: fileControl.isDynamicImage(curImageSource)

            // 用于标识在上层 swipeView 的索引项，普通图片为缩略图栏索引，多页图为图片帧索引
            property int swipeItemIndex

            // 统一使用的缩放比例
            property double imageScale: {
                // 非当前图片调整
                if ((!curSourceIsMultiImage && swipeItemIndex != view.currentIndex)
                        || (curSourceIsMultiImage && swipeItemIndex !== imageViewer.frameIndex)) {
                    if (root.visibility == Window.FullScreen) {
                        return 1.0
                    } else {
                        return 1.0 * (root.height - titleRect.height * 2) / root.height
                    }
                }

                return currentScale
            }

            // 图片保存完成，预览区域重新加载当前图片
            Connections {
                target: fileControl
                onCallSavePicDone: {
                    // 多页图无保存处理
                    if (!flickableL.curSourceIsMultiImage && view.currentIndex == swipeItemIndex) {
                        // 重新加载图片
                        showImg.source = ""
                        showImg.source = flickableL.curImageSource
                    }
                }
            }

            // normal image
            Image {
                id: showImg
                fillMode: Image.PreserveAspectFit
                width: parent.width
                height: parent.height
                source: {
                    // 优先判断多页图，多页图使用单独的图像加载，需指定加载的图像帧号
                    if (flickableL.curSourceIsMultiImage) {
                        return "image://multiimage/" + flickableL.curImageSource + "#frame_" + swipeItemIndex
                    } else if (flickableL.curSourceIsNormalStaticImage) {
                        return "image://viewImage/" + flickableL.curImageSource
                    }
                    return ""
                }

                // NormalStaticImage 包含普通图片和多页图类型
                visible: flickableL.curSourceIsNormalStaticImage && !flickableL.curSourceIsNullImage
                asynchronous: true

                cache: false
                clip: true
                scale: imageScale
                mipmap: true
                smooth: true
                // 仅限普通图片进行旋转
                rotation: currentRotate

                onStatusChanged: {
                    msArea.changeRectXY()

                    if (Image.Ready === showImg.status) {
                        onImageReady()
                    }
                }
            }

            // svg image
            Image {
                id: showSvgImg

                fillMode: Image.PreserveAspectFit
                width: parent.width
                height: parent.height
                source: flickableL.curSourceIsSvgImage ? flickableL.curImageSource : ""
                visible: flickableL.curSourceIsSvgImage && !flickableL.curSourceIsNullImage
                asynchronous: true
                sourceSize: Qt.size(width,height)
                cache: false
                clip: true
                scale: imageScale
                smooth: true
                mipmap: true

                onStatusChanged: {
                    msArea.changeRectXY()

                    if (Image.Ready === showSvgImg.status) {
                        onImageReady()
                    }
                }
            }

            // dynamic image
            AnimatedImage {
                id: showAnimatedImg

                fillMode: Image.PreserveAspectFit
                width: parent.width
                height: parent.height
                source: flickableL.curSourceIsDynamicImage ? flickableL.curImageSource : ""
                visible: flickableL.curSourceIsDynamicImage && !flickableL.curSourceIsNullImage
                asynchronous: true
                cache: false
                clip: true
                scale: imageScale
                smooth: true

                onStatusChanged: {
                    msArea.changeRectXY()

                    if (Image.Ready === showAnimatedImg.status) {
                        onImageReady()
                    }
                }
            }

            ActionButton {
                id: damageIcon
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                icon {
                    name: "photo_breach"
                    width: 151
                    height: 151
                }

                // 判断展示图片状态是否异常
                visible: showImg.status === Image.Error || curSourceIsNullImage
            }

            BusyIndicator {
                running: true
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width:48
                height:48
                visible: showImg.status === Image.Loading && !curSourceIsNullImage
            }

            Connections {
                target: root
                onSigTitlePress: {
                    infomationDig.hide()
                    msArea.forceActiveFocus()
                }
            }

            PinchArea {
                enabled: isMousePinchArea
                anchors.fill: showAnimatedImg.visible ? showAnimatedImg : showImg.visible ?  showImg : showSvgImg

                // 记录旧的缩放大小，防止拖拽时未保留当前
                property double oldScale: 0
                property double oldRotate: 0
                property bool isRotatable: false

                onPinchStarted: {
                    // 缩放和旋转都至少需要2指操作
                    if (pinch.pointCount !== 2) {
                        pinch.accepted = false
                        return
                    }

                    oldScale = imageViewer.currentScale
                    oldRotate = imageViewer.currentRotate
                    // 不绑定信号，无需每次计算，仅当处理时获取
                    isRotatable = fileControl.isRotatable(imageViewer.source)
                    pinch.accepted = true
                }

                onPinchUpdated: {
                    // 不设置边界，通过 onCurrentScaleChanged 处理限制缩放范围在 2% ~ 2000%
                    currentScale = pinch.scale * oldScale
                    if (isRotatable) {
                        imageViewer.currentRotate = pinch.rotation + oldRotate
                    }
                }

                onPinchFinished: {
                    currentScale = pinch.scale * oldScale

                    // 判断当前图片是否允许旋转
                    if (isRotatable) {
                        // 计算旋转角度，限制在旋转梯度为90度，以45度为分界点
                        if (Math.abs(pinch.rotation) > 45) {
                            // 区分正反旋转方向
                            var isClockWise = pinch.rotation > 0
                            // 计算绝对角度值
                            var rotateAngle = Math.floor((Math.abs(pinch.rotation) + 45) / 90) * 90;
                            fileControl.rotateFile(imageViewer.source, isClockWise ? rotateAngle : -rotateAngle)
                            fileControl.slotRotatePixCurrent()
                        } else {
                            imageViewer.currentRotate = oldRotate
                        }
                    }
                }

                MultiPointTouchArea {
                    anchors.fill: parent
                    minimumTouchPoints: 1
                    maximumTouchPoints: 3
                }
            }

            MouseArea {
                id: msArea
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                drag.target: showAnimatedImg.visible ? showAnimatedImg : showImg.visible ?  showImg : showSvgImg
                enabled : isMousePinchArea
                function setImgPostions(x, y) {
                    currentimgX = msArea.drag.maximumX - x * (msArea.drag.maximumX - msArea.drag.minimumX)
                    currentimgY = msArea.drag.maximumY - y * (msArea.drag.maximumY - msArea.drag.minimumY)
                    if (showAnimatedImg.visible) {
                        showAnimatedImg.x = currentimgX
                        showAnimatedImg.y = currentimgY
                    } else if(showImg.visible) {
                        showImg.x = currentimgX
                        showImg.y = currentimgY
                    } else if(showSvgImg.visible) {
                        showSvgImg.x = currentimgX
                        showSvgImg.y = currentimgY
                    }
                }

                Connections {
                    target: idNavWidget
                    onChangeShowImgPostions: {
                        msArea.setImgPostions(x, y)
                    }
                }

                property int realWidth : 0
                property int realHeight : 0
                function changeRectXY() {
                    // 此缩放比率只在当前显示图片使用，对于多页图，CodeImage已缓存对应的帧号
                    readWidthHeightRatio = CodeImage.getrealWidthHeightRatio(flickableL.curImageSource)
                    realWidth = 0;
                    realHeight = 0;
                    if (currentScale <= 1.0) {
                        drag.minimumX = 0
                        drag.minimumY = 0
                        drag.maximumX = 0
                        drag.maximumY = 0
                        showAnimatedImg.x = 0;
                        showAnimatedImg.y = 0;
                        showImg.x = 0;
                        showImg.y = 0;
                        showSvgImg.x = 0;
                        showSvgImg.y = 0;
                    } else {
                        if (root.width > root.height * readWidthHeightRatio){
                            realWidth = root.height * readWidthHeightRatio
                        }else{
                            realWidth = root.width
                        }
                        if(root.height > root.width / readWidthHeightRatio){
                            realHeight = root.width / readWidthHeightRatio
                        }else{
                            realHeight = root.height
                        }

                        drag.minimumX = - realWidth * (currentScale-1)/2
                        drag.maximumX =  realWidth * (currentScale-1)/2
                        drag.minimumY = - realHeight * (currentScale-1)/2
                        drag.maximumY =  realHeight * (currentScale-1)/2
                        if (realHeight * currentScale >root.height) {
                            drag.maximumY = ( realHeight * currentScale - root.height )/2
                            drag.minimumY = - drag.maximumY
                        } else {
                            drag.maximumY = 0
                            drag.minimumY = 0
                        }

                        if (realWidth * currentScale > root.width) {
                            drag.maximumX = ( realWidth * currentScale - root.width )/2
                            drag.minimumX = - drag.maximumX
                        } else {
                            drag.maximumX = 0
                            drag.minimumX = 0
                        }

                        // 计算显示的 显示窗口 / 图片像素 的比值
                        viewImageWidthRatio = root.width / (realWidth * currentScale)
                        viewImageHeightRatio = root.height / (realHeight * currentScale)
                    }

                    if (showAnimatedImg.x >= drag.maximumX) {
                        showAnimatedImg.x = drag.maximumX
                    }
                    if (showAnimatedImg.x <= drag.minimumX) {
                        showAnimatedImg.x = drag.minimumX
                    }
                    if (showAnimatedImg.y >= drag.maximumY) {
                        showAnimatedImg.y = drag.maximumY
                    }
                    if (showAnimatedImg.y <= drag.minimumY) {
                        showAnimatedImg.y = drag.minimumY
                    }

                    if (showImg.x >= drag.maximumX) {
                        showImg.x = drag.maximumX
                    }
                    if (showImg.x <= drag.minimumX) {
                        showImg.x = drag.minimumX
                    }
                    if (showImg.y >= drag.maximumY) {
                        showImg.y = drag.maximumY
                    }
                    if (showImg.y <= drag.minimumY) {
                        showImg.y = drag.minimumY
                    }

                    if (showSvgImg.x >= drag.maximumX) {
                        showSvgImg.x = drag.maximumX
                    }
                    if (showSvgImg.x <= drag.minimumX) {
                        showSvgImg.x = drag.minimumX
                    }
                    if (showSvgImg.y >= drag.maximumY) {
                        showSvgImg.y = drag.maximumY
                    }
                    if (showSvgImg.y <= drag.minimumY) {
                        showSvgImg.y = drag.minimumY
                    }
                }

                Connections {
                    target: imageViewer
                    onSigSourceChange : {
                        //图元位置归位
                        showImg.x = 0
                        showImg.y = 0
                        showAnimatedImg.x = 0
                        showAnimatedImg.y = 0
                        showSvgImg.x = 0
                        showSvgImg.y = 0
                    }
                }

                onPressed: {
                    infomationDig.hide()
                    if (mouse.button === Qt.RightButton) {
                        option_menu.popup()
                    }
                }

                onMouseXChanged: {
                    changeRectXY()
                    if (showAnimatedImg.visible)
                    {
                        currentimgX = showAnimatedImg.x
                    } else
                    {
                        currentimgX = showImg.x
                    }
                    //以整个图片中心为平面原点，currentimgX，currentimgY为当前视口右下角相对于整个图片的坐标，以此计算导航窗口蒙皮和位置
                    //计算相对位置
                    m_NavX = (drag.maximumX - currentimgX) / (drag.maximumX - drag.minimumX)
                    m_NavY = (drag.maximumY - currentimgY) / (drag.maximumY - drag.minimumY)

                    idNavWidget.setRectLocation(m_NavX, m_NavY)
                }

                onMouseYChanged: {
                    changeRectXY()
                    if (showAnimatedImg.visible)
                    {
                        currentimgY = showAnimatedImg.y
                    } else
                    {
                        currentimgY = showImg.y
                    }
                    m_NavX = (drag.maximumX - currentimgX) / (drag.maximumX - drag.minimumX)
                    m_NavY = (drag.maximumY - currentimgY) / (drag.maximumY - drag.minimumY)

                    idNavWidget.setRectLocation(m_NavX, m_NavY)
                }

                onDoubleClicked: {
                    if (!thumbnailListView.contains(msArea.mapToItem(thumbnailListView, mouse.x, mouse.y))) {
                        infomationDig.hide()
                        showFulltimer.start()
                    }
                }

                onWheel: {
                    var datla = wheel.angleDelta.y / 120
                    // 通过Keys缓存的状态可能不准确，在焦点移出时release事件没有正确捕获，
                    // 修改为通过当前事件传入的按键按下信息判断
                    if (Qt.ControlModifier & wheel.modifiers)
                        datla > 0 ? thumbnailListView.previous() : thumbnailListView.next()
                    else {
                        // 缓存当前的坐标信息
                        var targetItem = drag.target
                        var mapPoint = mapToItem(drag.target, wheel.x, wheel.y)

                        if (datla > 0)
                            currentScale = currentScale / 0.9
                        else
                            currentScale = currentScale * 0.9

                        if (currentScale * 100 < 100)
                        {
                            idNavWidget.visible = false
                        } else if (isNavShow)
                        {
                            if(root.height<=global.minHideHeight || root.width<=global.minWidth){
                                idNavWidget.visible=false
                            }else{
                                idNavWidget.visible=true
                            }
                        }

                        // 缩放后，调整图片坐标
                        var restorePoint = mapFromItem(targetItem, mapPoint.x, mapPoint.y)
                        targetItem.x -= restorePoint.x - wheel.x;
                        targetItem.y -= restorePoint.y - wheel.y;

                        // 调整导航窗口蒙版位置
                        currentimgX = targetItem.x
                        currentimgY = targetItem.y
                        m_NavX = (drag.maximumX - currentimgX) / (drag.maximumX - drag.minimumX)
                        m_NavY = (drag.maximumY - currentimgY) / (drag.maximumY - drag.minimumY)
                        idNavWidget.setRectLocation(m_NavX, m_NavY)

                        // 坐标变更边界调整计算，图片小于窗口时坐标居中
                        changeRectXY()

                        sigWheelChange()

                        /*
                        缩放计算规则：val对应的是showImg.width和showImg.height
                        缩小：(即showImg.scale < 1)
                            min:初始值+val*(1-showImg.scale) / 2
                            max:初始值-val*(1-showImg.scale) / 2
                        放大：(即showImg.scale > 1)
                            min:初始值-val*(showImg.scale-1) / 2
                            max:初始值+val*(showImg.scale-1) / 2
                        */
                    }
                }
            }
        }
    }

    // 多页图滑动视图组件，用于进行*.tif等多页图的滑动展示，嵌入最外层滑动视图展示
    Component {
        id: mulitImageSwipeViewComp
        SwipeView {
            id: multiImageSwipeView
            height: view.width
            width: view.height
            clip: true
            // 当处理双击缩放界面时，由于坐标变更，可能误触导致图片滑动
            // 调整为在缩放动作时不处理滑动操作
            interactive: !imageViewer.isFullNormalSwitchState

            // 设置当前加载多页图滑动视图在完整图片滑动视图的索引(非当前全局索引，可能需要预加载)
            property int imageIndex
            property var multiImageSource: imageViewer.sourcePaths[imageIndex]

            Repeater {
                model: fileControl.getImageCount(multiImageSource)
                Loader {
                    active: SwipeView.isCurrentItem || SwipeView.isNextItem || SwipeView.isPreviousItem
                    sourceComponent: imageShowComp

                    onLoaded: {
                        // 使用 loader加载，手动设置图片视图的源图片路径
                        item.curImageSource = multiImageSource
                        item.swipeItemIndex = index
                    }
                }
            }

            // 存在绑定依赖，使用信号连接
            Connections {
                target: imageViewer
                onFrameIndexChanged: {
                    if (multiImageSwipeView.imageIndex == view.currentIndex) {
                        multiImageSwipeView.currentIndex = imageViewer.frameIndex
                    }
                }
            }

            Connections {
                target: view
                onCurrentIndexChanged: {
                    // 需要根据当前顶层滑动窗口的索引进行计算
                    // 处于当前显示图片前一位的多页图，调整帧号为尾帧
                    if (multiImageSwipeView.imageIndex == view.currentIndex - 1) {
                        multiImageSwipeView.currentIndex = multiImageSwipeView.count - 1
                    }
                    // 处于当前显示图片后一位的多页图，调整帧号为首帧
                    if (multiImageSwipeView.imageIndex == view.currentIndex + 1) {
                        multiImageSwipeView.currentIndex = 0
                    }
                }
            }

            onCurrentIndexChanged: {
                // 判断当前展示的是否为此多页图
                if (multiImageSwipeView.imageIndex == view.currentIndex) {
                    // 更新当前的多页图帧号(注意循环引用问题)
                    imageViewer.frameIndex = multiImageSwipeView.currentIndex
                }
            }

            // 初始打开和点击缩略图切换都不会再有滑动效果
            Component.onCompleted: {
                contentItem.highlightMoveDuration = 0       // 将移动时间设为0
            }
        }
    }

    // 图片滑动视图
    SwipeView {
        id: view
        currentIndex: sourcePaths.indexOf(source)
        width: parent.width
        height: parent.height
        clip: true
        // 当处理双击缩放界面时，由于坐标变更，可能误触导致图片滑动
        // 调整为在缩放动作时不处理滑动操作
        interactive: !imageViewer.isFullNormalSwitchState

        // 初始打开和点击缩略图切换都不会再有滑动效果
        Component.onCompleted: {
            contentItem.highlightMoveDuration = 0       // 将移动时间设为0
        }

        Repeater {
            model: sourcePaths.length
            Loader {
                active: SwipeView.isCurrentItem || SwipeView.isNextItem
                        || SwipeView.isPreviousItem
                // 非当前 ImageViewer 使用的标识，而是当前滑动视图 item 对应图片的信息
                property var curItemIsMultiImage: fileControl.isMultiImage(imageViewer.sourcePaths[index])

                // 根据列表索引判断是否为多页图
                sourceComponent: curItemIsMultiImage ? mulitImageSwipeViewComp : imageShowComp

                onLoaded: {
                    if (curItemIsMultiImage) {
                        item.imageIndex = index
                        // 若为前后的组件且此图片组件为多页图，修改索引
                        if (SwipeView.isPreviousItem) {
                            item.currentIndex = item.count - 1
                        }
                        if (SwipeView.isNextItem) {
                            item.currentIndex = 0
                        }
                    } else {
                        // 非多页图，使用 loader 加载，设置 imageShowComp 组件的源图片路径
                        item.swipeItemIndex = index
                        item.curImageSource = imageViewer.sourcePaths[index]
                    }
                }
            }
        }

        onCurrentIndexChanged: {
            // 当通过界面拖拽导致索引变更，需要调整多页图索引范围
            imageViewer.index = view.currentIndex
            imageViewer.currentRotate = 0

            CodeImage.setReverseHeightWidth(false)
        }
    }

    //rename窗口
    ReName {
        id: renamedialog
    }
    //info的窗口
    InfomationDialog {

        id: infomationDig

    }



    //导航窗口
    NavigationWidget {
        id : idNavWidget
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 109
        anchors.left: parent.left
        anchors.leftMargin: 15
        visible: false
    }

    onHeightChanged: {
        if(root.height<=global.minHideHeight ){
            idNavWidget.visible=false
        }
    }

    onWidthChanged: {
        if( root.width<=global.minWidth){
            idNavWidget.visible=false
        }
    }

    // 导航窗口显示配置变更时触发
    onIsNavShowChanged: {
        // 保存设置信息
        fileControl.setEnableNavigation(isNavShow)
    }
}

