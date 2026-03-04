import * as vscode from 'vscode';
import * as path from 'path';
import { FolReplClient } from './replClient';
import * as fs from 'fs';

// Initialize immediately to satisfy the compiler
const replClient = new FolReplClient();

let folTerminal: vscode.Terminal | undefined;
let folStatusBarItem: vscode.StatusBarItem;

// Resettable server-ready promise. Replaced each time the server restarts.
let serverReady: {
    promise: Promise<void>;
    resolve: () => void;
    reject: (err: Error) => void;
} = makeServerReady();

function makeServerReady() {
    let resolve!: () => void;
    let reject!: (err: Error) => void;
    const promise = new Promise<void>((res, rej) => { resolve = res; reject = rej; });
    return { promise, resolve, reject };
}

/**
 * Waits for the FOL server to be ready, up to `timeoutMs`.
 * Returns true if the server became ready in time, false otherwise.
 */
async function waitForServer(timeoutMs = 30_000): Promise<boolean> {
    try {
        await Promise.race([
            serverReady.promise,
            new Promise<void>((_, reject) =>
                setTimeout(() => reject(new Error('timeout')), timeoutMs))
        ]);
        return true;
    } catch {
        return false;
    }
}

/**
 * The Lisp script sent to SBCL on startup.
 * It muffles the 500+ symbol warnings from the Facade pattern and starts the server.
 * asdf:clear-system is called before loading so code changes are always picked up.
 */
const lispInitContent = `
(in-package :cl-user)
(require :asdf)

(handler-bind (#+sbcl (sb-int:package-at-variance #'muffle-warning)
               (warning #'muffle-warning))
  (handler-case
      (progn
        (let* ((source-dir (uiop:ensure-directory-pathname (uiop:getenv "FOL_LISP_SRC")))
               (asd-file (merge-pathnames "fol-compiler.asd" source-dir)))

          (format t "~&--- Setting Registry to: ~A ---~%" source-dir)
          (push source-dir asdf:*central-registry*)

          (format t "~&--- Loading System Definition: ~A ---~%" asd-file)
          (if (probe-file asd-file)
              (asdf:load-asd asd-file)
              (error "Could not find fol-compiler.asd at ~A" asd-file))

          ;; Load core first to resolve FOL.MACROS and collections
          (format t "~&--- Loading fol-compiler/core ---~%")
          (force-output)
          (asdf:load-system :fol-compiler/core)

          ;; Load and start the extension server
          (format t "~&--- Loading fol-extension-server ---~%")
          (force-output)
          (asdf:load-system :fol-extension-server)

          (format t "~&--- FOL SERVER STARTING ON PORT 9010 ---~%")
          (force-output)
          (uiop:symbol-call :fol-repl-server :start-server 9010)))
    (error (c)
      (format t "~&!!! FOL LOAD ERROR: ~A !!!~%" c)
      (force-output))))
`;

