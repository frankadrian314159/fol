// The module 'vscode' contains the VS Code extensibility API
// Import the module and reference it with the alias vscode in your code below
import * as vscode from 'vscode';
import * as net from 'net';
import * as path from 'path';

// Keep track of the terminal running our Lisp server
let folTerminal: vscode.Terminal | null = null;
function startFolServer(context: vscode.ExtensionContext) {
    // If a terminal already exists, kill it to ensure a clean slate
    if (folTerminal) {
        folTerminal.dispose();
    }

    const workspaceFolders = vscode.workspace.workspaceFolders;
    if (!workspaceFolders) {
        vscode.window.showErrorMessage("FOL: You must have a folder open in VS Code.");
        return;
    }
    // 1. Get the current project workspace (where the user's .asd files are)
    const workspaceRoot = workspaceFolders[0].uri.fsPath.replace(/\\/g, '/');
    
    // 2. Get the extension's installation directory (where repl-server.lisp is bundled)
    const serverScriptPath = path.join(context.extensionPath, 'repl-server.lisp').replace(/\\/g, '/');
    folTerminal = vscode.window.createTerminal({
        name: "FOL REPL",
        cwd: workspaceRoot 
    });
    
    folTerminal.show(true);

    // FORCE the terminal to navigate to the workspace root
    // We wrap workspaceRoot in quotes in case your path has spaces in it
    folTerminal.sendText(`cd "${workspaceRoot}"`);

    // Send the bash commands to boot SBCL and start the server
    // (Adjust the path to your repl-server.lisp if it is not in the current workspace directory)
    folTerminal.sendText(`sbcl --eval "(push #p\\\"${workspaceRoot}/\\\" asdf:*central-registry*)" --load "${serverScriptPath}" --eval "(fol-repl-server::start-server 9010)"`);
    
    vscode.window.showInformationMessage("FOL: Server starting...");
}

// Your existing socket logic
function sendToFolServer(textToEval: string, statusBar: vscode.StatusBarItem) {
    if (textToEval.trim().length === 0) return;

    const port = 9010; 
    const host = '127.0.0.1';
    const client = new net.Socket();

    statusBar.text = '$(sync~spin) FOL: Evaluating...';
    statusBar.backgroundColor = undefined;

    client.connect(port, host, () => {
        client.end(textToEval + '\n'); 
    });

    client.on('data', (data) => {
        const result = data.toString().trim();
        vscode.window.showInformationMessage(`FOL: ${result}`);
        statusBar.text = '$(check) FOL: Ready';
        client.destroy(); 
    });

    client.on('error', (err) => {
        vscode.window.showErrorMessage(`FOL Server Error: Is the server running? Try restarting it.`);
        console.error(err);
        statusBar.text = '$(error) FOL: Offline';
        statusBar.backgroundColor = new vscode.ThemeColor('statusBarItem.errorBackground');
    });
}

export function activate(context: vscode.ExtensionContext) {
    console.log('FOL extension is now active!');

    const myStatusBarItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    myStatusBarItem.text = '$(server) FOL: Ready';
    myStatusBarItem.show();
    context.subscriptions.push(myStatusBarItem);

    // --- Commands ---

    const evalCommand = vscode.commands.registerCommand('fol.eval', () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor) return;
        const selection = editor.selection;
        const textToEval = selection.isEmpty 
            ? editor.document.lineAt(selection.active.line).text 
            : editor.document.getText(selection);
        sendToFolServer(textToEval, myStatusBarItem);
    });

    const evalFileCommand = vscode.commands.registerCommand('fol.evalFile', () => {
        const editor = vscode.window.activeTextEditor;
        if (!editor) return;
        const textToEval = editor.document.getText();
        sendToFolServer(textToEval, myStatusBarItem);
    });

    // The new Restart Command
    const restartCommand = vscode.commands.registerCommand('fol.restartServer', () => {
        startFolServer(context);
    });

    context.subscriptions.push(evalCommand, evalFileCommand, restartCommand);
}

export function deactivate() {
    // Clean up the terminal when VS Code is closed
    if (folTerminal) {
        folTerminal.dispose();
    }
}
