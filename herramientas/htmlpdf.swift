// htmlpdf: convierte una página HTML de tamaño carta en PDF usando WebKit (el motor de Safari).
// Uso: htmlpdf entrada.html salida.pdf
import Cocoa
import WebKit

let args = CommandLine.arguments
if args.count < 3 { fputs("Uso: htmlpdf entrada.html salida.pdf\n", stderr); exit(2) }
let inURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[2])

final class Loader: NSObject, WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            let cfg = WKPDFConfiguration()
            cfg.rect = CGRect(x: 0, y: 0, width: 612, height: 792)
            webView.createPDF(configuration: cfg) { result in
                switch result {
                case .success(let data):
                    do { try data.write(to: outURL); exit(0) }
                    catch { fputs("No pude guardar el PDF: \(error.localizedDescription)\n", stderr); exit(1) }
                case .failure(let e):
                    fputs("No pude crear el PDF: \(e.localizedDescription)\n", stderr); exit(1)
                }
            }
        }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fputs("Error al cargar: \(error.localizedDescription)\n", stderr); exit(1)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fputs("Error al cargar: \(error.localizedDescription)\n", stderr); exit(1)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 612, height: 792))
web.pageZoom = 0.75   // 816 px CSS (8,5 pulgadas) -> 612 puntos = tamaño carta
let win = NSWindow(contentRect: NSRect(x: -30000, y: -30000, width: 612, height: 792),
                   styleMask: [.borderless], backing: .buffered, defer: false)
win.contentView = web
win.orderFrontRegardless()
let loader = Loader()
web.navigationDelegate = loader
web.loadFileURL(inURL, allowingReadAccessTo: inURL.deletingLastPathComponent())
DispatchQueue.main.asyncAfter(deadline: .now() + 45) { fputs("Tiempo agotado creando el PDF\n", stderr); exit(1) }
app.run()
