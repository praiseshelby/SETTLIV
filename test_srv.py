
import http.server
import socketserver
import os
import sys

DIRECTORY = r"C:\Users\shelb\Downloads\SETTLIV-X\build\web"

class ThreadingHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

try:
    server = ThreadingHTTPServer(("", 3000), Handler)
    print("SERVER STARTED SUCCESSFULLY")
    server.serve_forever()
except Exception as e:
    import traceback
    traceback.print_exc()
