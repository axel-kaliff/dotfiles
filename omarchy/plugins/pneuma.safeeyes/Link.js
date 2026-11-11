.pragma library

// The service hands itself to this plugin's bar widgets here. Omarchy gives
// the widgets of a replacement bar (akaliff.bar) no service lookup, and a
// .pragma library is one instance per QML engine, so Service.qml and
// BarWidget.qml share this variable.
var service = null
