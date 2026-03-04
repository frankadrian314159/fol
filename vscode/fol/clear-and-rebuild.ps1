# Configuration
$PUBLISHER = "frankadrian314159"
$EXT_NAME = "fol"
$FULL_EXT_ID = "$PUBLISHER.$EXT_NAME"
$VSIX_NAME = "fol-0.0.1.vsix"
$LISP_EXE = "sbcl"
$STAGING_DIR = "staging_package"

Write-Host "--- 1. Killing VS Code and Lisp processes ---" -ForegroundColor Cyan
Get-Process -Name "Code", $LISP_EXE -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2 

Write-Host "--- 2. Uninstalling & Cleaning Cache ---" -ForegroundColor Cyan
code --uninstall-extension $FULL_EXT_ID --force

$ExtPath = "$HOME\.vscode\extensions"
Get-ChildItem -Path $ExtPath -Filter "*$EXT_NAME*" | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

$AsdfCache = "$HOME\AppData\Local\common-lisp\cache"
if (Test-Path $AsdfCache) {
    Get-ChildItem -Path $AsdfCache -Filter "*fol*" -Recurse | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "--- 3. Rebuilding VSIX (Final Path & Color Fix) ---" -ForegroundColor Cyan

# 3a. Compile in root where tsconfig.json exists
npm run compile
if ($LASTEXITCODE -ne 0) { throw "TypeScript compilation failed." }

# 3b. Fresh Start for Staging
$STAGING_DIR = "staging_package"
if (Test-Path $STAGING_DIR) { Remove-Item -Recurse -Force $STAGING_DIR }
New-Item -ItemType Directory -Path $STAGING_DIR | Out-Null

# 3c. THE ALLOW-LIST - Refined for 'out/test' and '.map' exclusion
$STAGING_DIR = "staging_package"

# Handle 'out' folder: Exclude .map files and the 'test' directory
$outTarget = Join-Path $STAGING_DIR "out"
New-Item -ItemType Directory -Path $outTarget -Force | Out-Null
Get-ChildItem -Path "out" -Recurse | Where-Object { 
    $_.Extension -ne ".map" -and $_.FullName -notmatch "\\test($|\\)" 
} | Copy-Item -Destination {
    # Maintain folder structure during copy
    $target = $_.FullName.Replace((Get-Item "out").FullName, $outTarget)
    if ($_.PSIsContainer) { 
        if (-not (Test-Path $target)) { New-Item -ItemType Directory -Path $target -Force | Out-Null }
    }
    $target
} -Force

# Handle 'syntaxes' and 'language-config' normally
if (Test-Path "syntaxes") { Copy-Item "syntaxes" -Destination $STAGING_DIR -Recurse -Force }
if (Test-Path "fol-language-configuration.json") { Copy-Item "fol-language-configuration.json" -Destination $STAGING_DIR -Force }

# 3d. RESOLVE JUNCTION: Copy Lisp source MINUS tests
$sourcePath = (Get-Item "lisp-src").FullName
$targetLispDir = Join-Path $STAGING_DIR "lisp-src"
New-Item -ItemType Directory -Path $targetLispDir -Force | Out-Null

Write-Host "Syncing Lisp source (excluding tests)..." -ForegroundColor Gray
Get-ChildItem -Path $sourcePath | Where-Object { $_.Name -ne "tests" } | Copy-Item -Destination $targetLispDir -Recurse -Force

# Clean up any trash that came along with the recursive copy 
Get-ChildItem -Path $targetLispDir -Include *.fasl, *.64xfasl, .git -Recurse | Remove-Item -Recurse -Force

# Positive Selection: Explicitly copy essential metadata
Copy-Item -Path ".\LICENSE.md" -Destination "$STAGING_DIR\LICENSE.md" -Force

# Final check for the server file 
if (Test-Path "repl-server.lisp") {
    Copy-Item "repl-server.lisp" -Destination $targetLispDir -Force
}

# 3e. SELECTIVE MANIFEST STRIP
# We must keep "contributes" for colors, but remove "scripts" to avoid tsconfig errors
Write-Host "Cleaning package.json while preserving syntax highlighting..." -ForegroundColor Gray
$manifestPath = Join-Path $STAGING_DIR "package.json"
Copy-Item "package.json" -Destination $STAGING_DIR -Force
$manifest = Get-Content $manifestPath | ConvertFrom-Json

# Only remove the specific items that block the vsce build
$manifest.PSObject.Properties.Remove("scripts")
$manifest.PSObject.Properties.Remove("devDependencies")

# Save the cleaned manifest
$manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath

# 3f. Package the Staging Folder
Push-Location $STAGING_DIR
npx @vscode/vsce package
Pop-Location

# 3g. Move resulting VSIX back to root
if (Test-Path "$STAGING_DIR\$VSIX_NAME") {
    Move-Item "$STAGING_DIR\$VSIX_NAME" . -Force
}

Write-Host "--- 4. Installing New Extension ---" -ForegroundColor Cyan
if (Test-Path $VSIX_NAME) {
    $installProcess = Start-Process -FilePath "code" -ArgumentList "--install-extension $VSIX_NAME --force" -Wait -PassThru
    
    if ($installProcess.ExitCode -ne 0) {
         Write-Error "Installation failed with exit code $($installProcess.ExitCode)"
    }
}

Write-Host "--- 5. Launching VS Code ---" -ForegroundColor Green
code .