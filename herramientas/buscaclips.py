#!/usr/bin/env python3
"""Seraf Clips · buscaclips: encuentra momentos con potencial de clip en un VOD largo.
Señales: subidas de volumen (gritos, risas, acción), picos de chat (YouTube y Twitch) y transcripción."""
import sys, os, re, json, time, shutil, statistics, subprocess, urllib.request
import html as H

HOME = os.path.expanduser("~")
CLIPS = os.path.join(HOME, "Desktop", "Clips")
WORKROOT = os.path.join(CLIPS, ".buscar")
OUTDIR = os.path.join(CLIPS, "candidatos")
MODEL = os.path.join(HOME, "clipstools", "modelos", "ggml-large-v3-turbo-q5_0.bin")
ENC = os.environ.get("SERAF_ENC", "h264_videotoolbox")
RISA = re.compile(r"(?:ja|je|ji|js){2,}|xd+\b|lul|kekw|omegalul|lmao|😂|🤣|💀|\bclip", re.I)
TW_HASH = "b70a3591ff0f4e0313d126c6a1502d79a1c02baebb288227c582044aa76adf6a"
TW_CID = "kimne78kx3ncx6brgo4mv6wki5h1ko"

def say(m): print(m, flush=True)
def die(m): say(m); sys.exit(1)
def hms(s): s = int(max(0, s)); return "%d:%02d:%02d" % (s // 3600, s % 3600 // 60, s % 60)
def q(cmd): return subprocess.run(cmd, capture_output=True, text=True)

def fuente(src):
    if os.path.isfile(src):
        b = os.path.splitext(os.path.basename(src))[0]
        n = b.split("_vod_")[0] if "_vod_" in b else b.rsplit("_", 1)[0]
        return {"name": n or "vod", "file": os.path.abspath(src), "url": None, "id": re.sub(r"\W", "", b)[:40], "plat": "archivo"}
    r = q(["yt-dlp", "--force-ipv4", "--no-warnings", "--skip-download", "-O", "%(is_live)s", "-O", "%(uploader_id)s", "-O", "%(id)s", src])
    L = r.stdout.strip().splitlines()
    if len(L) < 3: die("No pude abrir ese VOD. Revisa el link (si sigue fallando: brew upgrade yt-dlp).")
    if L[0] == "True": die("Ese directo sigue en vivo. Espera a que termine.")
    n = L[1]
    m = re.search(r"kick\.com/([^/?#]+)/videos/", src)
    if m: n = m.group(1)
    n = re.sub(r"[^a-z0-9_]", "", n.lstrip("@").lower())
    if not n or n == "na": n = "vod"
    plat = "twitch" if "twitch.tv" in src else "youtube" if ("youtube.com" in src or "youtu.be" in src) else "kick" if "kick.com" in src else "otro"
    return {"name": n, "file": None, "url": src, "id": L[2], "plat": plat}

def audio(f, work):
    wav = os.path.join(work, "audio.wav")
    if os.path.exists(wav) and os.path.getsize(wav) > 100000:
        say("1/4 Audio ya descargado antes, lo reutilizo."); return wav
    src = f["file"]
    if not src:
        say("1/4 Descargando solo el audio del VOD (pesa poco, tarda unos minutos)...")
        for x in os.listdir(work):
            if x.startswith("audio_src"): os.remove(os.path.join(work, x))
        r = subprocess.run(["yt-dlp", "--force-ipv4", "--no-warnings", "-N", "8", "-f", "ba/w", "-o", os.path.join(work, "audio_src.%(ext)s"), f["url"]])
        got = [x for x in os.listdir(work) if x.startswith("audio_src") and not x.endswith(".part")]
        if r.returncode != 0 or not got: die("No pude descargar el audio del VOD.")
        src = os.path.join(work, got[0])
    else:
        say("1/4 Leyendo el audio del archivo...")
    r = q(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", src, "-vn", "-ac", "1", "-ar", "16000", wav])
    if r.returncode != 0: die("No pude leer el audio: " + r.stderr[-300:])
    if not f["file"]: os.remove(src)
    return wav

def volumen(wav, work):
    out = os.path.join(work, "rms.txt")
    q(["ffmpeg", "-nostdin", "-hide_banner", "-loglevel", "error", "-i", wav, "-af",
       "asetnsamples=n=16000,astats=metadata=1:reset=1,ametadata=mode=print:key=lavfi.astats.Overall.RMS_level:file=" + out, "-f", "null", "-"])
    v = []
    for line in open(out):
        if "RMS_level=" in line:
            try: v.append(max(-90.0, float(line.split("=", 1)[1])))
            except ValueError: v.append(-90.0)
    return v

def chat_youtube(f, work):
    base = os.path.join(work, "chat")
    q(["yt-dlp", "--force-ipv4", "--no-warnings", "--skip-download", "--write-subs", "--sub-langs", "live_chat", "-o", base, f["url"]])
    p = base + ".live_chat.json"
    if not os.path.exists(p): return None
    out = []
    for line in open(p, encoding="utf-8"):
        try: o = json.loads(line)
        except ValueError: continue
        a = o.get("replayChatItemAction", {})
        t = a.get("videoOffsetTimeMsec")
        if t is None: continue
        txt = ""
        for act in a.get("actions", []):
            it = act.get("addChatItemAction", {}).get("item", {})
            for k in ("liveChatTextMessageRenderer", "liveChatPaidMessageRenderer"):
                for run in it.get(k, {}).get("message", {}).get("runs", []):
                    txt += run.get("text") or run.get("emoji", {}).get("emojiId", "")
        out.append((int(t) / 1000.0, txt))
    return out or None

def chat_twitch(f):
    vid = re.sub(r"\D", "", f["id"])
    out, cursor = [], None
    try:
        for page in range(5000):
            var = {"videoID": vid}
            if cursor: var["cursor"] = cursor
            else: var["contentOffsetSeconds"] = 0
            body = json.dumps([{"operationName": "VideoCommentsByOffsetOrCursor", "variables": var,
                                "extensions": {"persistedQuery": {"version": 1, "sha256Hash": TW_HASH}}}]).encode()
            req = urllib.request.Request("https://gql.twitch.tv/gql", data=body, headers={"Client-ID": TW_CID, "Content-Type": "text/plain;charset=UTF-8"})
            c = json.load(urllib.request.urlopen(req, timeout=20))[0]["data"]["video"]["comments"]
            for e in c["edges"]:
                nd = e["node"]
                out.append((float(nd["contentOffsetSeconds"]), "".join((fr.get("text") or "") for fr in nd["message"]["fragments"])))
                cursor = e.get("cursor") or cursor
            if page % 100 == 99: say("   chat descargado hasta %s..." % hms(out[-1][0]))
            if not c["pageInfo"]["hasNextPage"] or not cursor: break
    except Exception:
        pass
    return out or None

def chat(f, work):
    if f["plat"] == "youtube": return chat_youtube(f, work)
    if f["plat"] == "twitch": return chat_twitch(f)
    return None

def mediana_movil(x, atras, paso=10, inicio=60):
    N = len(x); out = [0.0] * N
    for i in range(0, N, paso):
        w = x[max(0, i - atras):i] or x[:inicio]
        m = statistics.median(w)
        for j in range(i, min(N, i + paso)): out[j] = m
    return out

def puntuar(v, msgs):
    N = len(v)
    sm = [sum(v[max(0, i - 1):i + 2]) / len(v[max(0, i - 1):i + 2]) for i in range(N)]
    base = mediana_movil(sm, 120)
    A = [max(0.0, sm[i] - base[i]) for i in range(N)]
    CH = [0.0] * N; WIN = [0] * N; WR = [0] * N; CB = [0.0] * N
    if msgs:
        per = [0] * (N + 1); rs = [0] * (N + 1)
        for t, m in msgs:
            k = int(t)
            if 0 <= k < N:
                per[k] += 1
                if RISA.search(m or ""): rs[k] += 1
        W = 20  # el chat reacciona en los 20 s siguientes al momento
        s = sum(per[:W]); r = sum(rs[:W])
        for i in range(N):
            WIN[i] = s; WR[i] = r
            if i + W < N: s += per[i + W]; r += rs[i + W]
            s -= per[i]; r -= rs[i]
        CB = mediana_movil(WIN, 300)
        CH = [max(0.0, WIN[i] + WR[i] - CB[i]) / (CB[i] + 3.0) for i in range(N)]
    def norm(x):
        s = sorted(x); p = s[min(len(s) - 1, int(len(s) * 0.995))] if s else 0
        return [min(1.5, y / p) if p > 0 else 0.0 for y in x]
    an = norm(A); cn = norm(CH) if msgs else [0.0] * N
    S = [an[i] + 1.5 * cn[i] for i in range(N)]
    return S, A, WIN, WR, CB

def elegir(S, n, gap=150):
    sel = []
    for i in sorted(range(len(S)), key=lambda i: -S[i]):
        if S[i] < 0.15 or len(sel) >= n: break
        if all(abs(i - j) >= gap for j in sel): sel.append(i)
    return sel

def transcribir(wav, work, cands):
    wh = shutil.which("whisper-cli")
    if not wh or not os.path.exists(MODEL):
        say("3/4 (sin transcripción: no encuentro whisper)"); return
    for k, c in enumerate(cands, 1):
        say("3/4 Transcribiendo momento %d de %d..." % (k, len(cands)))
        seg = os.path.join(work, "seg%d" % k)
        q(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-ss", str(c["ini"]), "-t", str(c["fin"] - c["ini"]), "-i", wav, seg + ".wav"])
        q([wh, "-m", MODEL, "-f", seg + ".wav", "-l", "auto", "-nt", "-np", "-otxt", "-of", seg])
        try: c["texto"] = " ".join(open(seg + ".txt", encoding="utf-8").read().split())
        except OSError: pass
        for x in (seg + ".wav", seg + ".txt"):
            if os.path.exists(x): os.remove(x)

def enlace(f, t):
    t = int(max(0, t))
    if f["plat"] == "twitch": return "https://www.twitch.tv/videos/%s?t=%dh%02dm%02ds" % (re.sub(r"\D", "", f["id"]), t // 3600, t % 3600 // 60, t % 60)
    if f["plat"] == "youtube": return "https://www.youtube.com/watch?v=%s&t=%ds" % (f["id"], t)
    if f["url"]: return f["url"].split("?")[0] + "?t=%d" % t
    return None

def informe(f, cands, con_chat):
    stamp = time.strftime("%Y%m%d_%H%M")
    base = os.path.join(OUTDIR, "%s_%s" % (f["name"], stamp))
    src = f["url"] or f["file"]
    top = max([c["score"] for c in cands] or [1]) or 1
    txt = ["Momentos con potencial de clip · %s · %s" % (f["name"], src),
           "Señales: volumen%s%s" % (" + chat" if con_chat else "", " + transcripción" if any(c["texto"] for c in cands) else ""), ""]
    cards = []
    for k, c in enumerate(cands, 1):
        cmd = 'clipvod "%s" %s %s' % (src, hms(c["ini"]), hms(c["fin"]))
        link = enlace(f, c["pico"] - 30)
        txt += ["#%d  %s → %s  (pico %s)  puntos %.2f  %s" % (k, hms(c["ini"]), hms(c["fin"]), hms(c["pico"]), c["score"], " · ".join(c["razones"])),
                "    %s" % (c["texto"] or "(sin transcripción)"), "    %s" % cmd, ""]
        cards.append(
            '<article><header><span class="n">#%d</span><b>%s → %s</b><span class="bar"><i style="width:%d%%"></i></span></header>'
            '<p class="why">%s</p><p class="tx">%s</p><div class="acts">%s<code>%s</code><button onclick="cp(this)">Copiar</button></div></article>'
            % (k, hms(c["ini"]), hms(c["fin"]), int(100 * c["score"] / top), H.escape(" · ".join(c["razones"]) or "Subida de intensidad"),
               H.escape(c["texto"] or "(sin transcripción)"),
               ('<a href="%s" target="_blank">▶ Ver en el VOD</a>' % H.escape(link)) if link else "", H.escape(cmd)))
    open(base + ".txt", "w", encoding="utf-8").write("\n".join(txt))
    page = ("<!doctype html><meta charset=utf-8><meta name=viewport content='width=device-width,initial-scale=1'><title>Clips de %s</title>"
            "<style>body{margin:0;padding:20px max(16px,4vw);background:#141118;color:#f2eef7;font:15px/1.5 -apple-system,Segoe UI,sans-serif}"
            "h1{font-size:1.6rem;margin:0 0 4px}.sub{color:#a49cb1;margin:0 0 20px}article{background:#1d1923;border:1px solid #2f2939;border-radius:14px;padding:14px;margin:0 0 12px;max-width:820px}"
            "header{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.n{color:#ff5596;font-weight:800}.bar{flex:1;min-width:80px;height:6px;background:#2f2939;border-radius:9px;overflow:hidden}.bar i{display:block;height:100%%;background:#ff5596}"
            ".why{margin:8px 0 4px;color:#43d1a2;font-weight:600}.tx{margin:0 0 10px;color:#d8d2e2}.acts{display:flex;gap:8px;align-items:center;flex-wrap:wrap}"
            "a{background:#ff5596;color:#1b0b12;font-weight:700;text-decoration:none;border-radius:99px;padding:6px 12px}code{flex:1;min-width:0;overflow-x:auto;white-space:nowrap;background:#141118;border:1px solid #2f2939;border-radius:8px;padding:6px 8px;font:12px Menlo,monospace}"
            "button{background:#2f2939;color:#f2eef7;border:0;border-radius:99px;padding:6px 12px;font-weight:600;cursor:pointer}</style>"
            "<h1>Clips de %s</h1><p class=sub>%d momentos ordenados por potencial · señales: volumen%s · Abre el VOD en el momento y pulsa ⌃⌥C, o copia el comando en la Terminal.</p>%s"
            "<script>function cp(b){var t=b.previousElementSibling.textContent;function ok(){b.textContent='Copiado'}"
            "try{navigator.clipboard.writeText(t).then(ok,function(){})}catch(e){}}</script>"
            % (H.escape(f["name"]), H.escape(f["name"]), len(cands), " + chat" if con_chat else "", "".join(cards)))
    open(base + ".html", "w", encoding="utf-8").write(page)
    return base

def cortar(f, cands):
    dest = os.path.join(CLIPS, "listos", f["name"].upper(), "sugeridos"); os.makedirs(dest, exist_ok=True)
    if f["file"]: u1 = u2 = f["file"]
    else:
        U = q(["yt-dlp", "--force-ipv4", "--no-warnings", "-f", "bv*[height<=1080]+ba/b[height<=1080]/b", "-O", "%(urls)s", f["url"]]).stdout.strip().splitlines()
        if not U: say("No pude preparar el video para cortar."); return
        u1 = U[0]; u2 = U[1] if len(U) > 1 else U[0]
    try: d = open(os.path.join(CLIPS, ".desfase_" + f["name"])).read().strip() or "0"
    except OSError: d = "0"
    for k, c in enumerate(cands, 1):
        say("4/4 Cortando clip %d de %d..." % (k, len(cands)))
        out = os.path.join(dest, "%s_%s.mp4" % (f["name"], hms(c["ini"]).replace(":", "")))
        r = q(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-fflags", "+genpts", "-ss", str(c["ini"]), "-i", u1, "-ss", str(c["ini"]), "-itsoffset", d, "-i", u2,
               "-t", str(c["fin"] - c["ini"]), "-map", "0:v:0", "-map", "1:a:0", "-c:v", ENC, "-b:v", "25M", "-maxrate", "30M", "-bufsize", "60M",
               "-af", "aresample=async=1:first_pts=0", "-c:a", "aac", "-b:a", "192k", "-avoid_negative_ts", "make_zero", out])
        if r.returncode != 0: say("   (no pude cortar el #%d)" % k)
    return dest

def main():
    a = sys.argv[1:]
    if not a: die("Uso: buscaclips LINK-o-ARCHIVO [CUANTOS] [cortar]   Ej: buscaclips https://www.twitch.tv/videos/123 15")
    n, cut = 15, False
    for x in a[1:]:
        if x.isdigit(): n = max(1, min(50, int(x)))
        elif x.lower() == "cortar": cut = True
    os.makedirs(WORKROOT, exist_ok=True); os.makedirs(OUTDIR, exist_ok=True)
    for x in os.listdir(WORKROOT):
        p = os.path.join(WORKROOT, x)
        if time.time() - os.path.getmtime(p) > 2 * 86400: shutil.rmtree(p, ignore_errors=True)
    f = fuente(a[0])
    say("Buscando clips en el VOD de %s..." % f["name"])
    work = os.path.join(WORKROOT, "%s_%s" % (f["name"], re.sub(r"\W", "", f["id"])[:40])); os.makedirs(work, exist_ok=True)
    wav = audio(f, work)
    say("2/4 Analizando volumen y chat...")
    v = volumen(wav, work)
    if len(v) < 180: die("El video es muy corto para buscar clips.")
    msgs = chat(f, work)
    say("   Chat: %s" % ("%d mensajes" % len(msgs) if msgs else "no disponible, uso solo el audio"))
    S, A, WIN, WR, CB = puntuar(v, msgs)
    cands = []
    for i in elegir(S, n):
        why = []
        if A[i] >= 3: why.append("🔊 sube %d dB de golpe" % round(A[i]))
        if msgs and WIN[i] > CB[i] * 1.5 + 2: why.append("💬 chat x%.1f (%d mensajes en 20 s)" % ((WIN[i] + 1.0) / (CB[i] + 1.0), WIN[i]))
        if msgs and WR[i] >= 3: why.append("😂 %d risas en el chat" % WR[i])
        cands.append({"pico": i, "ini": max(0, i - 60), "fin": min(len(v), i + 25), "score": S[i], "razones": why, "texto": ""})
    transcribir(wav, work, cands)
    base = informe(f, cands, bool(msgs))
    say("Listo ✅ %d momentos. Informe: %s.html" % (len(cands), base))
    if cut:
        dest = cortar(f, cands)
        if dest: say("Clips sugeridos en: %s" % dest); subprocess.run(["open", dest]) if sys.platform == "darwin" else None
    if sys.platform == "darwin": subprocess.run(["open", base + ".html"])

if __name__ == "__main__":
    main()
