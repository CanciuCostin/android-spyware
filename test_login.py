import urllib.request, urllib.parse, http.cookiejar, re, sys

cj = http.cookiejar.CookieJar()
handler = urllib.request.HTTPCookieProcessor(cj)
redirect_handler = urllib.request.HTTPRedirectHandler()
opener = urllib.request.build_opener(handler, redirect_handler)

# Step 1: GET login page
print('Getting login page...', flush=True)
req1 = urllib.request.Request('http://localhost:8080/admin/login')
resp1 = opener.open(req1, timeout=10)
html = resp1.read().decode('utf-8', errors='replace')
print(f'Got page: {resp1.status}', flush=True)

# Extract CSRF token
m = re.search(r'name="authenticity_token"\s+value="([^"]+)"', html)
if not m:
    m = re.search(r'value="([^"]+)"\s+name="authenticity_token"', html)
if m:
    token = m.group(1)
    print(f'Token: {token[:30]}...', flush=True)
else:
    print('NO TOKEN FOUND', flush=True)
    print(html[:500], flush=True)
    sys.exit(1)

# Show cookies
for c in cj:
    print(f'Cookie: {c.name}={c.value[:20]}...', flush=True)

# Step 2: POST login  
print('Logging in...', flush=True)
data = urllib.parse.urlencode({
    'admin_user[email]': 'admin@example.com',
    'admin_user[password]': 'password',
    'authenticity_token': token,
    'commit': 'Login',
    'utf8': '\u2713'
}).encode('utf-8')

req2 = urllib.request.Request('http://localhost:8080/admin/login', data=data, method='POST')
req2.add_header('Content-Type', 'application/x-www-form-urlencoded')
req2.add_header('Accept', 'text/html')
try:
    resp2 = opener.open(req2, timeout=10)
    print(f'Login OK: {resp2.status} -> {resp2.url}', flush=True)
except urllib.error.HTTPError as e:
    print(f'Login HTTPError: {e.code} {e.reason}', flush=True)
    print(e.read().decode('utf-8', errors='replace')[:200], flush=True)
except Exception as e:
    print(f'Login error: {e}', flush=True)
    sys.exit(1)

print('DONE', flush=True)
