import * as vscode from 'vscode';
import * as path from 'path';
import { FolReplClient } from './replClient';
import * as fs from 'fs';

// Initialize immediately to satisfy the compiler
const replClient = new FolReplClient();

let folTerminal: vscode.Terminal | undefined;

let folStatusBarItem: vscode.StatusBarItem;

/**
 * The Lisp script sent to SBCL on startup.
 * It muffles the 500+ symbol warnings from the Facade pattern and starts the server.
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
          (asdf:load-system :fol-compiler/core)
          
          ;; Load and start the extension server
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
    folStatusBarItem.text = "$(symbol-event) FOL: Initializing";
    folStatusBarItem.show();

    // 2. Start the SBCL process
    startLispServer(context);

    await vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: "FOL: Initializing",
        cancellable: false
    }, async (progress) => {
        // 3. The 10-second wait for CLOS MOP/ASDF
        for (let i = 10; i > 0; i--) {
            progress.report({ message: `Booting FOL environment... ${i}s` });
            await new Promise(resolve => setTimeout(resolve, 1000));
        }

        try {
            // 4. Connect the ALREADY INITIALIZED global client
            await replClient.connect(9010);
            vscode.window.setStatusBarMessage("$(check) FOL Connected");
        } catch (err) {
            vscode.window.showErrorMessage("Connection failed.");
        }
    });

    // 5. Use the SAME replClient in your commands
    context.subscriptions.push(
        vscode.commands.registerCommand('fol.eval', async () => {
            const editor = vscode.window.activeTextEditor;
            if (!editor) return;

            const selection = editor.selection;
            const code = editor.document.getText(selection.isEmpty ? editor.document.lineAt(selection.active.line).range : selection);

            try {
                replClient.showOutput();

                // Single call to the REPL
                const result = await replClient.evaluateForm(code);

                // Update UI
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
            const editor = vscode.window.activeTextEditor;
            if (!editor) return;

            // Get the entire text of the current file
            const fullCode = editor.document.getText();

            try {
                replClient.showOutput();
                folStatusBarItem.text = "$(sync~spin) FOL: Evaluating File...";

                // Reusing your evaluateForm logic for the whole buffer
                const result = await replClient.evaluateForm(fullCode);

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
            // 1. Disconnect the TCP client
            replClient.disconnect();

            // 2. Kill the existing SBCL terminal
            if (folTerminal) {
                folTerminal.dispose();
                folTerminal = undefined;
            }

            vscode.window.showInformationMessage("FOL: Restarting Server...");

            // 3. Re-trigger the startup sequence
            // This will call startLispServer and begin the 10-second wait
            await vscode.commands.executeCommand('workbench.action.reloadWindow');

            // ALTERNATIVELY, if you don't want a full window reload:
            // startLispServer(context);
            // (Insert the 10-second wait logic here manually)
        })
    );
}

/**
 * Spawns the SBCL terminal and sends the initialization string.
 */
function startLispServer(context: vscode.ExtensionContext) {
    const lispSrcPath = vscode.Uri.joinPath(context.extensionUri, 'lisp-src').fsPath;
    const tempInitPath = path.join(context.extensionUri.fsPath, 'init-runtime.lisp');

    // Write the init content to a physical file to avoid shell escaping errors
    fs.writeFileSync(tempInitPath, lispInitContent);

    folTerminal = vscode.window.createTerminal({
        name: "FOL REPL",
        env: { "FOL_LISP_SRC": lispSrcPath }
    });

    folTerminal.show();

    // Tell SBCL to load the file. This is much cleaner for PowerShell.
    folTerminal.sendText(`sbcl --load "${tempInitPath}"`);
}

/**
 * Helper to handle communication and UI feedback via the ReplClient
 */
async function sendToRepl(code: string) {
    // If the client isn't connected yet, try to connect now
    if (!replClient.isConnected()) {
        try {
            await replClient.connect(9010);
        } catch (e) {
            vscode.window.showErrorMessage("FOL Server is still starting. Please try again in a moment.");
            return;
        }
    }
    try {
        replClient.showOutput();
        const result = await replClient.evaluateForm(code);
        vscode.window.setStatusBarMessage(`FOL Result: ${result}`, 5000);
    } catch (err: any) {
        vscode.window.showErrorMessage(`REPL Error: ${err.message}`);
    }
}

export function deactivate() {
    if (folTerminal) {
        folTerminal.dispose();
    }
}