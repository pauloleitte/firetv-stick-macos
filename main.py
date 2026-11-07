"""Barra de menu do Mac para controlar o Fire TV Stick via ADB."""

import json
import os
import shutil
import subprocess

import rumps

HERE = os.path.dirname(os.path.abspath(__file__))
CONFIG_PATH = os.path.join(HERE, "config.json")

KEYS = {
    "Cima": "KEYCODE_DPAD_UP",
    "Baixo": "KEYCODE_DPAD_DOWN",
    "Esquerda": "KEYCODE_DPAD_LEFT",
    "Direita": "KEYCODE_DPAD_RIGHT",
    "OK": "KEYCODE_DPAD_CENTER",
    "Voltar": "KEYCODE_BACK",
    "Home": "KEYCODE_HOME",
    "Play/Pause": "KEYCODE_MEDIA_PLAY_PAUSE",
    "Volume +": "KEYCODE_VOLUME_UP",
    "Volume -": "KEYCODE_VOLUME_DOWN",
    "Mudo": "KEYCODE_VOLUME_MUTE",
}


def load_config():
    if not os.path.exists(CONFIG_PATH):
        raise RuntimeError(
            "config.json não encontrado. Copie config.example.json para config.json "
            "e preencha o IP da TV."
        )
    with open(CONFIG_PATH, encoding="utf-8") as f:
        return json.load(f)


def find_adb(config):
    configured = config.get("adb_path")
    if configured and os.path.exists(configured):
        return configured
    found = shutil.which("adb")
    if found:
        return found
    for candidate in ("/opt/homebrew/bin/adb", "/usr/local/bin/adb"):
        if os.path.exists(candidate):
            return candidate
    raise RuntimeError("adb não encontrado. Instale com: brew install android-platform-tools")


class FireTVMenu(rumps.App):
    def __init__(self):
        super().__init__("📺", quit_button=None)
        self.config = load_config()
        self.adb = find_adb(self.config)
        self.target = f"{self.config['ip']}:{self.config.get('port', 5555)}"
        self.status_item = rumps.MenuItem("Conectando...")

        items = [self.status_item, None]
        for label in KEYS:
            items.append(rumps.MenuItem(label, callback=self.send_key))
        items.append(None)

        self.apps_menu = rumps.MenuItem("Apps")
        for name in self.config.get("apps", {}):
            self.apps_menu.add(rumps.MenuItem(name, callback=self.open_app))
        items.append(self.apps_menu)
        items.append(None)
        items.append(rumps.MenuItem("Reconectar", callback=self.connect))
        items.append(rumps.MenuItem("Sair", callback=rumps.quit_application))
        self.menu = items

        self.connect(None)

    def run_adb(self, *args):
        return subprocess.run(
            [self.adb, *args], capture_output=True, text=True, timeout=10
        )

    def connect(self, _):
        result = self.run_adb("connect", self.target)
        output = (result.stdout + result.stderr).strip()
        connected = "connected" in output and "cannot" not in output
        self.status_item.title = (
            f"Conectado: {self.target}" if connected else f"Sem conexão: {output or 'erro'}"
        )

    def send_key(self, sender):
        keycode = KEYS[sender.title]
        result = self.run_adb("-s", self.target, "shell", "input", "keyevent", keycode)
        if result.returncode != 0:
            rumps.notification("Fire TV", "Falha ao enviar comando", result.stderr.strip())

    def open_app(self, sender):
        package = self.config["apps"][sender.title]
        self.run_adb(
            "-s", self.target, "shell", "monkey", "-p", package,
            "-c", "android.intent.category.LAUNCHER", "1",
        )


if __name__ == "__main__":
    try:
        FireTVMenu().run()
    except RuntimeError as exc:
        rumps.alert("Fire TV", str(exc))
