#!/usr/bin/env python3
"""
collect_codebase.py

Скрипт рекурсивно собирает тексты файлов в одну "кодовую базу".
Пример запуска:
    python collect_codebase.py -r /path/to/project -o all_code.txt --exts .py,.js,.html
"""

import argparse
import os
import sys
from pathlib import Path

DEFAULT_EXCLUDE_DIRS = {'.git', '__pycache__', 'node_modules', 'venv', '.venv', 'env', 'build', 'dist'}

SEPARATOR = "\n" + ("#" * 80) + "\n"

def is_text_file(path: Path, blocksize: int = 512) -> bool:
    """
    Простая эвристика: читаем первые bytes и считаем наличие нулевых байтов.
    Если нулевых нет — считаем текстовым.
    """
    try:
        with path.open('rb') as f:
            chunk = f.read(blocksize)
            if not chunk:
                return True
            if b'\x00' in chunk:
                return False
            # try decode as utf-8 or fallback — если декодится с заменой, считаем текстом
            try:
                chunk.decode('utf-8')
                return True
            except Exception:
                try:
                    chunk.decode('latin-1')
                    return True
                except Exception:
                    return False
    except Exception:
        return False

def gather_files(root: Path, exts: set, exclude_dirs: set, max_size: int, skip_output_path: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        # модифицируем dirnames in-place чтобы os.walk не заходил в исключённые каталоги
        dirnames[:] = [d for d in dirnames if d not in exclude_dirs]
        for fname in filenames:
            fpath = Path(dirpath) / fname
            # пропустить файл вывода, если он находится в корне/поддиректории
            try:
                if skip_output_path and fpath.resolve() == skip_output_path.resolve():
                    continue
            except Exception:
                pass
            # расширения: если задан список — проверяем
            if exts and fpath.suffix not in exts:
                continue
            # размер
            try:
                size = fpath.stat().st_size
            except Exception:
                continue
            if max_size and size > max_size:
                continue
            # бинарный?
            if not is_text_file(fpath):
                continue
            yield fpath

def write_aggregate(root: Path, output: Path, exts: set, exclude_dirs: set, max_size: int, mode: str):
    # если режим overwrite, то перезапишем, иначе append
    open_mode = 'w' if mode == 'overwrite' else 'a'
    files = list(gather_files(root, exts, exclude_dirs, max_size, output))
    files.sort()  # упорядочим по пути для детерминированности
    total = 0
    with output.open(open_mode, encoding='utf-8', errors='replace') as out:
        for p in files:
            total += 1
            header = f"{SEPARATOR}FILE: {p.relative_to(root) if root in p.parents or p==root else p}\nSIZE: {p.stat().st_size} bytes\n{SEPARATOR}"
            out.write(header)
            try:
                with p.open('r', encoding='utf-8', errors='replace') as fin:
                    for line in fin:
                        out.write(line)
            except Exception as e:
                out.write(f"\n# ERROR reading file: {e}\n")
    return total

def parse_args():
    p = argparse.ArgumentParser(description="Собрать кодовую базу в один файл.")
    p.add_argument('-r', '--root', type=str, default='.', help="Корневая директория для обхода (по умолчанию текущая).")
    p.add_argument('-o', '--output', type=str, default='codebase_aggregate.txt', help="Выходной файл.")
    p.add_argument('--exts', type=str, default='', help="Через запятую: список расширений файлов (например .py,.js). Оставьте пустым чтобы брать все файлы.")
    p.add_argument('--exclude', type=str, default=','.join(sorted(DEFAULT_EXCLUDE_DIRS)), help=f"Имена папок для исключения (через запятую). По умолчанию: {', '.join(sorted(DEFAULT_EXCLUDE_DIRS))}")
    p.add_argument('--max-size', type=int, default=5_000_000, help="Максимальный размер файла в байтах (по умолчанию 5_000_000). 0 — без лимита.")
    p.add_argument('--mode', choices=['overwrite', 'append'], default='overwrite', help="Перезаписать файл или добавлять.")
    return p.parse_args()

def main():
    args = parse_args()
    root = Path(args.root).resolve()
    output = Path(args.output).resolve()
    exts = {e.strip() for e in args.exts.split(',') if e.strip()}  # пустой => все файлы
    exclude_dirs = {d.strip() for d in args.exclude.split(',') if d.strip()}
    max_size = args.max_size if args.max_size > 0 else None

    if not root.exists() or not root.is_dir():
        print(f"Ошибка: root {root} не найдена или не директория.", file=sys.stderr)
        sys.exit(2)

    # не даём добавлять сам выходной файл в результат, даже если он лежит в корне
    if output.exists() and args.mode == 'append':
        print(f"Добавляю к существующему файлу {output}")
    else:
        print(f"Запись в файл {output} (режим: {args.mode})")

    total = write_aggregate(root, output, exts, exclude_dirs, max_size, args.mode)
    print(f"Готово. Обработано файлов: {total}. Выход: {output}")

if __name__ == '__main__':
    main()
