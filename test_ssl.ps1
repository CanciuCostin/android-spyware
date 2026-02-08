# SSL/TLS Testing Script for EagleSpy V5 (Windows)
# Tests SSL configuration, certificates, and security headers

param(
    [string]$Domain = "localhost",
    [int]$Port = 3000
)

$Protocol = "https"
$Url = "${Protocol}://${Domain}:${Port}"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "SSL/TLS Security Test for EagleSpy V5" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Target: $Url"
Write-Host ""

# Test 1: Check if server is responding
Write-Host "[1/6] Testing server connectivity..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri $Url -SkipCertificateCheck -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✓ Server is responding" -ForegroundColor Green
    Write-Host "  Status Code: $($response.StatusCode)" -ForegroundColor Gray
} catch {
    Write-Host "✗ Server is not responding" -ForegroundColor Red
    Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test 2: Check for HTTPS redirect
Write-Host "[2/6] Testing HTTP to HTTPS redirect..." -ForegroundColor Yellow
try {
    $httpUrl = "http://${Domain}:${Port}"
    $httpResponse = Invoke-WebRequest -Uri $httpUrl -MaximumRedirection 0 -ErrorAction Stop
    Write-Host "⚠ No HTTP redirect detected" -ForegroundColor Yellow
} catch {
    if ($_.Exception.Response.StatusCode -in @(301, 302, 307, 308)) {
        Write-Host "✓ HTTP redirects to HTTPS ($($_.Exception.Response.StatusCode))" -ForegroundColor Green
    } else {
        Write-Host "⚠ HTTP endpoint behavior unclear" -ForegroundColor Yellow
    }
}

# Test 3: Check HSTS header
Write-Host "[3/6] Checking Strict-Transport-Security header..." -ForegroundColor Yellow
$hstsHeader = $response.Headers['Strict-Transport-Security']
if ($hstsHeader) {
    Write-Host "✓ HSTS header present" -ForegroundColor Green
    Write-Host "  $hstsHeader" -ForegroundColor Gray
} else {
    Write-Host "✗ HSTS header missing" -ForegroundColor Red
}

# Test 4: Check security headers
Write-Host "[4/6] Checking security headers..." -ForegroundColor Yellow

$securityHeaders = @{
    'X-Frame-Options' = $response.Headers['X-Frame-Options']
    'X-Content-Type-Options' = $response.Headers['X-Content-Type-Options']
    'X-XSS-Protection' = $response.Headers['X-XSS-Protection']
    'Referrer-Policy' = $response.Headers['Referrer-Policy']
    'Content-Security-Policy' = $response.Headers['Content-Security-Policy']
    'Permissions-Policy' = $response.Headers['Permissions-Policy']
}

foreach ($header in $securityHeaders.GetEnumerator()) {
    if ($header.Value) {
        Write-Host "✓ $($header.Key) present" -ForegroundColor Green
        Write-Host "  $($header.Value)" -ForegroundColor Gray
    } else {
        Write-Host "✗ $($header.Key) missing" -ForegroundColor Red
    }
}

# Test 5: Check secure cookie flag
Write-Host "[5/6] Checking secure cookie settings..." -ForegroundColor Yellow
$cookies = $response.Headers['Set-Cookie']
if ($cookies) {
    $hasSecure = $cookies -match "(?i)secure"
    $hasHttpOnly = $cookies -match "(?i)httponly"
    
    if ($hasSecure) {
        Write-Host "✓ Cookies have Secure flag" -ForegroundColor Green
    } else {
        Write-Host "✗ Cookies missing Secure flag" -ForegroundColor Red
    }
    
    if ($hasHttpOnly) {
        Write-Host "✓ Cookies have HttpOnly flag" -ForegroundColor Green
    } else {
        Write-Host "⚠ Cookies missing HttpOnly flag" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠ No cookies set in response" -ForegroundColor Yellow
}

# Test 6: Check TLS version (requires openssl)
Write-Host "[6/6] Checking SSL/TLS protocol..." -ForegroundColor Yellow
if (Get-Command openssl -ErrorAction SilentlyContinue) {
    $sslInfo = echo "" | openssl s_client -connect "${Domain}:${Port}" -servername $Domain 2>$null | Select-String "Protocol"
    if ($sslInfo) {
        Write-Host $sslInfo -ForegroundColor Gray
        if ($sslInfo -match "TLSv1\.[23]") {
            Write-Host "✓ Using modern TLS version" -ForegroundColor Green
        } else {
            Write-Host "✗ Using outdated TLS version" -ForegroundColor Red
        }
    }
} else {
    Write-Host "⚠ OpenSSL not found, skipping TLS version check" -ForegroundColor Yellow
    Write-Host "  Install OpenSSL to check TLS version" -ForegroundColor Gray
}

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "SSL/TLS Security Test Complete" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Recommendations:" -ForegroundColor Cyan
Write-Host "1. Ensure HSTS is enabled with long max-age (1 year)"
Write-Host "2. All security headers should be present"
Write-Host "3. Use TLS 1.2 or higher"
Write-Host "4. Enable secure and httponly flags on cookies"
Write-Host "5. Consider SSL certificate pinning in Android client"
Write-Host ""
Write-Host "For detailed SSL analysis, visit: https://www.ssllabs.com/ssltest/" -ForegroundColor Gray
