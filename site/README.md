# kdrill.5xx.tech

The kdrill landing page: the "toolbox" design (kdrill as a power tool in its
retail box, courses as drill bits). Plain static files, no build step.

| File | What it is |
|---|---|
| `index.html` | The whole page: inline CSS and JS, fonts from Google Fonts, page-view stats from `l.5xx.tech`. |
| `404.html` | "Bit not found". |
| `og.png` | 1200×630 share image (Open Graph and X cards). |
| `CNAME` | `kdrill.5xx.tech` for GitHub Pages. |
| `notes/` | The design brief, content and voice rules, and course data. Not published. |

## Preview

```bash
python3 -m http.server -d site 8000
```

## Publish

`.github/workflows/pages.yml` deploys `index.html`, `404.html`, `og.png` and
`CNAME` (not `notes/`) when `site/` changes on `main`, or when run by hand
from the Actions tab.

1. Repository settings, Pages: Source "GitHub Actions"; custom domain
   `kdrill.5xx.tech`; tick "Enforce HTTPS" once the certificate is issued.
2. DNS for 5xx.tech: `CNAME kdrill -> mousavian.github.io`.

## Before launch

- Lesson titles are embedded in the `COURSES` array in `index.html` (from
  `notes/courses.json`). Update both when courses change; the 168 total also
  appears in the copy, the share text and `og.png`.
