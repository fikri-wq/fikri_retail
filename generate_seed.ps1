$priceMap = @{
    "AIR MINERAL" = @{ "Gelas" = 500; "Botol - 330ml" = 3000; "Botol - 220ml" = 2000; "Botol - 550ml" = 4000; "Botol - 600ml" = 4000; "Botol - 1.2L" = 6000; "Botol - 1.5L" = 6000; "Galon - 15L" = 20000; "Galon - 19L" = 22000; "default" = 4000 }
    "BUMBU MASAK" = @{ "sachet" = 2500; "botol" = 12000; "75g" = 5000; "80g" = 5000; "210g" = 12000; "default" = 5000 }
    "DETERGEN DAN LAUNDRY" = @{ "default" = 18000 }
    "FROZEN FOOD" = @{ "pack" = 35000; "500g" = 40000; "400g" = 38000; "pcs" = 8000; "default" = 35000 }
    "KOPI" = @{ "sachet" = 2500; "380g" = 35000; "250ml" = 7000; "kaleng" = 8000; "default" = 2500 }
    "MAKANAN KALENG DAN INSTAN" = @{ "425g" = 18000; "155g" = 10000; "kaleng" = 15000; "198g" = 25000; "120g" = 18000; "400g" = 30000; "sachet" = 5000; "cup" = 7000; "default" = 12000 }
    "MIE INSTAN" = @{ "cup" = 5500; "default" = 3500 }
    "MINUMAN SERBUK" = @{ "default" = 2000 }
    "MINUMAN SIAP MINUM" = @{ "250ml" = 5000; "330ml" = 7000; "350ml" = 6000; "390ml" = 7000; "500ml" = 8000; "200m" = 4000; "140ml" = 8000; "botol" = 8000; "kaleng" = 6000; "default" = 6000 }
    "PASTA GIGI DAN SIKAT GIGI" = @{ "pcs" = 15000; "50g" = 8000; "100g" = 18000; "120g" = 12000; "160g" = 15000; "default" = 15000 }
    "PRODUK BAYI" = @{ "pack" = 55000; "box" = 25000; "200ml" = 22000; "100ml" = 18000; "100m" = 18000; "50ml" = 12000; "100g" = 15000; "300g" = 20000; "default" = 35000 }
    "SABUN, SHAMPOO, DAN PERSONAL CARE" = @{ "cair" = 18000; "batang" = 8000; "botol" = 28000; "sachet" = 1500; "340ml" = 32000; "default" = 18000 }
    "SEMBAKO" = @{ "5kg" = 65000; "25kg" = 280000; "1kg" = 15000; "500g" = 8000; "250g" = 12000; "200g" = 8000; "1L" = 18000; "2L" = 35000; "default" = 15000 }
    "SNACK DAN BISQUIT" = @{ "35g" = 5000; "36g" = 5000; "40g" = 5000; "50g" = 6000; "55g" = 7000; "60g" = 7000; "68g" = 10000; "pack" = 10000; "kaleng" = 65000; "cup" = 8000; "pac" = 10000; "default" = 8000 }
    "SUSU" = @{ "kaleng" = 12000; "sachet" = 3000; "22g" = 3000; "180ml" = 5000; "190ml" = 5000; "200ml" = 6000; "225ml" = 6000; "125ml" = 4000; "1L" = 18000; "400g" = 45000; "600g" = 55000; "kaleng 189ml" = 10000; "default" = 15000 }
}

$descMap = @{
    "AIR MINERAL" = "Air mineral murni, segar dan higienis untuk kebutuhan minum sehari-hari"
    "BUMBU MASAK" = "Bumbu masak praktis, pelengkap rasa masakan nusantara"
    "DETERGEN DAN LAUNDRY" = "Detergen dan pewangi pakaian, menjaga kebersihan dan keharuman cucian"
    "FROZEN FOOD" = "Makanan beku siap masak, praktis dan lezat untuk keluarga"
    "KOPI" = "Kopi nikmat, teman santai dan penambah semangat"
    "MAKANAN KALENG DAN INSTAN" = "Makanan kaleng dan instan, praktis dan tahan lama"
    "MIE INSTAN" = "Mie instan, makanan siap saji cepat dan lezat"
    "MINUMAN SERBUK" = "Minuman serbuk segar, tinggal seduh dan nikmati"
    "MINUMAN SIAP MINUM" = "Minuman siap minum, segar dan praktis dibawa kemana saja"
    "PASTA GIGI DAN SIKAT GIGI" = "Perawatan gigi dan mulut, menjaga kesehatan dan kebersihan"
    "PRODUK BAYI" = "Produk perawatan bayi, lembut dan aman untuk si kecil"
    "SABUN, SHAMPOO, DAN PERSONAL CARE" = "Sabun dan perawatan tubuh, menjaga kebersihan dan kesegaran"
    "SEMBAKO" = "Sembako kebutuhan pokok dapur sehari-hari"
    "SNACK DAN BISQUIT" = "Makanan ringan dan biskuit, cemilan santai untuk semua"
    "SUSU" = "Susu bergizi, asupan nutrisi sehat untuk keluarga"
}

$output = "final List<Map<String, dynamic>> seedProductsNew = [`n"

$lines = Get-Content "product_list.txt" | Where-Object { $_.Trim() -ne "" }

foreach ($line in $lines) {
    $parts = $line -split "\|"
    $category = $parts[0]
    $brand = $parts[1]
    $filename = $parts[2]
    $imagePath = $parts[3]
    
    # Build product name: Brand + Filename (restore underscores to spaces for display)
    $displayBrand = $brand -replace '_', ' '
    $displayFilename = $filename -replace '_', ' '
    $productName = "$displayBrand $displayFilename"
    
    # Get description (restore category name for lookup)
    $displayCategory = $category -replace '_', ' '
    $desc = $descMap[$displayCategory]
    if (-not $desc) { $desc = "Produk retail berkualitas" }
    
    # Get price based on category and size hint in filename
    $price = 5000
    $catPrices = $priceMap[$displayCategory]
    if ($catPrices) {
        $foundPrice = $false
        foreach ($key in $catPrices.Keys) {
            if ($key -ne "default" -and $displayFilename -match [regex]::Escape($key)) {
                $price = $catPrices[$key]
                $foundPrice = $true
                break
            }
        }
        if (-not $foundPrice) {
            $price = $catPrices["default"]
        }
    }
    
    # Stock random between 20-100
    $stock = Get-Random -Minimum 20 -Maximum 101
    
    # Escape single quotes in strings
    $productName = $productName.Replace("'", "\'")
    $desc = $desc.Replace("'", "\'")
    $imagePath = $imagePath.Replace("'", "\'")
    
    $output += "  {`n"
    $output += "    'name': '$productName',`n"
    $output += "    'description': '$desc',`n"
    $output += "    'price': $price.0,`n"
    $output += "    'stock': $stock,`n"
    $output += "    'image_url': '$imagePath',`n"
    $output += "  },`n"
}

$output += "];`n"

$output | Out-File -FilePath "lib\seed_data_new.dart" -Encoding UTF8

Write-Host "Generated seed_data_new.dart with $($lines.Count) products"
