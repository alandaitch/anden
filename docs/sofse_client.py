# Cliente minimo verificado de la API SOFSE. Ver api-reference.md seccion 2.

import base64, json, re, time, urllib.parse, urllib.request, urllib.error, datetime, os
BASE = "https://api-servicios.sofse.gob.ar/v1"
CIPHER = [("a",["#t","#j"]),("e",["#x","#p"]),("i",["#f","#w"]),
          ("o",["#l","#8"]),("u",["#7","#0"]),("=",["#g","#v"])]
def b64(s): return base64.b64encode(s.encode()).decode()
def cipher(s, step):
    for ch, out in CIPHER: s = s.replace(ch, out[step])
    return s
def rev(s): return s[::-1]
def gen_creds():
    d = datetime.datetime.now(datetime.timezone.utc)
    username = b64(f"{d.year:04d}{d.month:02d}{d.day:02d}sofse")
    p = b64(username); p = cipher(p,0); p = rev(p); p = b64(p); p = cipher(p,1); p = rev(p)
    return {"username": username, "password": urllib.parse.quote(p)}
TOKFILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "token.dat")
_tok = None
def token(force=False):
    global _tok
    if _tok and not force: return _tok
    if not force and os.path.exists(TOKFILE):
        t = open(TOKFILE).read().strip()
        if t:
            payload = json.loads(base64.urlsafe_b64decode(t.split('.')[1]+'=='))
            if payload.get('exp',0)*1000 > time.time()*1000: _tok = t; return t
    body = json.dumps(gen_creds()).encode()
    req = urllib.request.Request(BASE+"/auth/authorize", data=body,
        headers={"Content-Type":"application/json"}, method="POST")
    r = json.load(urllib.request.urlopen(req, timeout=30))
    _tok = r["token"]; open(TOKFILE,"w").write(_tok)
    return _tok
def get(path, auth=True, raw=False):
    h = {"Content-Type":"application/json"}
    if auth: h["Authorization"] = token()
    req = urllib.request.Request(BASE+path, headers=h)
    try:
        b = urllib.request.urlopen(req, timeout=40).read().decode("utf-8","replace")
        code = 200
    except urllib.error.HTTPError as e:
        b = e.read().decode("utf-8","replace"); code = e.code
        if code in (401,403) and auth:
            token(force=True); return get(path, auth, raw)
    if raw: return code, b
    try: return code, json.loads(b)
    except Exception: return code, b
