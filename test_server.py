
import http.server
import socketserver
import os

os.chdir(r"C:\Users\shelb\Downloads\SETTLIV-X\build\web")
class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        super().end_headers()

with socketserver.TCPServer(("", 3000), Handler) as httpd:
    print("Serving on 3000")
    httpd.handle_request()
    print("Handled one request successfully")
