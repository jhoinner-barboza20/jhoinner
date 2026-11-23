// Seraf Acuerdos: app para crear el acuerdo de servicio en PDF de cada cliente.
import SwiftUI
import WebKit
import AppKit

// MARK: - Planes
enum Plan: String, CaseIterable, Identifiable {
    case prueba, basico, pro, elite
    var id: String { rawValue }
    var nombre: String {
        switch self { case .prueba: return "Prueba"; case .basico: return "Básico"; case .pro: return "Pro"; case .elite: return "Élite" }
    }
    var precio: Int {
        switch self { case .prueba: return 39; case .basico: return 129; case .pro: return 269; case .elite: return 389 }
    }
    var dias: Int { self == .prueba ? 7 : 30 }
    var mensual: Bool { self != .prueba }
    var incluye: String {
        switch self {
        case .prueba: return "Hasta 4 clips por cada día de directo (máximo 28), editados en vertical con subtítulos y gancho, en alta resolución. Te los dejamos el mismo día en tu carpeta de Drive. El día de directo cierra a las 6:00 a. m."
        case .basico: return "Hasta 4 clips por cada día de directo (unos 120 al mes), editados en vertical con subtítulos y gancho, en alta resolución. Se publican solos en tus redes con título, hashtags y en los mejores horarios, y tienes una copia en tu carpeta de Drive."
        case .pro: return "Hasta 6 clips por cada día de directo (unos 180 al mes), sacados en vivo mientras transmites, con edición dinámica y en alta resolución. Se publican solos en tus redes; recibes un reporte de crecimiento y tienes chat directo con el equipo por WhatsApp."
        case .elite: return "Todo lo del plan Pro, más edición premium en tus mejores clips, portadas para cada publicación, hasta 4 videos largos al mes para YouTube con sus miniaturas, estrategia de contenido y una videollamada mensual. Tus entregas tienen prioridad."
        }
    }
}

// MARK: - Fechas en español
enum Fechas {
    static let meses = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre"]
    static let mc = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
    static let dias = ["domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado"]
    static var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = .current; return c }
    static func partes(_ d: Date) -> (dia: Int, mes: Int, anio: Int, semana: Int) {
        let c = cal.dateComponents([.day, .month, .year, .weekday], from: d)
        return (c.day ?? 1, c.month ?? 1, c.year ?? 2026, c.weekday ?? 1)
    }
    static func mas(_ d: Date, _ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: d) ?? d }
    static func corta(_ d: Date) -> String { let p = partes(d); return "\(p.dia) \(mc[p.mes - 1])" }
    static func larga(_ d: Date) -> String { let p = partes(d); return "\(p.dia) de \(meses[p.mes - 1]) de \(p.anio)" }
    static func diaSemana(_ d: Date) -> String { dias[partes(d).semana - 1] }
    static func periodo(_ a: Date, _ b: Date) -> String {
        let pa = partes(a), pb = partes(b)
        if pa.mes == pb.mes && pa.anio == pb.anio { return "\(pa.dia) – \(pb.dia) \(mc[pb.mes - 1]) \(pb.anio)" }
        return "\(corta(a)) – \(corta(b)) \(pb.anio)"
    }
}

// MARK: - Acuerdo
struct Datos {
    var nombre: String
    var canal: String
    var plan: Plan
    var precio: Int
    var inicio: Date
    var fin: Date { Fechas.mas(inicio, plan.dias - 1) }
    var renueva: Date { Fechas.mas(inicio, plan.dias) }
    var resumen: String {
        let base = "\(plan.nombre) · US$\(precio) · \(Fechas.periodo(inicio, fin))"
        if plan.mensual { return base + " · renueva el \(Fechas.corta(renueva))" }
        return base + " · \(Fechas.diaSemana(inicio).capitalized) a \(Fechas.diaSemana(fin))"
    }
    var archivo: String { "Acuerdo Seraf Clips - \(nombre) (\(Fechas.corta(inicio)) \(Fechas.partes(inicio).anio)).pdf" }
}

