#!/usr/bin/env python3
"""Give a copied KOReader home two months of reading in its statistics
database, so the telemetry screens have something to show:  setup_stats.py <home_dir>"""
import os
import sqlite3
import sys
import time

db = os.path.join(sys.argv[1], "settings", "statistics.sqlite3")
con = sqlite3.connect(db)
ids = [r[0] for r in con.execute("SELECT id FROM book ORDER BY id LIMIT 5")]
if not ids:
    sys.exit("no books in the statistics database")
now = int(time.time())
page = {i: 1 for i in ids}
for back in range(0, 70):
    # a gap every week and a longer one in the middle, so streaks and the calendar differ
    if back > 12 and back % 7 in (3, 5):
        continue
    book = ids[(back // 9) % len(ids)]
    hour = (8, 13, 21)[back % 3]
    day = now - back * 86400
    t = time.localtime(day)
    start = int(time.mktime((t.tm_year, t.tm_mon, t.tm_mday, hour, 0, 0, 0, 0, -1)))
    for n in range(4 + back % 6):
        page[book] += 1 if n else 0
        con.execute("INSERT OR IGNORE INTO page_stat_data VALUES (?, ?, ?, ?, ?)",
                    (book, page[book], start + n * 90, 240 + 60 * (back % 5), 300))
con.commit()
print("seeded", len(ids), "books")
