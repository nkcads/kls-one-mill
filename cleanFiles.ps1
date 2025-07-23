# PowerShell-Skript: Alle *.h und *.hpp Dateien rekursiv in UTF-8 ohne BOM konvertieren
# und ungültige Zeichen ersetzen

$rootDir = "./"  # <-- anpassen!

Get-ChildItem -Path $rootDir -Recurse -Include *.h, *.hpp -File | ForEach-Object {
    $file = $_.FullName
    try {
        # Inhalt lesen, bei Fehlern ungültige Zeichen durch � ersetzen
        $content = Get-Content -Path $file -Raw -Encoding Byte
        $text = [System.Text.Encoding]::UTF8.GetString($content)

        # Optional: ungültige Zeichen bereinigen (ersetze durch Leerzeichen oder entferne)
        $textClean = $text -replace '[^\u0000-\u007F]', ''  # entfernt alle Nicht-ASCII-Zeichen

        # Datei in UTF-8 ohne BOM neu speichern
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($file, $textClean, $utf8NoBom)

        Write-Host "Fix: $file"
    } catch {
        Write-Warning "Fehler bei Datei: $file - $_"
    }
}
