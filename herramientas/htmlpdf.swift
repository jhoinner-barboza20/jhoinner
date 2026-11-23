// htmlpdf: convierte una página HTML de tamaño carta en PDF usando WebKit (el motor de Safari).
// Uso: htmlpdf entrada.html salida.pdf      Compilar: swiftc -O -parse-as-library htmlpdf.swift -o htmlpdf
import Cocoa
import WebKit

@MainActor
final class Loader: NSObject, WKNavigationDelegate {
    let out: URL
    init(out: URL) { self.out = out }
    static func fallo(_ m: String) -> Never { FileHandle.standardError.write(Data((m + "\n").utf8)); exit(1) }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            let cfg = WKPDFConfiguration()
            cfg.rect = CGRect(x: 0, y: 0, width: 612, height: 792)
            do {
                let data = try await webView.pdf(configuration: cfg)
                try data.write(to: self.out)
                exit(0)
            } catch { Loader.fallo("No pude crear el PDF: \(error.localizedDescription)") }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Loader.fallo("Error al cargar: \(error.localizedDescription)")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Loader.fallo("Error al cargar: \(error.localizedDescription)")
    }
}

@main
struct HTMLPDF {
    @MainActor static func main() {
        let args = CommandLine.arguments
        if args.count < 3 { Loader.fallo("Uso: htmlpdf entrada.html salida.pdf") }
        let inURL = URL(fileURLWithPath: args[1])
        let loader = Loader(out: URL(fileURLWithPath: args[2]))
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
        web.pageZoom = 0.75   // 816 px CSS (8,5 pulgadas) -> 612 puntos = tamaño carta
        let win = NSWindow(contentRect: NSRect(x: -30000, y: -30000, width: 612, height: 792),
                           styleMask: [.borderless], backing: .buffered, defer: false)
        win.contentView = web
        win.orderBack(nil)
        web.navigationDelegate = loader
        web.loadFileURL(inURL, allowingReadAccessTo: inURL.deletingLastPathComponent())
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            Loader.fallo("Tiempo agotado creando el PDF")
        }
        withExtendedLifetime((loader, win)) { app.run() }
    }
}
