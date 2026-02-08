# SSL/TLS Implementation Validation Script
# Validates that all SSL/TLS components are properly configured

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "SSL/TLS Implementation Validation" -ForegroundColor Cyan
Write-Host "EagleSpy V5" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

$errors = 0
$warnings = 0

# Test 1: Check middleware file exists
Write-Host "[1/10] Checking SecurityHeaders middleware..." -ForegroundColor Yellow
$middlewarePath = "E:\EagleSpy V5\app\middleware\security_headers.rb"
if (Test-Path $middlewarePath) {
    Write-Host "✓ SecurityHeaders middleware exists" -ForegroundColor Green
    
    # Check syntax
    $syntaxCheck = ruby -c $middlewarePath 2>&1
    if ($syntaxCheck -match "Syntax OK") {
        Write-Host "✓ Syntax is valid" -ForegroundColor Green
    } else {
        Write-Host "✗ Syntax error in middleware" -ForegroundColor Red
        $errors++
    }
} else {
    Write-Host "✗ SecurityHeaders middleware missing" -ForegroundColor Red
    $errors++
}

# Test 2: Check application.rb registration
Write-Host "[2/10] Checking middleware registration..." -ForegroundColor Yellow
$appConfig = Get-Content "E:\EagleSpy V5\config\application.rb" -Raw
if ($appConfig -match "SecurityHeaders") {
    Write-Host "✓ Middleware registered in application.rb" -ForegroundColor Green
} else {
    Write-Host "✗ Middleware not registered" -ForegroundColor Red
    $errors++
}

if ($appConfig -match "autoload_paths.*middleware") {
    Write-Host "✓ Middleware path in autoload_paths" -ForegroundColor Green
} else {
    Write-Host "✗ Middleware path not in autoload_paths" -ForegroundColor Red
    $errors++
}

# Test 3: Check puma.rb SSL configuration
Write-Host "[3/10] Checking Puma SSL configuration..." -ForegroundColor Yellow
$pumaConfig = Get-Content "E:\EagleSpy V5\config\puma.rb" -Raw
if ($pumaConfig -match "ssl_bind") {
    Write-Host "✓ SSL binding configured in puma.rb" -ForegroundColor Green
} else {
    Write-Host "⚠ SSL binding not found in puma.rb" -ForegroundColor Yellow
    $warnings++
}

if ($pumaConfig -match "ENV\.fetch\('USE_SSL'") {
    Write-Host "✓ Environment-based SSL toggle present" -ForegroundColor Green
} else {
    Write-Host "⚠ Environment-based SSL toggle not found" -ForegroundColor Yellow
    $warnings++
}

# Test 4: Check production.rb SSL settings
Write-Host "[4/10] Checking production environment SSL..." -ForegroundColor Yellow
$prodConfig = Get-Content "E:\EagleSpy V5\config\environments\production.rb" -Raw
if ($prodConfig -match "config\.force_ssl") {
    Write-Host "✓ force_ssl configured in production" -ForegroundColor Green
} else {
    Write-Host "✗ force_ssl not configured" -ForegroundColor Red
    $errors++
}

if ($prodConfig -match "ssl_options") {
    Write-Host "✓ SSL options configured" -ForegroundColor Green
} else {
    Write-Host "✗ SSL options missing" -ForegroundColor Red
    $errors++
}

# Test 5: Check .env file
Write-Host "[5/10] Checking .env configuration..." -ForegroundColor Yellow
$envPath = "E:\EagleSpy V5\.env"
if (Test-Path $envPath) {
    $envContent = Get-Content $envPath -Raw
    
    if ($envContent -match "USE_SSL") {
        Write-Host "✓ USE_SSL variable present" -ForegroundColor Green
    } else {
        Write-Host "✗ USE_SSL variable missing" -ForegroundColor Red
        $errors++
    }
    
    if ($envContent -match "SSL_KEY_PATH") {
        Write-Host "✓ SSL_KEY_PATH variable present" -ForegroundColor Green
    } else {
        Write-Host "✗ SSL_KEY_PATH variable missing" -ForegroundColor Red
        $errors++
    }
    
    if ($envContent -match "SSL_CERT_PATH") {
        Write-Host "✓ SSL_CERT_PATH variable present" -ForegroundColor Green
    } else {
        Write-Host "✗ SSL_CERT_PATH variable missing" -ForegroundColor Red
        $errors++
    }
} else {
    Write-Host "✗ .env file not found" -ForegroundColor Red
    $errors++
}

# Test 6: Check Android network security config
Write-Host "[6/10] Checking Android network security config..." -ForegroundColor Yellow
$androidConfigPath = "E:\EagleSpy V5\android-client\app\src\main\res\xml\network_security_config.xml"
if (Test-Path $androidConfigPath) {
    Write-Host "✓ network_security_config.xml exists" -ForegroundColor Green
    
    $androidConfig = Get-Content $androidConfigPath -Raw
    if ($androidConfig -match "cleartextTrafficPermitted") {
        Write-Host "✓ Cleartext traffic policy configured" -ForegroundColor Green
    }
    
    if ($androidConfig -match "pin-set" -or $androidConfig -match "certificate pinning") {
        Write-Host "✓ Certificate pinning template present" -ForegroundColor Green
    } else {
        Write-Host "⚠ Certificate pinning template not found (optional)" -ForegroundColor Yellow
    }
} else {
    Write-Host "✗ network_security_config.xml missing" -ForegroundColor Red
    $errors++
}

