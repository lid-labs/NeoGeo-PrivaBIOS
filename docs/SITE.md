# The website

The PrivaBIOS website lives in [`site/`](../site/) and is served by GitHub Pages. Its domain is
https://privabios.com/ once the steps of "The domain" below are done; until then it is served at
https://bios.sprixe.dev/, its address under the name Sprixe BIOS.

## What is in `site/`

| File | Role |
|---|---|
| `index.html` | The home page: header, figures, features, "Why another BIOS?", method, install, FAQ |
| `guide/` | The guides, one folder per article with its `index.html`, and the list in `guide/index.html`. Their images and styles are taken from the site's root (`/img/`, `/site.css`) |
| `site.css` | The styles. One dark appearance, in the colours of the BIOS screens |
| `favicon.svg` | The tab icon |
| `fonts/` | The three fonts (WOFF2) and their OFL licences |
| `CNAME` | `privabios.com` |
| `serve.sh` | Local preview (not published) |

There is no build step and no npm. The page serves its three fonts itself, from `site/fonts/`
(Silkscreen, VT323, IBM Plex Sans; latin subset of Google Fonts' WOFF2 files, SIL OFL 1.1, licences
alongside, served unmodified, under their original names), each with a system fallback. The only
third-party requests go to [GoatCounter](https://www.goatcounter.com/), which counts the visits:
the script `count.v5.js` from `gc.zgo.at`, pinned by its SRI hash, and the pageview it sends to
`privabios.goatcounter.com`. GoatCounter stores aggregate counts only, no IP address, no full
User-Agent and no tracker ID, and sets no cookies or other browser storage ([privacy
policy](https://www.goatcounter.com/help/privacy), dated 8 June 2025, read on 5 November 2026).

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

## The domain

`privabios.com` is registered at Vercel, which also holds its DNS zone. To be done once, by a
maintainer, after the rename to PrivaBIOS is merged:

1. **Rename the repository** `lid-labs/sprixe-bios` to `lid-labs/privabios` (Settings → General;
   done, then renamed again, see below).
   GitHub redirects the old URLs, clones included (GitHub
   documentation, "Renaming a repository").
2. **Create the DNS records** in the `privabios.com` zone: four `A` records for the apex, to the
   GitHub Pages addresses listed in GitHub's documentation ("Managing a custom domain for your
   GitHub Pages site"), and `CNAME` `www` → `lid-labs.github.io`.
3. **Set the custom domain** in Settings → Pages: `privabios.com`, then tick **Enforce HTTPS**
   once the certificate is issued. With a workflow deployment, GitHub ignores the `CNAME` file in
   the artifact: the domain set here is what counts. `site/CNAME` stays as a record of the
   intended domain.
4. **Redirect the old address**: `bios.sprixe.dev` (a `CNAME` to `lid-labs.github.io` in the
   `sprixe.dev` zone, at Vercel) is no longer served by GitHub once the domain changes; it gets a
   permanent redirect to `https://privabios.com/`.

## The repository name

On 2026-11-06 the repository was renamed again, `lid-labs/privabios` to
`lid-labs/NeoGeo-PrivaBIOS`, for GitHub's search; the product name stays PrivaBIOS. Measured that
day on GitHub's web search (repositories, best match, signed in), before and after the rename, the
short description already in place: "neo geo bios" went from 10th to 6th, "neogeo bios" from 9th
to 8th, "neo geo mvs bios" from 4th to 3rd. In those results, GitHub highlights the name as
`NeoGeo-PrivaBIOS` with `NeoGeo` marked for "neo geo" as for "neogeo", and `BIOS` marked inside
`PrivaBIOS` for "bios".

The ABOUT screen of the BIOS still shows `GITHUB.COM/LID-LABS/PRIVABIOS` (`src/c0/about.s`, scene
in `bench/parcours.sh`): changing it would change the image, and the old address redirects. That
redirect lasts only as long as no repository called `privabios` is created again under `lid-labs`
(GitHub documentation, "Renaming a repository"): never create one.
