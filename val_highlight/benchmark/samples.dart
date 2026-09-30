import 'package:val_highlight/languages/all.dart';
import 'package:val_highlight/val_highlight.dart';

/// Realistic source for each language, repeated to benchmark size.
const benchmarkSamples = <Grammar, String>{
  dartLanguage: r'''
import 'dart:async';
import 'package:flutter/material.dart';

/// Loads and caches user profiles.
class ProfileRepository {
  ProfileRepository(this._client, {this.ttl = const Duration(minutes: 5)});

  final HttpClient _client;
  final Duration ttl;
  final Map<String, (Profile, DateTime)> _cache = {};

  Future<Profile?> load(String id, {bool force = false}) async {
    final cached = _cache[id];
    if (!force && cached != null && DateTime.now().difference(cached.$2) < ttl) {
      return cached.$1;
    }
    try {
      final json = await _client.getJson('/profiles/$id?fields=${_fields.join(',')}');
      final profile = Profile.fromJson(json as Map<String, Object?>);
      _cache[id] = (profile, DateTime.now());
      return profile;
    } on TimeoutException catch (e) {
      debugPrint('timeout loading $id: $e'); // retry later
      return null;
    }
  }

  static const _fields = ['name', 'email', 'avatar', 0x1F];
}
''',
  javascriptLanguage: r'''
import { EventEmitter } from 'node:events';

export class Queue extends EventEmitter {
  #items = [];
  constructor({ concurrency = 4, retries = 2 } = {}) {
    super();
    this.concurrency = concurrency;
    this.retries = retries;
  }

  push(task) {
    this.#items.push({ task, attempts: 0 });
    this.emit('queued', this.#items.length);
    return this;
  }

  async run() {
    const workers = Array.from({ length: this.concurrency }, async () => {
      while (this.#items.length > 0) {
        const job = this.#items.shift();
        try {
          const result = await job.task();
          this.emit('done', result);
        } catch (err) {
          if (++job.attempts <= this.retries) this.#items.push(job);
          else console.error(`failed after ${job.attempts} tries`, /timeout/i.test(err.message));
        }
      }
    });
    await Promise.all(workers);
  }
}
''',
  pythonLanguage: r'''
from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Config:
    name: str
    retries: int = 3
    tags: list[str] = field(default_factory=list)

    @classmethod
    def load(cls, path: Path) -> "Config":
        """Read a config file, falling back to defaults."""
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except FileNotFoundError:
            return cls(name=path.stem)
        return cls(**{k: v for k, v in data.items() if k in cls.__annotations__})

    def summary(self) -> str:
        return f"{self.name}: {self.retries} retries, tags={', '.join(self.tags) or None!r}"


if __name__ == "__main__":
    for p in Path(".").glob("*.json"):
        print(Config.load(p).summary())  # one per file
''',
  jsonLanguage: r'''
{
  "id": "0f8fad5b-d9cb-469f-a165-70867728950e",
  "name": "val_highlight",
  "version": "1.2.3",
  "private": false,
  "downloads": 128934,
  "rating": 4.87,
  "tags": ["syntax", "highlighting", "flutter", "dart"],
  "maintainers": [
    {"name": "Ada", "email": "ada@example.com", "active": true},
    {"name": "Linus", "email": "linus@example.com", "active": null}
  ],
  "escaped": "line\nbreak \"quoted\" é",
  "nested": {"a": {"b": {"c": [1, 2, 3, -4.5e10]}}}
}
''',
  htmlLanguage: r'''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Dashboard &mdash; Overview</title>
  <style>
    .card { padding: 1rem; border-radius: 8px; box-shadow: 0 1px 3px rgba(0,0,0,.2); }
    .card:hover { transform: translateY(-2px); }
  </style>
</head>
<body class="dark">
  <!-- Main navigation -->
  <nav id="top"><a href="/" class="brand">Home</a><a href="/about">About</a></nav>
  <main>
    <section class="card" data-id="42">
      <h2>Stats</h2>
      <p>Visitors: <strong id="count">0</strong></p>
    </section>
  </main>
  <script type="module">
    const el = document.getElementById('count');
    let n = 0;
    setInterval(() => { el.textContent = String(++n); }, 1000);
  </script>
</body>
</html>
''',
  cssLanguage: r'''
:root {
  --brand: #b0226e;
  --gap: 12px;
}

html, body { margin: 0; font: 16px/1.5 system-ui, sans-serif; }

.grid > .item:nth-child(2n + 1),
#sidebar a[href^="https://"]:hover {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: var(--gap);
  color: var(--brand) !important;
  background: url("img/bg.png") no-repeat center / cover;
  transition: transform 0.2s ease-in-out, opacity 150ms;
}

@media (max-width: 600px) {
  .grid { grid-template-columns: 1fr; }
}
''',
  yamlLanguage: r'''
# Deployment configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels: {app: web, tier: frontend}
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    spec:
      containers:
        - name: web
          image: "registry.example.com/web:1.4.2"
          ports:
            - containerPort: 8080
          env:
            - name: DEBUG
              value: false
            - name: RATIO
              value: 0.75
          args: &args [--port, "8080"]
          resources:
            limits: {cpu: 500m, memory: 256Mi}
''',
  sqlLanguage: r'''
-- Monthly revenue per region
WITH monthly AS (
  SELECT r.name AS region,
         date_trunc('month', o.created_at) AS month,
         SUM(o.total) AS revenue,
         COUNT(DISTINCT o.customer_id) AS customers
  FROM orders o
  JOIN regions r ON r.id = o.region_id
  WHERE o.status = 'paid' AND o.created_at >= '2026-01-01'
  GROUP BY 1, 2
)
SELECT region, month, revenue,
       revenue / NULLIF(customers, 0) AS per_customer,
       LAG(revenue) OVER (PARTITION BY region ORDER BY month) AS previous
FROM monthly
ORDER BY region, month DESC
LIMIT 100;
''',
  bashLanguage: r'''
#!/usr/bin/env bash
set -euo pipefail

LOG_DIR="${LOG_DIR:-/var/log/app}"
KEEP=7

# Rotate logs older than $KEEP days.
rotate() {
  local dir="$1"
  find "$dir" -name '*.log' -mtime +"$KEEP" -print0 | while IFS= read -r -d '' f; do
    gzip -9 "$f" && echo "compressed $(basename "$f")"
  done
}

if [[ -d "$LOG_DIR" ]]; then
  rotate "$LOG_DIR" >> /tmp/rotate.log 2>&1
else
  echo "missing $LOG_DIR" >&2
  exit 1
fi
''',
  markdownLanguage: r'''
# Release notes

## 1.2.0

This release makes highlighting **much faster** and adds *incremental* updates.
See [the changelog](https://example.com/changelog) for details.

- Faster scanner with `first-character dispatch`
- New `IncrementalHighlighter`
- Fixed a bug in YAML keys

> Upgrading is safe; the API is unchanged.

```dart
final result = const Highlighter().highlight(code, language: dartLanguage);
```

1. Update the dependency
2. Run `dart pub get`
''',
};

/// [source] repeated until it is at least [minLength] characters long.
String repeatTo(String source, int minLength) {
  final buffer = StringBuffer();
  while (buffer.length < minLength) {
    buffer.write(source);
  }
  return buffer.toString();
}