# Test 7: Check documentation exists
Write-Host "[7/10] Checking documentation files..." -ForegroundColor Yellow
$docs = @(
    "SSL_SETUP_GUIDE.md",
    "CERTIFICATE_PINNING_GUIDE.md",
    "SECURITY_HARDENING.md",
    "SSL_IMPLEMENTATION_SUMMARY.md",
    "SSL_README.md"
)

$missingDocs = 0
foreach ($doc in $docs) {
    $docPath = "E:\EagleSpy V5\$doc"
    if (Test-Path $docPath) {
        $size = (Get-Item $docPath).Length
        Write-Host "  ✓ $doc ($([math]::Round($size/1024, 1)) KB)" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $doc missing" -ForegroundColor Red
        $missingDocs++
    }
}

if ($missingDocs -eq 0) {
    Write-Host "✓ All documentation files present" -ForegroundColor Green
} else {
    Write-Host "✗ $missingDocs documentation files missing" -ForegroundColor Red
    $errors += $missingDocs
}

# Test 8: Check test scripts
Write-Host "[8/10] Checking SSL test scripts..." -ForegroundColor Yellow
if (Test-Path "E:\EagleSpy V5\test_ssl.ps1") {
    Write-Host "✓ test_ssl.ps1 exists" -ForegroundColor Green
} else {
    Write-Host "✗ test_ssl.ps1 missing" -ForegroundColor Red
    $errors++
}

if (Test-Path "E:\EagleSpy V5\test_ssl.sh") {
    Write-Host "✓ test_ssl.sh exists" -ForegroundColor Green
} else {
    Write-Host "✗ test_ssl.sh missing" -ForegroundColor Red
    $errors++
}

# Test 9: Verify Ruby syntax for all config files
Write-Host "[9/10] Checking Ruby syntax for config files..." -ForegroundColor Yellow
$configFiles = @(
    "E:\EagleSpy V5\config\application.rb",
    "E:\EagleSpy V5\config\puma.rb",
    "E:\EagleSpy V5\config\environments\production.rb",
    "E:\EagleSpy V5\config\environments\development.rb"
)

$syntaxErrors = 0
foreach ($file in $configFiles) {
    $fileName = Split-Path $file -Leaf
    $check = ruby -c $file 2>&1
    if ($check -match "Syntax OK") {
        Write-Host "  ✓ $fileName" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $fileName has syntax errors" -ForegroundColor Red
        $syntaxErrors++
    }
}

if ($syntaxErrors -eq 0) {
    Write-Host "✓ All config files have valid syntax" -ForegroundColor Green
} else {
    Write-Host "✗ $syntaxErrors config files have syntax errors" -ForegroundColor Red
    $errors += $syntaxErrors
}

# Test 10: Check NETWORK_CONFIGURATION.md updated
Write-Host "[10/10] Checking NETWORK_CONFIGURATION.md..." -ForegroundColor Yellow
$networkConfig = Get-Content "E:\EagleSpy V5\NETWORK_CONFIGURATION.md" -Raw
if ($networkConfig -match "SSL" -or $networkConfig -match "HTTPS") {
    Write-Host "✓ NETWORK_CONFIGURATION.md includes SSL section" -ForegroundColor Green
} else {
    Write-Host "⚠ NETWORK_CONFIGURATION.md may need SSL section" -ForegroundColor Yellow
    $warnings++
}

# Summary
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Validation Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Host "✓ ALL TESTS PASSED" -ForegroundColor Green
    Write-Host "SSL/TLS implementation is complete and valid!" -ForegroundColor Green
} elseif ($errors -eq 0) {
    Write-Host "✓ TESTS PASSED WITH WARNINGS" -ForegroundColor Yellow
    Write-Host "Errors: $errors" -ForegroundColor Green
    Write-Host "Warnings: $warnings" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Implementation is functional but review warnings." -ForegroundColor Yellow
} else {
    Write-Host "✗ TESTS FAILED" -ForegroundColor Red
    Write-Host "Errors: $errors" -ForegroundColor Red
    Write-Host "Warnings: $warnings" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please fix errors before deploying." -ForegroundColor Red
}

Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Review SSL_README.md for quick start" -ForegroundColor Gray
Write-Host "2. For development: Generate self-signed certificate" -ForegroundColor Gray
Write-Host "3. For production: Obtain Let's Encrypt certificate" -ForegroundColor Gray
Write-Host "4. Run test_ssl.ps1 to verify SSL configuration" -ForegroundColor Gray
Write-Host "5. Build Android APK with HTTPS URL" -ForegroundColor Gray
Write-Host ""

exit $errors
