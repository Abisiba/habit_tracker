import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PC3

PlasmoidItem {
    id: root

    compactRepresentation: Rectangle {
        color: "transparent"
        Layout.fillWidth: true
        Layout.fillHeight: true

        Text {
            anchors.centerIn: parent
            text: todayStar ? "⭐" : todayScore
            color: todayStar ? "#f1fa8c" : "#50fa7b"
            font.bold: true
            font.pointSize: 10
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    fullRepresentation: Rectangle {
        width: 300
        height: Math.min(mainColumn.implicitHeight + 28, 540)
        color: Qt.rgba(0.06, 0.06, 0.1, 0.92)
        radius: 16
        border.color: Qt.rgba(1, 1, 1, 0.12)
        border.width: 1

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: Qt.formatDate(new Date(), "dd MMM")
                    color: Qt.rgba(1, 1, 1, 0.45)
                    font.pointSize: 9
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 8
                    height: 8
                    radius: 4
                    visible: root.supabaseConfigured
                    color: root.syncStatus === "syncing" ? "#f1fa8c"
                         : root.syncStatus === "error" ? "#ff5555"
                         : "#50fa7b"
                }

                Text {
                    text: todayStar ? "⭐" : todayScore + "/100"
                    color: todayStar ? "#f1fa8c" : "#50fa7b"
                    font.bold: true
                    font.pointSize: todayStar ? 18 : 12
                }
            }

            Canvas {
                id: chartCanvas
                Layout.fillWidth: true
                height: 60
                property var points: root.chartPoints
                onPointsChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d");
                    ctx.clearRect(0, 0, width, height);
                    if (!points || points.length < 2) return;

                    var pad = 4;
                    var w = width - pad * 2;
                    var h = height - pad * 2;
                    var grad = ctx.createLinearGradient(0, 0, 0, height);
                    grad.addColorStop(0, "rgba(80, 250, 123, 0.2)");
                    grad.addColorStop(1, "rgba(80, 250, 123, 0.0)");

                    ctx.beginPath();
                    ctx.moveTo(pad, height - pad);
                    for (var i = 0; i < points.length; i++) {
                        var x = pad + (i / (points.length - 1)) * w;
                        var y = height - pad - (Math.min(points[i], 100) / 100) * h;
                        if (i === 0) {
                            ctx.lineTo(x, y);
                        } else {
                            var px = pad + ((i - 1) / (points.length - 1)) * w;
                            var py = height - pad - (Math.min(points[i - 1], 100) / 100) * h;
                            var cpx = px + (x - px) / 2;
                            ctx.bezierCurveTo(cpx, py, cpx, y, x, y);
                        }
                    }
                    ctx.lineTo(width - pad, height - pad);
                    ctx.closePath();
                    ctx.fillStyle = grad;
                    ctx.fill();

                    ctx.beginPath();
                    for (var j = 0; j < points.length; j++) {
                        var lx = pad + (j / (points.length - 1)) * w;
                        var ly = height - pad - (Math.min(points[j], 100) / 100) * h;
                        if (j === 0) {
                            ctx.moveTo(lx, ly);
                        } else {
                            var lpx = pad + ((j - 1) / (points.length - 1)) * w;
                            var lpy = height - pad - (Math.min(points[j - 1], 100) / 100) * h;
                            var lcpx = lpx + (lx - lpx) / 2;
                            ctx.bezierCurveTo(lcpx, lpy, lcpx, ly, lx, ly);
                        }
                    }
                    ctx.strokeStyle = "#50fa7b";
                    ctx.lineWidth = 1.5;
                    ctx.stroke();

                    for (var k = 0; k < points.length; k++) {
                        var dx = pad + (k / (points.length - 1)) * w;
                        var dy = height - pad - (Math.min(points[k], 100) / 100) * h;
                        ctx.beginPath();
                        ctx.arc(dx, dy, 2.5, 0, 2 * Math.PI);
                        ctx.fillStyle = k === points.length - 1 ? "#50fa7b" : Qt.rgba(1, 1, 1, 0.5);
                        ctx.fill();
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 260
                color: "transparent"
                border.color: Qt.rgba(1, 1, 1, 0.03)
                border.width: 1
                radius: 8

                ListView {
                    id: habitsList
                    anchors.fill: parent
                    anchors.margins: 4
                    model: habitsModel
                    spacing: 5
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        width: 4
                        contentItem: Rectangle {
                            implicitWidth: 4
                            radius: 2
                            color: Qt.rgba(1, 1, 1, 0.3)
                        }
                    }

                    delegate: Rectangle {
                        width: ListView.view.width - 8
                        height: 36
                        color: model.isExtra ? Qt.rgba(241, 250, 140, 0.06) : Qt.rgba(255, 255, 255, 0.02)
                        radius: 8
                        border.color: model.isExtra ? Qt.rgba(241, 250, 140, 0.12) : Qt.rgba(255, 255, 255, 0.04)
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            spacing: 8

                            Rectangle {
                                visible: !root.editMode
                                width: 16
                                height: 16
                                radius: 4
                                color: model.completed ? "#50fa7b" : "transparent"
                                border.color: model.completed ? "#50fa7b" : Qt.rgba(1, 1, 1, 0.25)
                                border.width: 1

                                Text {
                                    visible: model.completed
                                    anchors.centerIn: parent
                                    text: "✓"
                                    color: "#000"
                                    font.pointSize: 7
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.toggleHabit(model.index)
                                }
                            }

                            TextField {
                                visible: root.editMode
                                text: model.name
                                Layout.fillWidth: true
                                color: "#f8f8f2"
                                font.pointSize: 9
                                background: Rectangle {
                                    radius: 4
                                    color: Qt.rgba(255, 255, 255, 0.05)
                                    border.color: Qt.rgba(255, 255, 255, 0.08)
                                }
                                onEditingFinished: root.updateHabitName(model.index, text)
                            }

                            Text {
                                visible: !root.editMode
                                text: model.name
                                color: model.completed ? Qt.rgba(1, 1, 1, 0.35) : "#f8f8f2"
                                font.pointSize: 9
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                                font.strikeout: model.completed
                            }

                            TextField {
                                visible: root.editMode && !model.isExtra
                                text: model.points
                                Layout.preferredWidth: 36
                                color: "#f8f8f2"
                                font.pointSize: 9
                                horizontalAlignment: Text.AlignHCenter
                                background: Rectangle {
                                    radius: 4
                                    color: Qt.rgba(255, 255, 255, 0.05)
                                    border.color: Qt.rgba(255, 255, 255, 0.08)
                                }
                                onEditingFinished: {
                                    var val = parseInt(text) || 1;
                                    if (val > 100) val = 100;
                                    if (val < 1) val = 1;
                                    root.updateHabitPoints(model.index, val);
                                }
                            }

                            Text {
                                visible: !root.editMode && !model.isExtra
                                text: model.points
                                color: Qt.rgba(1, 1, 1, 0.35)
                                font.pointSize: 8
                                Layout.preferredWidth: 24
                                horizontalAlignment: Text.AlignRight
                            }

                            Text {
                                visible: !root.editMode && model.isExtra
                                text: "★"
                                color: "#f1fa8c"
                                font.pointSize: 10
                                Layout.preferredWidth: 24
                                horizontalAlignment: Text.AlignRight
                            }

                            PC3.Button {
                                visible: root.editMode
                                icon.name: "edit-delete"
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                onClicked: root.deleteHabit(model.index)
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                PC3.Button {
                    text: root.editMode ? "Done" : "Edit"
                    icon.name: root.editMode ? "dialog-ok" : "document-edit"
                    onClicked: root.editMode = !root.editMode
                }

                PC3.Button {
                    text: "+"
                    visible: root.editMode
                    icon.name: "list-add"
                    onClicked: addDialog.open()
                }

                Item { Layout.fillWidth: true }

                PC3.Button {
                    visible: root.supabaseConfigured
                    icon.name: "view-refresh"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    onClicked: root.syncFromSupabase()
                }

                PC3.Button {
                    icon.name: "configure"
                    Layout.preferredWidth: 28
                    Layout.preferredHeight: 28
                    onClicked: {
                        supabaseUrlField.text = Plasmoid.configuration.supabaseUrl;
                        supabaseKeyField.text = Plasmoid.configuration.supabaseAnonKey;
                        supabaseDialog.open();
                    }
                }
            }
        }

        Dialog {
            id: addDialog
            title: "Add Habit"
            standardButtons: Dialog.Ok | Dialog.Cancel
            modal: true
            anchors.centerIn: parent
            width: 240

            ColumnLayout {
                spacing: 8

                TextField {
                    id: newName
                    placeholderText: "Habit name"
                    Layout.fillWidth: true
                    color: "#f8f8f2"
                    background: Rectangle {
                        radius: 4
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                    }
                }

                TextField {
                    id: newPoints
                    text: "20"
                    Layout.preferredWidth: 50
                    color: "#f8f8f2"
                    horizontalAlignment: Text.AlignHCenter
                    background: Rectangle {
                        radius: 4
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                    }
                }

                CheckBox {
                    id: newExtra
                    text: "Extra star"
                    indicator: Rectangle {
                        implicitWidth: 14
                        implicitHeight: 14
                        radius: 3
                        color: parent.checked ? "#f1fa8c" : "transparent"
                        border.color: parent.checked ? "#f1fa8c" : Qt.rgba(1, 1, 1, 0.2)
                    }
                }
            }

            onAccepted: {
                if (newName.text.trim() !== "") {
                    var val = parseInt(newPoints.text) || 20;
                    root.addHabit(newName.text.trim(), val, newExtra.checked);
                    newName.text = "";
                    newPoints.text = "20";
                    newExtra.checked = false;
                }
            }
        }

        Dialog {
            id: supabaseDialog
            title: "Supabase Sync Ayarları"
            standardButtons: Dialog.Ok | Dialog.Cancel
            modal: true
            anchors.centerIn: parent
            width: 270

            ColumnLayout {
                spacing: 6
                width: parent.width

                Text {
                    text: "Project URL:"
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pointSize: 8
                }

                TextField {
                    id: supabaseUrlField
                    placeholderText: "https://proje.supabase.co"
                    Layout.fillWidth: true
                    color: "#f8f8f2"
                    font.pointSize: 8
                    background: Rectangle {
                        radius: 4
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                    }
                }

                Text {
                    text: "Anon/Public Key:"
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pointSize: 8
                }

                TextField {
                    id: supabaseKeyField
                    placeholderText: "eyJ..."
                    Layout.fillWidth: true
                    color: "#f8f8f2"
                    font.pointSize: 8
                    echoMode: TextInput.Password
                    background: Rectangle {
                        radius: 4
                        color: Qt.rgba(255, 255, 255, 0.05)
                        border.color: Qt.rgba(255, 255, 255, 0.08)
                    }
                }

                Text {
                    text: "Supabase → Settings → API\nTablo: public.habittracker_state"
                    color: Qt.rgba(1, 1, 1, 0.4)
                    font.pointSize: 7
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            onAccepted: {
                Plasmoid.configuration.supabaseUrl = root.normalizeSupabaseUrl(supabaseUrlField.text.trim());
                Plasmoid.configuration.supabaseAnonKey = supabaseKeyField.text.trim();
                if (root.supabaseConfigured) root.syncFromSupabase();
            }
        }
    }

    property bool editMode: false
    property int todayScore: 0
    property bool todayStar: false
    property var chartPoints: []
    property string _currentDate: ""
    property string lastLocalModifiedCache: Plasmoid.configuration.lastModified || ""
    property string syncStatus: "idle"
    property bool supabaseConfigured: Plasmoid.configuration.supabaseUrl !== "" && Plasmoid.configuration.supabaseAnonKey !== ""

    ListModel { id: habitsModel }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: {
            var today = root.getTodayStr();
            if (root._currentDate !== "" && root._currentDate !== today) {
                root.saveCurrentDayData(root._currentDate);
                root._currentDate = today;
                root.resetForNewDay();
            }
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.saveData(false)
    }

    Timer {
        interval: 300000
        repeat: true
        running: root.supabaseConfigured
        onTriggered: root.syncFromSupabase()
    }

    Component.onCompleted: {
        _currentDate = getTodayStr();
        loadData();
        if (supabaseConfigured) Qt.callLater(syncFromSupabase);
    }

    Component.onDestruction: saveData(false)

    function getTodayStr() {
        return Qt.formatDate(new Date(), "yyyy-MM-dd");
    }

    function getHabitsDefault() {
        return [
            {"id": 1, "name": "Drink Water", "points": 20, "isExtra": 0},
            {"id": 2, "name": "Walk 5k", "points": 20, "isExtra": 0},
            {"id": 3, "name": "Push-ups", "points": 20, "isExtra": 0},
            {"id": 4, "name": "Read", "points": 20, "isExtra": 0},
            {"id": 5, "name": "Meditate", "points": 20, "isExtra": 0},
            {"id": 6, "name": "Extra", "points": 0, "isExtra": 1}
        ];
    }

    function loadData() {
        var raw = Plasmoid.configuration.habitsData;
        var habits = (raw && raw !== "") ? JSON.parse(raw) : getHabitsDefault();
        var todayStr = getTodayStr();
        var records = JSON.parse(Plasmoid.configuration.dailyRecords || "{}");
        var todayRecord = records[todayStr] || {};

        habitsModel.clear();
        for (var i = 0; i < habits.length; i++) {
            var h = habits[i];
            habitsModel.append({
                id: h.id,
                name: h.name,
                points: h.points,
                isExtra: h.isExtra,
                completed: todayRecord[h.id.toString()] || false
            });
        }
        calculateToday();
        buildChart();
    }

    function habitsFromModel() {
        var habits = [];
        for (var i = 0; i < habitsModel.count; i++) {
            var item = habitsModel.get(i);
            habits.push({id: item.id, name: item.name, points: item.points, isExtra: item.isExtra});
        }
        return habits;
    }

    function dailyRecordsFromModel() {
        var todayStr = getTodayStr();
        var records = JSON.parse(Plasmoid.configuration.dailyRecords || "{}");
        var todayRecord = {};
        for (var j = 0; j < habitsModel.count; j++) {
            var recordItem = habitsModel.get(j);
            if (recordItem.completed) todayRecord[recordItem.id.toString()] = true;
        }
        records[todayStr] = todayRecord;
        return records;
    }

    function scoreHistoryFromCurrentScore() {
        var todayStr = getTodayStr();
        var history = JSON.parse(Plasmoid.configuration.scoreHistory || "{}");
        history[todayStr] = todayScore;
        var keys = Object.keys(history).sort();
        if (keys.length > 30) {
            var trimmed = {};
            for (var k = keys.length - 30; k < keys.length; k++) trimmed[keys[k]] = history[keys[k]];
            history = trimmed;
        }
        return history;
    }

    function saveData(markModified) {
        var habits = habitsFromModel();
        Plasmoid.configuration.habitsData = JSON.stringify(habits);

        var records = dailyRecordsFromModel();
        Plasmoid.configuration.dailyRecords = JSON.stringify(records);

        var history = scoreHistoryFromCurrentScore();
        Plasmoid.configuration.scoreHistory = JSON.stringify(history);
        if (markModified) {
            lastLocalModifiedCache = new Date().toISOString();
            Plasmoid.configuration.lastModified = lastLocalModifiedCache;
        }
    }

    function saveCurrentDayData(dateStr) {
        var records = JSON.parse(Plasmoid.configuration.dailyRecords || "{}");
        var dayRecord = {};
        for (var i = 0; i < habitsModel.count; i++) {
            var item = habitsModel.get(i);
            if (item.completed) dayRecord[item.id.toString()] = true;
        }
        records[dateStr] = dayRecord;
        Plasmoid.configuration.dailyRecords = JSON.stringify(records);

        var history = JSON.parse(Plasmoid.configuration.scoreHistory || "{}");
        history[dateStr] = todayScore;
        Plasmoid.configuration.scoreHistory = JSON.stringify(history);
        lastLocalModifiedCache = new Date().toISOString();
        Plasmoid.configuration.lastModified = lastLocalModifiedCache;
    }

    function resetForNewDay() {
        for (var i = 0; i < habitsModel.count; i++) {
            habitsModel.setProperty(i, "completed", false);
        }
        calculateToday();
        buildChart();
    }

    function calculateToday() {
        var score = 0;
        var extraDone = false;
        for (var i = 0; i < habitsModel.count; i++) {
            var h = habitsModel.get(i);
            if (h.isExtra === 1) {
                if (h.completed) extraDone = true;
            } else if (h.completed) {
                score += h.points;
            }
        }
        todayScore = Math.min(score, 100);
        todayStar = (score >= 100 && extraDone);
    }

    function buildChart() {
        var pts = [];
        var history = JSON.parse(Plasmoid.configuration.scoreHistory || "{}");
        var today = new Date();
        for (var i = 6; i >= 0; i--) {
            var d = new Date(today);
            d.setDate(d.getDate() - i);
            var dateStr = Qt.formatDate(d, "yyyy-MM-dd");
            pts.push(i === 0 ? todayScore : (history[dateStr] || 0));
        }
        chartPoints = pts;
    }

    function normalizeSupabaseUrl(url) {
        if (!url) return "";
        while (url.length > 0 && url[url.length - 1] === "/") {
            url = url.slice(0, -1);
        }
        return url;
    }

    function supabaseReadPath() {
        return normalizeSupabaseUrl(Plasmoid.configuration.supabaseUrl)
            + "/rest/v1/habittracker_state?id=eq.default&select=data";
    }

    function supabaseWritePath() {
        return normalizeSupabaseUrl(Plasmoid.configuration.supabaseUrl)
            + "/rest/v1/habittracker_state?on_conflict=id";
    }

    function setSupabaseHeaders(xhr) {
        var key = Plasmoid.configuration.supabaseAnonKey;
        xhr.setRequestHeader("apikey", key);
        xhr.setRequestHeader("Authorization", "Bearer " + key);
        xhr.setRequestHeader("Content-Type", "application/json");
    }

    function localLastModified() {
        return lastLocalModifiedCache || Plasmoid.configuration.lastModified || "";
    }

    function isRemoteNewer(remote) {
        var local = Date.parse(localLastModified());
        var incoming = Date.parse(remote.lastModified || "");
        if (isNaN(incoming)) return false;
        if (isNaN(local)) return true;
        return incoming > local;
    }

    function syncToSupabase() {
        if (!supabaseConfigured) return;
        syncStatus = "syncing";
        var modified = localLastModified();
        if (!modified) {
            modified = new Date().toISOString();
            lastLocalModifiedCache = modified;
            Plasmoid.configuration.lastModified = modified;
        }
        var payload = {
            habits: habitsFromModel(),
            dailyRecords: dailyRecordsFromModel(),
            scoreHistory: scoreHistoryFromCurrentScore(),
            lastModified: modified
        };
        var body = {
            id: "default",
            data: payload,
            updated_at: new Date().toISOString()
        };
        var xhr = new XMLHttpRequest();
        xhr.open("POST", supabaseWritePath());
        setSupabaseHeaders(xhr);
        xhr.setRequestHeader("Prefer", "resolution=merge-duplicates,return=minimal");
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return;
            syncStatus = (xhr.status >= 200 && xhr.status < 300) ? "ok" : "error";
            console.log("HabitTracker Supabase push", xhr.status, modified);
        };
        xhr.send(JSON.stringify(body));
    }

    function syncFromSupabase() {
        if (!supabaseConfigured) return;
        syncStatus = "syncing";
        var xhr = new XMLHttpRequest();
        xhr.open("GET", supabaseReadPath());
        setSupabaseHeaders(xhr);
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return;
            if (xhr.status !== 200) {
                syncStatus = "error";
                return;
            }
            var rows = JSON.parse(xhr.responseText);
            var remote = rows && rows.length > 0 ? rows[0].data : null;
            if (!remote || !remote.habits || remote.habits.length === 0) {
                saveData(true);
                syncToSupabase();
                return;
            }

            if (isRemoteNewer(remote) || !Plasmoid.configuration.habitsData) {
                Plasmoid.configuration.habitsData = JSON.stringify(remote.habits || []);
                Plasmoid.configuration.dailyRecords = JSON.stringify(remote.dailyRecords || {});
                Plasmoid.configuration.scoreHistory = JSON.stringify(remote.scoreHistory || {});
                lastLocalModifiedCache = remote.lastModified || new Date().toISOString();
                Plasmoid.configuration.lastModified = lastLocalModifiedCache;
            } else {
                syncToSupabase();
            }

            loadData();
            syncStatus = "ok";
        };
        xhr.send();
    }

    function toggleHabit(index) {
        var item = habitsModel.get(index);
        habitsModel.setProperty(index, "completed", !item.completed);
        calculateToday();
        buildChart();
        saveData(true);
        if (supabaseConfigured) syncToSupabase();
    }

    function addHabit(name, points, isExtra) {
        var maxId = 0;
        for (var i = 0; i < habitsModel.count; i++) {
            var h = habitsModel.get(i);
            if (h.id > maxId) maxId = h.id;
        }
        habitsModel.append({id: maxId + 1, name: name, points: isExtra ? 0 : points, isExtra: isExtra ? 1 : 0, completed: false});
        saveData(true);
        if (supabaseConfigured) syncToSupabase();
    }

    function deleteHabit(index) {
        habitsModel.remove(index);
        calculateToday();
        buildChart();
        saveData(true);
        if (supabaseConfigured) syncToSupabase();
    }

    function updateHabitName(index, name) {
        habitsModel.setProperty(index, "name", name);
        saveData(true);
        if (supabaseConfigured) syncToSupabase();
    }

    function updateHabitPoints(index, points) {
        habitsModel.setProperty(index, "points", points);
        calculateToday();
        buildChart();
        saveData(true);
        if (supabaseConfigured) syncToSupabase();
    }
}