enum Acuerdo {
    static let plantilla: String = {
        if let u = Bundle.main.url(forResource: "acuerdo_plantilla", withExtension: "html"),
           let s = try? String(contentsOf: u, encoding: .utf8) { return s }
        let alt = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("clipstools/acuerdo_plantilla.html")
        return (try? String(contentsOf: alt, encoding: .utf8)) ?? "<html><body><h1>Falta la plantilla del acuerdo</h1></body></html>"
    }()
    static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    static func html(_ d: Datos) -> String {
        var necesitamos = "El link de tu canal y tu horario de directos. Avísanos si un día no transmites y dinos qué temas o momentos no quieres ver en clips."
        let pagos: String
        if d.plan.mensual {
            necesitamos += " Conecta tus redes con el enlace seguro que te enviamos, sin darnos contraseñas."
            pagos = "Todo se paga por adelantado. Tu plan se renueva cada 30 días; el próximo pago es el \(Fechas.corta(d.renueva)). Sin pago, el servicio se pausa al día siguiente."
        } else {
            pagos = "Todo se paga por adelantado. Si pasas a un plan mensual durante tu semana de prueba, te descontamos los US$\(d.precio) del primer mes. Los planes mensuales se renuevan en su fecha; sin pago, el servicio se pausa al día siguiente."
        }
        var canal = d.canal.trimmingCharacters(in: .whitespaces)
        if !canal.isEmpty && !canal.hasPrefix("@") && !canal.contains(".") { canal = "@" + canal }
        let valores: [String: String] = [
            "CLIENTE": d.nombre.isEmpty ? "Nombre del cliente" : d.nombre,
            "CANAL": canal.isEmpty ? "Cliente de Seraf Clips" : canal,
            "PLAN": d.plan.nombre, "PLAN_SUB": d.plan.mensual ? "Mensual" : "7 días",
            "PRECIO": "US$\(d.precio)", "PRECIO_SUB": d.plan.mensual ? "Al mes, por adelantado" : "Pagado por adelantado",
            "PERIODO": Fechas.periodo(d.inicio, d.fin),
            "PERIODO_SUB": d.plan.mensual ? "Renueva el \(Fechas.corta(d.renueva))" : "\(Fechas.diaSemana(d.inicio).capitalized) a \(Fechas.diaSemana(d.fin))",
            "FECHA": Fechas.larga(Date()),
            "INCLUYE": d.plan.incluye, "NECESITAMOS": necesitamos, "PAGOS": pagos,
        ]
        var s = plantilla
        for (k, v) in valores { s = s.replacingOccurrences(of: "{{\(k)}}", with: esc(v)) }
        return s
    }
    static func carpeta() -> URL {
        let fm = FileManager.default
        let cs = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/CloudStorage")
        if let items = try? fm.contentsOfDirectory(atPath: cs.path) {
            for it in items.sorted() where it.hasPrefix("GoogleDrive-") {
                let seraf = cs.appendingPathComponent(it).appendingPathComponent("Mi unidad").appendingPathComponent("Seraf Clips")
                if fm.fileExists(atPath: seraf.path) { return seraf.appendingPathComponent("ACUERDOS") }
            }
        }
        return fm.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/Clips/ACUERDOS")
    }
}

// MARK: - PDF con WebKit
@MainActor
final class PDFMaker: NSObject, WKNavigationDelegate {
    private var web: WKWebView?
    private var win: NSWindow?
    private var done: ((Result<Data, Error>) -> Void)?

    func make(html: String, done: @escaping (Result<Data, Error>) -> Void) {
        self.done = done
        let w = WKWebView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        w.pageZoom = 0.75
        let win = NSWindow(contentRect: NSRect(x: -30000, y: -30000, width: 612, height: 792),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.isExcludedFromWindowsMenu = true
        win.contentView = w
        win.orderBack(nil)
        w.navigationDelegate = self
        web = w; self.win = win
        w.loadHTMLString(html, baseURL: nil)
    }
    private func finish(_ r: Result<Data, Error>) {
        let d = done; done = nil
        win?.orderOut(nil); web = nil; win = nil
        d?(r)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            let cfg = WKPDFConfiguration()
            cfg.rect = CGRect(x: 0, y: 0, width: 612, height: 792)
            do { finish(.success(try await webView.pdf(configuration: cfg))) }
            catch { finish(.failure(error)) }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(error)) }
}

// MARK: - Vista previa
struct Vista: NSViewRepresentable {
    let html: String
    final class Coord { var ultimo = "" }
    func makeCoordinator() -> Coord { Coord() }
    func makeNSView(context: Context) -> WKWebView {
        let w = WKWebView()
        w.pageZoom = 0.6
        context.coordinator.ultimo = html
        w.loadHTMLString(html, baseURL: nil)
        return w
    }
    func updateNSView(_ w: WKWebView, context: Context) {
        if context.coordinator.ultimo != html {
            context.coordinator.ultimo = html
            w.loadHTMLString(html, baseURL: nil)
        }
    }
}

