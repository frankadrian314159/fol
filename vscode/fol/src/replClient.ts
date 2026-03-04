import * as net from 'net';
import * as vscode from 'vscode';

export class FolReplClient {
    private client: net.Socket | null = null;
    private outputChannel: vscode.OutputChannel;
    private responseResolver: ((data: string) => void) | null = null;
    constructor() {
        this.outputChannel = vscode.window.createOutputChannel("FOL REPL Output");
    }

    public isConnected(): boolean {
        return this.client !== null && !this.client.destroyed;
    }

    public async connect(port: number): Promise<void> {
        // If we're already connected, don't try again
        if (this.isConnected()) return Promise.resolve();

        return new Promise((resolve, reject) => {
            this.client = new net.Socket();

            this.client.connect(port, '127.0.0.1', () => {
                this.outputChannel.appendLine("--- FOL: Connection Established ---");
                resolve();
            });

            this.client.on('data', (data: Buffer) => {
                const response = data.toString();
                this.outputChannel.append(response);
                if (this.responseResolver) {
                    this.responseResolver(response);
                    this.responseResolver = null;
                }
            });

            this.client.on('error', (err) => {
                this.cleanup(); // CRITICAL: Actually destroy the socket
                reject(err);
            });
        });
    }

    private cleanup() {
        this.client?.destroy();
        this.client = null;
    }

    public async evaluateForm(code: string): Promise<string> {
        return new Promise((resolve, reject) => {
            if (!this.isConnected()) return reject("Not connected");

            this.responseResolver = (data: string) => {
                const trimmed = data.trim();
                // Tagged protocol: (:ok "result") or (:error "message")
                const okMatch = trimmed.match(/^\(:ok\s+"(.*)"\s*\)$/s);
                const errMatch = trimmed.match(/^\(:error\s+"(.*)"\s*\)$/s);
                if (okMatch) {
                    resolve(okMatch[1]);
                } else if (errMatch) {
                    reject(new Error(errMatch[1]));
                } else {
                    // Fallback for any untagged response (shouldn't happen)
                    resolve(trimmed);
                }
            };

            this.client?.write(code + "\n");
        });
    }

    public async tryConnect(port: number): Promise<boolean> {
        return new Promise((resolve) => {
            const socket = new net.Socket();
            socket.setTimeout(500); // Fast polling for the FOL server

            socket.on('connect', () => {
                // Destroy immediately to signal this was only a liveness test
                socket.destroy();
                resolve(true);
            });

            socket.on('error', () => {
                socket.destroy();
                resolve(false);
            });

            socket.on('timeout', () => {
                socket.destroy();
                resolve(false);
            });

            socket.connect(port, '127.0.0.1');
        });
    }

    public showOutput() {
        this.outputChannel.show(true);
    }

    public clear() {
        // 1. Wipe the VS Code Output Channel text
        this.outputChannel.clear();

        // 2. Optional: Send a reset form to the Lisp server if your 
        // FOL-REPL package supports state clearing
        if (this.isConnected()) {
            this.client?.write("(cl:format cl:nil \"--- REPL State Cleared ---~%\")\n");
        }
    }
    
    public disconnect() {
        if (this.client) {
            this.client.destroy();
            this.client = null;
            this.outputChannel.appendLine("--- FOL: Client Disconnected for Restart ---");
        }
    }
}
