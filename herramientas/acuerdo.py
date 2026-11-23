#!/usr/bin/env python3
"""Seraf Clips · acuerdo CLIENTE: crea el acuerdo de servicio en PDF con los datos de 'clientes'."""
import sys, os, html, shutil, tempfile, subprocess, datetime, time

HOME = os.path.expanduser("~")
C = os.path.join(HOME, "Desktop", "Clips")
PLANTILLA = os.path.join(HOME, "clipstools", "acuerdo_plantilla.html")
MESES = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
MC = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
DIAS = ["lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo"]
PLANES = {
    "prueba": ("Prueba", "7 días",
               "Hasta 4 clips por cada día de directo (máximo 28), editados en vertical con subtítulos y gancho, en alta resolución. Te los dejamos el mismo día en tu carpeta de Drive. El día de directo cierra a las 6:00 a. m."),
    "basico": ("Básico", "Mensual",
               "Hasta 4 clips por cada día de directo (unos 120 al mes), editados en vertical con subtítulos y gancho, en alta resolución. Se publican solos en tus redes con título, hashtags y en los mejores horarios, y tienes una copia en tu carpeta de Drive."),
    "pro": ("Pro", "Mensual",
            "Hasta 6 clips por cada día de directo (unos 180 al mes), sacados en vivo mientras transmites, con edición dinámica y en alta resolución. Se publican solos en tus redes; recibes un reporte de crecimiento y tienes chat directo con el equipo por WhatsApp."),
    "elite": ("Élite", "Mensual",
              "Todo lo del plan Pro, más edición premium en tus mejores clips, portadas para cada publicación, hasta 4 videos largos al mes para YouTube con sus miniaturas, estrategia de contenido y una videollamada mensual. Tus entregas tienen prioridad."),
}
NAVEGADORES = ["/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
               "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
               "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"]

def die(m):
    print(m); sys.exit(1)

def corta(d): return f"{d.day} {MC[d.month - 1]}"

def periodo(d1, d2):
    if d1.month == d2.month: return f"{d1.day} – {d2.day} {MC[d2.month - 1]} {d2.year}"
    return f"{corta(d1)} – {corta(d2)} {d2.year}"

def imprimir_con_navegador(nav, h, out, perfil):
    """Plan B: Brave/Chrome sin ventana. Si el navegador se queda colgado tras escribir el PDF, lo cerramos."""
    p = subprocess.Popen([nav, "--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
                          f"--user-data-dir={perfil}", "--no-pdf-header-footer", "--print-to-pdf-no-header",
                          f"--print-to-pdf={out}", "file://" + h], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    last, stable = -1, 0
    for _ in range(120):
        if p.poll() is not None: break
        size = os.path.getsize(out) if os.path.exists(out) else -1
        stable = stable + 1 if size > 1000 and size == last else 0
        last = size
        if stable >= 3: break
        time.sleep(0.5)
    if p.poll() is None:
        p.kill()
        try: p.wait(timeout=5)
        except subprocess.TimeoutExpired: pass
    subprocess.run(["pkill", "-f", perfil], capture_output=True)  # cierra procesos auxiliares que queden

def main():
    if len(sys.argv) < 2: die("Uso: acuerdo CLIENTE   (ej: acuerdo joanse)")
    n = sys.argv[1].upper()
    reg = os.path.join(C, "clientes.txt")
    filas = [l.rstrip("\n").split("\t") for l in open(reg, encoding="utf-8") if l.strip()] if os.path.exists(reg) else []
    filas = [f for f in filas if f[0] == n and len(f) >= 5]
    if not filas: die(f"No tengo a {n} apuntado. Primero: nuevocliente {n.lower()} PLAN FECHA")
    _, plan, ini, fin, precio = filas[-1][:5]
    if plan not in PLANES: die(f"Plan desconocido: {plan}")
    if not os.path.exists(PLANTILLA): die("No encuentro la plantilla del acuerdo en ~/clipstools.")
    d1 = datetime.date.fromisoformat(ini); d2 = datetime.date.fromisoformat(fin)
    nombre = n.capitalize()
    canal = ""
    vin = os.path.join(C, ".vinculos")
    if os.path.exists(vin):
        for l in open(vin, encoding="utf-8"):
            p = l.split()
            if len(p) >= 2 and p[0] == n: canal = "@" + p[1]
    pnom, psub, incluye = PLANES[plan]
    mensual = plan != "prueba"
    renueva = corta(d2 + datetime.timedelta(days=1))
    necesitamos = "El link de tu canal y tu horario de directos. Avísanos si un día no transmites y dinos qué temas o momentos no quieres ver en clips."
    if mensual:
        necesitamos += " Conecta tus redes con el enlace seguro que te enviamos, sin darnos contraseñas."
        pagos = f"Todo se paga por adelantado. Tu plan se renueva cada 30 días; el próximo pago es el {renueva}. Sin pago, el servicio se pausa al día siguiente."
    else:
        pagos = f"Todo se paga por adelantado. Si pasas a un plan mensual durante tu semana de prueba, te descontamos los US${precio} del primer mes. Los planes mensuales se renuevan en su fecha; sin pago, el servicio se pausa al día siguiente."
    hoy = datetime.date.today()
    datos = {
        "CLIENTE": nombre, "CANAL": canal or "Cliente de Seraf Clips",
        "PLAN": pnom, "PLAN_SUB": psub,
        "PRECIO": f"US${precio}", "PRECIO_SUB": "Al mes, por adelantado" if mensual else "Pagado por adelantado",
        "PERIODO": periodo(d1, d2),
        "PERIODO_SUB": f"Renueva el {renueva}" if mensual else f"{DIAS[d1.weekday()].capitalize()} a {DIAS[d2.weekday()]}",
        "FECHA": f"{hoy.day} de {MESES[hoy.month - 1]} de {hoy.year}",
        "INCLUYE": incluye, "NECESITAMOS": necesitamos, "PAGOS": pagos,
    }
    s = open(PLANTILLA, encoding="utf-8").read()
    for k, v in datos.items(): s = s.replace("{{" + k + "}}", html.escape(v))
    dest = os.path.join(C, "acuerdos"); os.makedirs(dest, exist_ok=True)
    out = os.path.join(dest, f"Acuerdo Seraf Clips - {nombre} ({corta(d1)} {d1.year}).pdf")
    tmp = tempfile.mkdtemp(prefix="seraf_acuerdo_")
    try:
        h = os.path.join(tmp, "acuerdo.html"); open(h, "w", encoding="utf-8").write(s)
        if os.path.exists(out): os.remove(out)
        hp = os.environ.get("SERAF_HTMLPDF") or os.path.join(HOME, "clipstools", "htmlpdf")
        if os.path.exists(hp):
            try: subprocess.run([hp, h, out], capture_output=True, timeout=60)
            except subprocess.TimeoutExpired: pass
        if not os.path.exists(out):
            nav = os.environ.get("SERAF_CHROME") or next((x for x in NAVEGADORES if os.path.exists(x)), None)
            if nav: imprimir_con_navegador(nav, h, out, os.path.join(tmp, "perfil"))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    if not os.path.exists(out) or os.path.getsize(out) < 1000:
        die("No pude crear el PDF. Compila el ayudante: swiftc -O ~/clipstools/htmlpdf.swift -o ~/clipstools/htmlpdf  y vuelve a probar.")
    print(f"✅ Acuerdo listo: {os.path.basename(out)}")
    print(f"   {pnom} · US${precio} · {datos['PERIODO']}")
    if sys.platform == "darwin": subprocess.run(["open", "-R", out])

if __name__ == "__main__":
    main()