export async function activate(context: vscode.ExtensionContext) {
    folStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    context.subscriptions.push(folStatusBarItem);
    folStatusBarItem.text = "$(sync~spin) FOL: Starting...";
    folStatusBarItem.show();

    // Start the SBCL process
    startLispServer(context);

    // Register commands immediately so keybindings work during server startup.
    // Each handler awaits serverReady.promise so keystrokes auto-proceed once the
    // server is up rather than silently bailing.
    context.subscriptions.push(
        vscode.commands.registerCommand('fol.eval', async () => {
            vscode.window.setStatusBarMessage("$(sync~spin) FOL: received eval...", 3000);
            const ready = await waitForServer(30_000);
            if (!ready) {
                vscode.window.showErrorMessage("FOL: Server is not ready. Use 'FOL: Restart Server' to try again.");
                return;
            }

            const editor = vscode.window.activeTextEditor;
            if (!editor) return;

            const selection = editor.selection;
            const code = editor.document.getText(
                selection.isEmpty
                    ? editor.document.lineAt(selection.active.line).range
                    : selection
            );

            try {
                replClient.showOutput();
                const result = await replClient.evaluateForm(code);
                folStatusBarItem.text = `$(check) FOL: ${result}`;
                folStatusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.remoteBackground');
                vscode.window.showInformationMessage(`Result: ${result}`);
            } catch (err) {
                folStatusBarItem.text = `$(error) FOL: Error`;
                folStatusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
                vscode.window.showErrorMessage(`FOL Eval Error: ${err}`);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('fol.evalFile', async () => {
            vscode.window.setStatusBarMessage("$(sync~spin) FOL: received evalFile...", 3000);
            const ready = await waitForServer(30_000);
            if (!ready) {
                vscode.window.showErrorMessage("FOL: Server is not ready. Use 'FOL: Restart Server' to try again.");
                return;
            }

            const editor = vscode.window.activeTextEditor;
            if (!editor) return;

            const fullCode = editor.document.getText();

            try {
                replClient.showOutput();
                folStatusBarItem.text = "$(sync~spin) FOL: Evaluating File...";
                await replClient.evaluateForm(fullCode);
                folStatusBarItem.text = `$(check) FOL: File Loaded`;
                folStatusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.remoteBackground');
                vscode.window.showInformationMessage("FOL: File evaluated successfully.");
            } catch (err) {
                folStatusBarItem.text = `$(error) FOL: Eval Error`;
                folStatusBarItem.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
                vscode.window.showErrorMessage(`FOL File Eval Error: ${err}`);
            }
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('fol.clearRepl', () => {
            replClient.clear();
            vscode.window.setStatusBarMessage("$(trash) FOL REPL Cleared", 3000);
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('fol.restartServer', async () => {
            replClient.disconnect();

            if (folTerminal) {
                folTerminal.dispose();
                folTerminal = undefined;
            }

            // Replace the one-shot promise so waitForServer() blocks again
            // until the new SBCL process is ready.
            serverReady = makeServerReady();

            folStatusBarItem.text = "$(sync~spin) FOL: Restarting...";
            vscode.window.showInformationMessage("FOL: Restarting Server...");

            startLispServer(context);
            pollForConnection();
        })
    );

    // Poll until the SBCL server is listening on the initial startup.
    pollForConnection();
}

/**
 * Polls port 9010 until the SBCL server is listening, then connects and
 * resolves serverReady. Uses the module-level `serverReady` reference so
 * it works correctly after a restart replaces the promise.
 */
async function pollForConnection() {
    const timeoutMs = 120_000;
    const pollMs = 1_000;
    const start = Date.now();

    // Capture the promise instance active at the time polling started,
    // so a subsequent restart doesn't resolve the wrong promise.
    const thisRound = serverReady;

    await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: "FOL: Waiting for server",
        cancellable: false
    }, async (progress) => {
        let elapsed = 0;

        while (elapsed < timeoutMs) {
            // Bail out if a newer restart has replaced the promise.
            if (serverReady !== thisRound) return;

            progress.report({ message: `${Math.round(elapsed / 1000)}s elapsed…` });
            const up = await replClient.tryConnect(9010);
            if (up) {
                try {
                    await replClient.connect(9010);
                    thisRound.resolve();
                    folStatusBarItem.text = "$(check) FOL: Connected";
                    vscode.window.setStatusBarMessage("$(check) FOL Connected", 5000);
                } catch (err) {
                    thisRound.reject(new Error(`Connection failed: ${err}`));
                    vscode.window.showErrorMessage(`FOL: Connection failed — ${err}`);
                    folStatusBarItem.text = "$(error) FOL: Connection failed";
                }
                return;
            }
            await new Promise(resolve => setTimeout(resolve, pollMs));
            elapsed = Date.now() - start;
        }

        thisRound.reject(new Error('Server startup timed out'));
        vscode.window.showErrorMessage("FOL: Server did not start within 120s.");
        folStatusBarItem.text = "$(error) FOL: Timed out";
    });
}

/**
 * Spawns the SBCL terminal and sends the initialization string.
 */
function startLispServer(context: vscode.ExtensionContext) {
    const lispSrcPath = vscode.Uri.joinPath(context.extensionUri, 'lisp-src').fsPath;
    const tempInitPath = path.join(context.extensionUri.fsPath, 'init-runtime.lisp');

    fs.writeFileSync(tempInitPath, lispInitContent);

    folTerminal = vscode.window.createTerminal({
        name: "FOL REPL",
        env: { "FOL_LISP_SRC": lispSrcPath }
    });

    folTerminal.show(true); // preserveFocus: keep editor focused so keybindings still fire
    folTerminal.sendText(`sbcl --load "${tempInitPath}"`);
}

export function deactivate() {
    if (folTerminal) {
        folTerminal.dispose();
    }
}