// MARK: - Pantalla
let morado = Color(red: 0.502, green: 0.012, blue: 0.961)
let naranja = Color(red: 0.996, green: 0.318, blue: 0.016)

struct Principal: View {
    @State private var nombre = ""
    @State private var canal = ""
    @State private var plan: Plan = .prueba
    @State private var precio = Plan.prueba.precio
    @State private var inicio = Date()
    @State private var estado = ""
    @State private var ultimo: URL?
    @State private var generando = false
    @State private var maker = PDFMaker()

    private var limpio: String {
        nombre.trimmingCharacters(in: .whitespaces).split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
    private var datos: Datos { Datos(nombre: limpio, canal: canal, plan: plan, precio: precio, inicio: inicio) }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    if let u = Bundle.main.url(forResource: "logo", withExtension: "png"), let img = NSImage(contentsOf: u) {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fit).frame(width: 74)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SERAF CLIPS").font(.system(size: 11, weight: .heavy)).kerning(1.6).foregroundColor(.white.opacity(0.85))
                        Text("Acuerdos").font(.system(size: 26, weight: .black)).foregroundColor(.white)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(morado))

                campo("Nombre del cliente") { TextField("Ej: Joanse", text: $nombre).textFieldStyle(.roundedBorder) }
                campo("Canal (opcional)") { TextField("Ej: @joanseee o kick.com/joanseee", text: $canal).textFieldStyle(.roundedBorder) }
                campo("Plan que pagó") {
                    Picker("", selection: $plan) { ForEach(Plan.allCases) { p in Text(p.nombre).tag(p) } }
                        .pickerStyle(.segmented).labelsHidden()
                }
                HStack(alignment: .top, spacing: 14) {
                    campo("Precio (US$)") { TextField("", value: $precio, format: .number).textFieldStyle(.roundedBorder).frame(width: 90) }
                    campo("Empieza el") { DatePicker("", selection: $inicio, displayedComponents: .date).labelsHidden() }
                }
                Text(datos.resumen).font(.callout).foregroundColor(.secondary)

                Spacer()

                Button(action: generar) {
                    Text(limpio.isEmpty ? "Generar acuerdo" : "Generar acuerdo de \(limpio)")
                        .font(.system(size: 15, weight: .bold)).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent).tint(morado).controlSize(.large)
                .disabled(limpio.isEmpty || generando)
                .keyboardShortcut(.defaultAction)

                if !estado.isEmpty { Text(estado).font(.callout).fixedSize(horizontal: false, vertical: true) }
                if let u = ultimo {
                    HStack {
                        Button("Abrir PDF") { NSWorkspace.shared.open(u) }
                        Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([u]) }
                        Button("Copiar mensaje") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString("Te paso el acuerdo de tu plan para que tengas claro todo lo que incluye 🙌 Si estás de acuerdo, respóndeme «Acepto» y arrancamos", forType: .string)
                            estado = "📋 Mensaje copiado: pégalo en WhatsApp junto al PDF."
                        }
                    }
                }
            }
            .padding(24).frame(width: 400)
            .onChange(of: plan) { nuevo in precio = nuevo.precio }

            ZStack {
                Color(nsColor: .underPageBackgroundColor)
                Vista(html: Acuerdo.html(datos))
                    .frame(width: 490, height: 634)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            }
            .frame(minWidth: 560, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 700)
        .environment(\.locale, Locale(identifier: "es_ES"))
    }

    private func campo<C: View>(_ t: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
            c()
        }
    }

    private func generar() {
        let d = datos
        guard !d.nombre.isEmpty else { return }
        generando = true; ultimo = nil
        estado = "Creando el acuerdo de \(d.nombre)…"
        maker.make(html: Acuerdo.html(d)) { r in
            generando = false
            switch r {
            case .success(let data):
                do {
                    let dir = Acuerdo.carpeta().appendingPathComponent("Acuerdo de \(d.nombre)")
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let url = dir.appendingPathComponent(d.archivo)
                    try data.write(to: url)
                    ultimo = url
                    estado = "✅ Listo: ACUERDOS › Acuerdo de \(d.nombre) › \(url.lastPathComponent)"
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } catch {
                    estado = "No pude guardar el PDF: \(error.localizedDescription)"
                }
            case .failure(let e):
                estado = "No pude crear el PDF: \(e.localizedDescription)"
            }
        }
    }
}

@main
struct SerafAcuerdosApp: App {
    var body: some Scene {
        WindowGroup("Seraf Acuerdos") { Principal() }
            .defaultSize(width: 1000, height: 720)
    }
}
