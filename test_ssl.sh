#!/bin/bash
# SSL/TLS Testing Script for EagleSpy V5
# Tests SSL configuration, certificates, and security headers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="${1:-localhost}"
PORT="${2:-3000}"
PROTOCOL="https"

echo "================================================"
echo "SSL/TLS Security Test for EagleSpy V5"
echo "================================================"
echo "Target: ${PROTOCOL}://${DOMAIN}:${PORT}"
echo ""

# Test 1: Check if server is responding
echo -e "${YELLOW}[1/7] Testing server connectivity...${NC}"
if curl -k -s -o /dev/null -w "%{http_code}" "${PROTOCOL}://${DOMAIN}:${PORT}" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Server is responding${NC}"
else
    echo -e "${RED}✗ Server is not responding${NC}"
    echo "Make sure the server is running and accessible"
    exit 1
fi

# Test 2: Check SSL/TLS certificate
echo -e "${YELLOW}[2/7] Checking SSL/TLS certificate...${NC}"
if openssl s_client -connect "${DOMAIN}:${PORT}" -servername "${DOMAIN}" </dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
    echo -e "${GREEN}✓ Valid SSL certificate${NC}"
else
    echo -e "${YELLOW}⚠ Certificate verification failed (expected for self-signed)${NC}"
fi

# Get certificate details
CERT_INFO=$(openssl s_client -connect "${DOMAIN}:${PORT}" -servername "${DOMAIN}" </dev/null 2>/dev/null | openssl x509 -noout -dates)
echo "$CERT_INFO"

# Test 3: Check for HTTP to HTTPS redirect (if FORCE_SSL is enabled)
echo -e "${YELLOW}[3/7] Testing HTTP to HTTPS redirect...${NC}"
HTTP_REDIRECT=$(curl -s -o /dev/null -w "%{http_code}" "http://${DOMAIN}:${PORT}" 2>/dev/null || echo "failed")
if [[ "$HTTP_REDIRECT" == "301" ]] || [[ "$HTTP_REDIRECT" == "302" ]] || [[ "$HTTP_REDIRECT" == "307" ]] || [[ "$HTTP_REDIRECT" == "308" ]]; then
    echo -e "${GREEN}✓ HTTP redirects to HTTPS (${HTTP_REDIRECT})${NC}"
elif [[ "$HTTP_REDIRECT" == "failed" ]]; then
    echo -e "${YELLOW}⚠ HTTP endpoint not accessible (SSL only mode)${NC}"
else
    echo -e "${YELLOW}⚠ No HTTP redirect detected (status: ${HTTP_REDIRECT})${NC}"
fi

# Test 4: Check HSTS header
echo -e "${YELLOW}[4/7] Checking Strict-Transport-Security header...${NC}"
HSTS=$(curl -k -s -I "${PROTOCOL}://${DOMAIN}:${PORT}" | grep -i "strict-transport-security" || echo "")
if [[ -n "$HSTS" ]]; then
    echo -e "${GREEN}✓ HSTS header present${NC}"
    echo "  $HSTS"
else
    echo -e "${RED}✗ HSTS header missing${NC}"
fi

# Test 5: Check security headers
echo -e "${YELLOW}[5/7] Checking security headers...${NC}"
HEADERS=$(curl -k -s -I "${PROTOCOL}://${DOMAIN}:${PORT}")

check_header() {
    local header_name="$1"
    local expected_value="$2"
    
    if echo "$HEADERS" | grep -qi "$header_name"; then
        echo -e "${GREEN}✓ $header_name present${NC}"
        echo "$HEADERS" | grep -i "$header_name" | head -n 1
    else
        echo -e "${RED}✗ $header_name missing${NC}"
    fi
}

check_header "X-Frame-Options"
check_header "X-Content-Type-Options"
check_header "X-XSS-Protection"
check_header "Referrer-Policy"
check_header "Content-Security-Policy"
check_header "Permissions-Policy"

# Test 6: Check SSL/TLS version and ciphers
echo -e "${YELLOW}[6/7] Checking SSL/TLS protocol version...${NC}"
SSL_VERSION=$(openssl s_client -connect "${DOMAIN}:${PORT}" -servername "${DOMAIN}" </dev/null 2>/dev/null | grep "Protocol" || echo "Unknown")
echo "$SSL_VERSION"

if echo "$SSL_VERSION" | grep -q "TLSv1.3\|TLSv1.2"; then
    echo -e "${GREEN}✓ Using modern TLS version${NC}"
else
    echo -e "${RED}✗ Using outdated TLS version${NC}"
fi

# Test 7: Test secure cookie flag
echo -e "${YELLOW}[7/7] Checking secure cookie settings...${NC}"
COOKIES=$(curl -k -s -I "${PROTOCOL}://${DOMAIN}:${PORT}" | grep -i "set-cookie" || echo "")
if [[ -n "$COOKIES" ]]; then
    if echo "$COOKIES" | grep -qi "secure"; then
        echo -e "${GREEN}✓ Cookies have Secure flag${NC}"
    else
        echo -e "${RED}✗ Cookies missing Secure flag${NC}"
    fi
    
    if echo "$COOKIES" | grep -qi "httponly"; then
        echo -e "${GREEN}✓ Cookies have HttpOnly flag${NC}"
    else
        echo -e "${YELLOW}⚠ Cookies missing HttpOnly flag${NC}"
    fi
else
    echo -e "${YELLOW}⚠ No cookies set in response${NC}"
fi

echo ""
echo "================================================"
echo "SSL/TLS Security Test Complete"
echo "================================================"
echo ""
echo "Recommendations:"
echo "1. Ensure HSTS is enabled with long max-age (1 year)"
echo "2. All security headers should be present"
echo "3. Use TLS 1.2 or higher"
echo "4. Enable secure and httponly flags on cookies"
echo "5. Consider SSL certificate pinning in Android client"
echo ""
echo "For detailed SSL analysis, use: https://www.ssllabs.com/ssltest/"
