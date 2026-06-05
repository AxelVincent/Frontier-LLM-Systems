# @frontier-llm-systems/repo-link

A minimal Quartz v5 toolbar component that renders a GitHub-icon link to the project's source repository.

Local plugin — referenced from `quartz.config.yaml` as `./plugins/repo-link`. Quartz symlinks this directory into `.quartz/plugins/repo-link/` and loads the pre-built `dist/` directly (no build step).

## Configuration

```yaml
- source: ./plugins/repo-link
  enabled: true
  options:
    url: https://github.com/<owner>/<repo>
    label: GitHub
  layout:
    position: left
    priority: 40
    group: toolbar
```

`url` is required; `label` is used as the link's `aria-label`, `title`, and inside the SVG `<title>` for tooltips and screen readers.

## Structure

- `dist/index.js`, `dist/components/index.js` — runtime, hand-written ESM that imports `preact.h` directly (no JSX, no bundler).
- `dist/index.d.ts`, `dist/components/index.d.ts` — declared exports so Quartz's plugin index generator picks up `RepoLink` as a `QuartzComponentConstructor`.
- `package.json` carries the `quartz` manifest (component registration, default position/priority, default options).

To swap the icon, edit `ICON_PATH` in `dist/components/index.js`. To restyle, edit the `css` template literal in the same file.
