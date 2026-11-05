pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import QtQuick
import "../config"

// Screen lock state and the password check. The lock screen itself is modules/lock/LockScreen.qml; this
// is what it (and the power menu, the idle timers and `qs ipc call lock lock`) talk to.
//
// The password is checked by PAM through config/pam/ushell.conf (pam_unix: the same account password as
// the system login). If Config.nativeLock is false, lock() just runs Config.lockCommand instead.
Singleton {
    id: root

    property bool locked: false
    property bool checking: false            // a password is being verified
    property bool failed: false              // the last attempt was wrong
    property int attempts: 0                 // wrong attempts since the screen locked
    property string message: ""              // what PAM wants to say (e.g. "Account locked")

    function lock() {
        if (Config.nativeLock) {
            if (locked) return
            Shell.close()
            reset()
            locked = true
        } else if (!lockProc.running) lockProc.running = true
    }

    function reset() { failed = false; attempts = 0; message = ""; checking = false; pending = "" }

    property string pending: ""              // the password on its way to PAM
    function submit(password) {
        if (checking || password === "") return
        pending = password
        checking = true
        failed = false
        message = ""
        pam.start()
    }

    PamContext {
        id: pam
        config: "ushell.conf"
        configDirectory: Quickshell.shellPath("config/pam")
        onPamMessage: {
            if (responseRequired) { respond(root.pending); root.pending = "" }
            else if (messageIsError) root.message = message
        }
        onCompleted: result => {
            root.pending = ""
            root.checking = false
            if (result === PamResult.Success) { root.locked = false; root.reset() }
            else { root.failed = true; root.attempts++ }
        }
        onError: e => { root.pending = ""; root.checking = false; root.failed = true; root.message = "Could not check the password" }
    }

    Process { id: lockProc; command: Config.lockCommand }
}
