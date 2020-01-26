/****************************************************************************
**
** Copyright (C) 2017-2020 Elros https://github.com/elros34
**               2020 Rinigus https://github.com/rinigus
**               2012 Digia Plc and/or its subsidiary(-ies).
**
** This file is part of Flatpak Runner.
**
** You may use this file under the terms of the BSD license as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of the copyright holder nor the names of its
**     contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
**
****************************************************************************/

import QtQuick 2.0
import Sailfish.Silica 1.0
import "."

Page {
    id: root
    objectName: "mainPage"

    property int  nwindows: 0
    property bool settingsInitDone: false

    BusyIndicator {
        id: busyInd
        anchors.centerIn: root
        running: false
        size: BusyIndicatorSize.Large
    }

    LabelC {
        id: busyInfoMessage
        anchors.top: busyInd.bottom
        anchors.topMargin: Theme.paddingLarge
        horizontalAlignment: Text.AlignHCenter
        visible: busyInd.running
    }

    // Settings: List of applications
    SilicaListView {
        id: alist
        anchors.fill: parent
        header: PageHeader {
            title: qsTr("Flatpak Runner")
        }

        delegate: ListItem {
            contentHeight: Math.max(icon.height,
                                    name.height + fpk.height + fpk.anchors.topMargin) + Theme.paddingLarge
            width: alist.width

            Image {
                id: icon
                anchors.left: parent.left
                anchors.leftMargin: Theme.horizontalPageMargin
                anchors.top: parent.top
                anchors.topMargin: Theme.paddingLarge/2
                source: model.icon
                sourceSize.width: Theme.itemSizeLarge
            }

            Label {
                id: name
                anchors.left: icon.right
                anchors.leftMargin: Theme.paddingLarge
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.top: parent.top
                anchors.topMargin: Theme.paddingLarge/2
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeLarge
                text: model.name
                wrapMode: Text.WordWrap
            }

            Label {
                id: fpk
                anchors.left: icon.right
                anchors.leftMargin: Theme.paddingLarge
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.top: name.bottom
                anchors.topMargin: Theme.paddingSmall
                color: Theme.primaryColor
                font.pixelSize: Theme.fontSizeSmall
                text: model.flatpak !== settings.defaultApp() ? model.flatpak : ""
            }

            onClicked: pageStack.push(Qt.resolvedUrl("AppSettingsPage.qml"),
                                      {
                                        "flatpak": model.flatpak,
                                        "name": model.name
                                      })
        }

        model: ListModel {}
        visible: settingsInitDone && modeSettings && nwindows <= 0

        PullDownMenu {
            MenuItem {
                text: qsTr("About")
                onClicked: pageStack.push(Qt.resolvedUrl("AboutPage.qml"))
            }
        }

        VerticalScrollDecorator { flickable: alist }

        Connections {
            target: settings
            onAppListChanged: {
                alist.model.clear();
                alist.model.append({
                                       'flatpak': settings.defaultApp(),
                                       'name': qsTr('Default settings'),
                                       'icon': Qt.resolvedUrl("../icons/flatpak-runner.svg")
                                   });
                var apps = settings.apps();
                apps.forEach(function (item, index) {
                    alist.model.append({
                                           'flatpak': item,
                                           'name': settings.appName(item),
                                           'icon': settings.appIcon(item)
                                       })
                });

            }
        }
    }

    // Start and end notification
    Label {
        id: hintLabel
        anchors.centerIn: parent
        font.pixelSize: Theme.fontSizeLarge
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: {
            if (runner.program && hintLabel.status)
                return qsTr("Flatpak: %1\n%2").arg(runner.program).arg(hintLabel.status);
            if (runner.program)
                return qsTr("Flatpak: %1").arg(runner.program);
            return qsTr("Flatpak Runner");
        }
        visible: nwindows <= 0 && !modeSettings
        width: root.width - 2*Theme.horizontalPageMargin
        wrapMode: Text.WordWrap

        property string status
        Connections {
            target: runner
            onExit: hintLabel.status = qsTr("Application finished")
        }
    }

    // Initialize in Settings mode
    function initSettings() {
        busyInd.running = true;
        if (app.py.call_sync("fpk.has_extension"))
            initSettingsApps();
        else
            initSettingsExtension();
    }

    function initSettingsApps() {
        busyInfoMessage.text = qsTr("Update list of applications");
        app.py.call("fpk.refresh_apps", [], function(result) {
            busyInd.running = false;
            settings.updateApps(JSON.stringify(result));
            root.settingsInitDone = true;
        });
    }

    function initSettingsExtension() {
        busyInfoMessage.text = qsTr("Initialize or update GL extension");
        app.py.call("fpk.sync_extension", [], function() {
            initSettingsApps()
        });
    }

    // Handling of contained application
    function windowAdded(window) {
        var windowContainerComponent = Qt.createComponent("WindowContainer.qml");
        if (windowContainerComponent.status !== Component.Ready) {
            console.warn("Error loading WindowContainer.qml: " +  windowContainerComponent.errorString());
            return;
        }

        var windowContainer = windowContainerComponent.createObject(root, {
                                                                        "child": compositor.item(window)
                                                                    });
        windowContainer.objectName = "windowContainer"
        windowContainer.child.resizeSurfaceToItem = true
        windowContainer.child.parent = windowContainer;
        windowContainer.child.anchors.fill = windowContainer;
        windowContainer.child.touchEventsEnabled = true;

        nwindows += 1

        windowContainer.child.takeFocus()
    }

    function windowResized(window) {
        window.width = window.surface.size.width;
        window.height = window.surface.size.height;
    }

    function removeWindow(window) {
        window.destroy();
        nwindows -= 1
    }
}

