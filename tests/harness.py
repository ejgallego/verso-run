"""Small shared utilities; assertions and browser scenarios stay in their suites."""
from contextlib import contextmanager
from functools import partial
import http.server
from pathlib import Path
import subprocess
import threading


def run_command(arguments, log, expected=0, *, output, cwd):
    """Stream merged output to a log and return it for diagnostic assertions."""
    path = Path(output) / (log + '.log')
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('w') as stream:
        result = subprocess.run(arguments, cwd=cwd, text=True,
                                stdout=stream, stderr=subprocess.STDOUT)
    text = path.read_text()
    assert (result.returncode == 0) == (expected == 0), (
        f'{arguments} exited {result.returncode}; see {path}\n{text[-5000:]}')
    return text


def inventory(path):
    """Compare names and bytes independently of filesystem enumeration order."""
    path = Path(path)
    return {file.relative_to(path): file.read_bytes()
            for file in path.rglob('*') if file.is_file()}


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def handle(self):
        try:
            super().handle()
        except (BrokenPipeError, ConnectionResetError):
            pass


@contextmanager
def serve_directory(directory):
    """Own the HTTP listener and its thread, including exceptional exits."""
    server = http.server.ThreadingHTTPServer(
        ('127.0.0.1', 0), partial(QuietHandler, directory=str(directory)))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        yield f'http://127.0.0.1:{server.server_port}/'
    finally:
        server.shutdown()
        server.server_close()
        thread.join()
