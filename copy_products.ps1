# Copy all product images from LIST PRODUK to assets/products with clean folder names (no spaces)
$source = "LIST PRODUK"
$dest = "assets\products"

Get-ChildItem -Path $source -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Substring((Resolve-Path $source).Path.Length + 1)
    
    # Replace spaces with underscores, remove commas
    $cleanPath = $relativePath -replace ' ', '_'
    $cleanPath = $cleanPath -replace ',', ''
    $cleanPath = $cleanPath -replace "'", ""
    
    $destPath = Join-Path $dest $cleanPath
    $destDir = Split-Path $destPath -Parent
    
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    
    Copy-Item $_.FullName -Destination $destPath -Force
}

Write-Host "Done copying files"
Get-ChildItem -Path $dest -Recurse -File | Measure-Object | Select-Object -ExpandProperty Count
