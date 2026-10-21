#!/usr/bin/env python3
"""Recopie la connexion Steam d'un ancien prefix Wine vers le nôtre.

Copie les sections de registre de Steam (compte en connexion automatique,
chemins, état des jeux) et le MachineGuid, en lisant directement les fichiers
user.reg / system.reg (l'ancien prefix n'est jamais modifié).

Ne copie PAS Apps\\CommonRedist : Steam doit réinstaller lui-même Visual C++
et DirectX dans le nouveau prefix au premier lancement du jeu.

Usage : import-steam-registry.py <ancien_prefix> <nouveau_prefix>
Wine doit être arrêté (wineserver -k) sur le nouveau prefix.
"""
import re
import sys
from pathlib import Path

USER_KEEP = [r"Software\\Valve\\Steam"]
USER_SKIP = [r"Software\\Valve\\Steam\\ActiveProcess"]
SYSTEM_KEEP = [r"Software\\Valve\\Steam", r"Software\\Wow6432Node\\Valve\\Steam"]
SYSTEM_SKIP = [r"Software\\Wow6432Node\\Valve\\Steam\\Apps\\CommonRedist",
               r"Software\\Valve\\Steam\\Apps\\CommonRedist"]

HEADER = re.compile(r"^\[(.+?)\](?: \d+)?\s*$")


def split_sections(text):
    """Renvoie (préambule, [(nom_clé, bloc_texte)])."""
    lines = text.splitlines(keepends=True)
    preamble, sections, current = [], [], None
    for line in lines:
        m = HEADER.match(line)
        if m:
            current = [m.group(1), [line]]
            sections.append(current)
        elif current is None:
            preamble.append(line)
        else:
            current[1].append(line)
    return "".join(preamble), [(k, "".join(b)) for k, b in sections]


def wanted(key, keep, skip):
    # Les clés sont écrites avec des doubles antislashs dans les fichiers .reg de Wine.
    k = key.replace("\\\\", "\\").lower()
    def under(prefix):
        p = prefix.replace("\\\\", "\\").lower()
        return k == p or k.startswith(p + "\\") or k.startswith(p) and k[len(p):].startswith("steamglobal")
    return any(under(p) for p in keep) and not any(under(p) for p in skip)


def merge(old_file, new_file, keep, skip):
    _, old_sections = split_sections(old_file.read_text(errors="surrogateescape"))
    pre, new_sections = split_sections(new_file.read_text(errors="surrogateescape"))
    imported = {k: b for k, b in old_sections if wanted(k, keep, skip)}
    kept = [(k, b) for k, b in new_sections if k not in imported]
    out = pre + "".join(b for _, b in kept)
    if not out.endswith("\n\n"):
        out += "\n"
    out += "".join(b if b.endswith("\n\n") else b + "\n" for b in imported.values())
    return out, sorted(imported)


def copy_machine_guid(old_text, new_text):
    key = r"Software\\Microsoft\\Cryptography"
    def find_guid(text):
        _, secs = split_sections(text)
        for k, b in secs:
            if k == key:
                m = re.search(r'^"MachineGuid"="([^"]+)"', b, re.M)
                return m.group(1) if m else None
    guid = find_guid(old_text)
    if not guid:
        return new_text, False
    new_text2, n = re.subn(
        r'(\[Software\\\\Microsoft\\\\Cryptography\][^\[]*?^"MachineGuid"=")[^"]+(")',
        lambda m: m.group(1) + guid + m.group(2), new_text, count=1, flags=re.M | re.S)
    return new_text2, n == 1


def main():
    old, new = Path(sys.argv[1]), Path(sys.argv[2])

    text, keys = merge(old / "user.reg", new / "user.reg", USER_KEEP, USER_SKIP)
    (new / "user.reg").write_text(text, errors="surrogateescape")
    print(f"user.reg   : {len(keys)} clés Steam importées")

    text, keys = merge(old / "system.reg", new / "system.reg", SYSTEM_KEEP, SYSTEM_SKIP)
    text, ok = copy_machine_guid((old / "system.reg").read_text(errors="surrogateescape"), text)
    (new / "system.reg").write_text(text, errors="surrogateescape")
    print(f"system.reg : {len(keys)} clés Steam importées, MachineGuid {'copié' if ok else 'NON copié'}")


if __name__ == "__main__":
    main()
