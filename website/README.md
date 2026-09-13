# RecordMe website

The single-page landing site lives at https://recorder.abbeazale.com. It has its own Vercel project, `recordme-website`, under `abbe-azales-projects`.

This is a static HTML, CSS, and JavaScript site with no dependencies or backend. Fonts and graphics are served locally. The interactive recording and canvas examples are illustrations; they never request device access or capture media.

## Local development

From this directory, run `npm run dev` and open http://localhost:4173. Node.js 22 or later is required. No package installation is needed.

Run `npm run build` to copy the public files into `dist/`, then `npm start` to inspect the production output. `dist/`, `.vercel/`, and personal verification files stay out of Git.

## Deployment

Deploy with `npm run deploy` from this directory, or `npm --prefix website run deploy` from the repository root. The script checks the project link and always uploads only `website/`. On a fresh checkout, first run `npx vercel@59.16.0 link --project recordme-website --scope abbe-azales-projects` from this directory.

Deployments are managed through the CLI. The Vercel project is not connected to Git, so app branch pushes do not redeploy the website. Only this directory is uploaded; the app, personal docs, and local tests are not part of the deployment.

## Downloads and release copy

All three download buttons point directly to the latest GitHub release's `RecordMe.dmg` asset. Keep that filename consistent between releases. Vercel also redirects `/download` to the same file.

The page includes the new trimming, styled export, camera layout, click effect, export setting, and saved project features. The download was still v1.0.6 at deployment, so the hero and editing section explain their availability. After publishing a release containing those features, update `.release-note` and `.editing-availability` in `index.html`; the direct download links update automatically.

The current installer is unsigned. Installation help links to Apple's supported first-launch instructions. Update that answer when signed, notarized builds are available.
