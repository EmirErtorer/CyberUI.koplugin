#!/usr/bin/env python3
"""Give the README's emulator copy a library of the screenshot books only, with
a reading history and a week of reading sessions:
    setup_books.py <copied home>   (the books' folder in CYBERUI_SHOT_BOOKS)"""
import glob, os, shutil, sqlite3, sys, time
home = os.path.realpath(sys.argv[1])   # one spelling of every path, as on a reader
src = os.environ["CYBERUI_SHOT_BOOKS"]
lib = os.path.join(home, "Books")
shutil.rmtree(lib, ignore_errors=True)
os.makedirs(lib)
books = []
for f in sorted(glob.glob(os.path.join(src, "*.epub"))):
    dst = os.path.join(lib, os.path.basename(f))
    shutil.copy(f, dst)
    books.append(dst)
# the reading order: Neuromancer first (the book being read)
books.sort(key=lambda p: (0 if "Neuromancer" in p else 1, p))
now = int(time.time())
with open(os.path.join(home, "history.lua"), "w") as h:
    h.write("return {\n" + "".join(
        f'    [{i + 1}] = {{ ["file"] = "{p}", ["time"] = {now - 3600 * (i * 9 + 2)} }},\n' for i, p in enumerate(books)) + "}\n")
s = open(os.path.join(home, "settings.reader.lua")).read()
import re
s = re.sub(r'\["lastfile"\] = "[^"]*"', f'["lastfile"] = "{books[0]}"', s)
s = re.sub(r'\["home_dir"\] = "[^"]*"', f'["home_dir"] = "{lib}"', s)
open(os.path.join(home, "settings.reader.lua"), "w").write(s)
db = sqlite3.connect(os.path.join(home, "settings", "statistics.sqlite3"))
db.execute("DELETE FROM page_stat_data"); db.execute("DELETE FROM book")
titles = ["Neuromancer", "Altered Carbon", "When Gravity Fails", "Ready Player One",
          "Do Androids Dream of Electric Sheep?", "Synners"]
for i, t in enumerate(titles, 1):
    db.execute("INSERT INTO book (id, title, authors, pages, total_read_time, total_read_pages, md5) VALUES (?,?,?,?,?,?,?)",
               (i, t, "", 300, 0, 0, "md5-%d" % i))
# a week of evenings, mostly Neuromancer
midnight = now - now % 86400
for day in range(7):
    for k, (book, minutes) in enumerate([(1, 34 + day * 3), (2 + day % 4, 12 + day)]):
        start = midnight - day * 86400 + 20 * 3600 + k * 3000
        for p in range(minutes // 2):
            db.execute("INSERT INTO page_stat_data (id_book, page, start_time, duration, total_pages) VALUES (?,?,?,?,?)",
                       (book, p + 1, start + p * 120, 120, 300))
db.commit()
print("library:", len(books), "books")
