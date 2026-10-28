# The website

The Sprixe BIOS website lives in [`site/`](../site/) and is meant to be served by GitHub Pages at
https://bios.sprixe.dev/. It replaces the `sprixe.dev/bios` page of the Sprixe site.

## What is in `site/`

| File | Role |
|---|---|
| `index.html` | The whole page: header, comparison with UniBIOS 4.0, screens, download, method, FAQ, manual, changelog |
| `site.css` | The styles. One dark appearance, in the colours of the BIOS screens |
| `favicon.svg` | The tab icon |
| `CNAME` | `bios.sprixe.dev` |
| `serve.sh` | Local preview (not published) |

There is no build step and no npm. The page loads three fonts from Google Fonts (Silkscreen,
VT323, IBM Plex Sans), each with a system fallback.

**The screenshots are not copied into `site/`.** The page references them under `img/`; the Pages
workflow copies `docs/screenshots/` there when it assembles the published artifact, and
`site/serve.sh` does the same locally. A screenshot updated in `docs/screenshots/` therefore
updates the README and the site at once.

## Preview locally

```bash
site/serve.sh          # http://localhost:8000/
site/serve.sh 8765     # another port
```

The script assembles `site/` and the screenshots in `.site-preview/` (ignored by git) and serves
that directory with `python3 -m http.server`, bound to 127.0.0.1.

## Publishing

[`.github/workflows/pages.yml`](../.github/workflows/pages.yml) runs on a push to `main` that
touches `site/**`, `docs/screenshots/**` or the workflow itself, and can also be started by hand
(`workflow_dispatch`). It assembles `site/` with the screenshots and deploys them with
`actions/upload-pages-artifact` and `actions/deploy-pages`, pinned by commit SHA.

**It does nothing useful yet.** The repository is private, and GitHub Pages is not available on
it: the deploy step will fail until the steps below are done.

## Activation

To be done once, by a maintainer, in this order. None of it has been done.

1. **Make the repository public** (Settings → General → Danger Zone → Change visibility).
2. **Enable Pages** (Settings → Pages → Build and deployment → Source: **GitHub Actions**).
3. **Set the custom domain** in the same page: `bios.sprixe.dev`, then tick **Enforce HTTPS**
   once the certificate is issued. With a workflow deployment, GitHub ignores the `CNAME` file in
   the artifact: the domain set here is what counts. `site/CNAME` stays as a record of the
   intended domain.
4. **Create the DNS record** in the `sprixe.dev` zone, managed at Vercel:
   `CNAME` `bios` → `lid-labs.github.io`.
   Optionally, verify `sprixe.dev` for the `lid-labs` organisation (Organisation settings → Pages →
   Add a domain, a `TXT` record), so that no other GitHub account can claim the subdomain.
5. **Run the workflow** once (Actions → pages → Run workflow), or push a change to `site/`.
6. **Redirect the old page**: in the Sprixe site (repository `lid-labs/sprixe`), add a redirect
   from `sprixe.dev/bios` to `https://bios.sprixe.dev/`, then remove the old page.
