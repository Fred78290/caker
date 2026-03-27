# GitHub Pages Setup for Caker

This directory contains the GitHub Pages documentation site for Caker. The site is built using Jekyll and provides a comprehensive documentation experience.

## Activating GitHub Pages

To activate GitHub Pages for this repository:

1. Go to your GitHub repository settings
2. Scroll down to the "Pages" section
3. Under "Source", select "Deploy from a branch"
4. Choose "main" branch and "/docs" folder
5. Click "Save"

GitHub will automatically build and deploy your site at: `https://Fred78290.github.io/caker`

## Local Development

To run the site locally for development:

### Prerequisites
- Ruby 2.7 or higher
- Bundler gem

### Setup
```bash
cd docs
gem install bundler jekyll
bundle install
```

### Run locally
```bash
bundle exec jekyll serve --baseurl=
```

The site will be available at `http://localhost:4000/caker`

## File Structure

```
docs/
├── _config.yml          # Jekyll configuration
├── index.md             # Home page
├── getting-started.md   # Getting started guide
├── architecture.md      # Architecture overview
├── development.md       # Development guide
├── command-summary.md   # Command reference
├── troubleshooting.md   # Troubleshooting guide
├── faq.md              # Frequently asked questions
├── release-notes.md    # Release notes
├── cheat-sheet.md      # Quick reference
└── assets/
    └── images/         # Images and assets
```

## Updating Documentation

1. Edit the Markdown files in this directory
2. Commit and push changes to the `main` branch
3. GitHub Pages will automatically rebuild the site

For major structural changes, test locally first using the local development setup above.

## Theme and Customization

The site uses the `minima` theme. To customize:

1. Override theme files by creating them locally
2. Modify `_config.yml` for site-wide settings
3. Add custom CSS in `assets/css/style.scss`

## Syncing with Wiki

The content in this directory is based on the `wiki/` folder in the repository root. When updating documentation:

1. Update files in `docs/` for GitHub Pages
2. Update corresponding files in `wiki/` for GitHub Wiki
3. Use the provided scripts to publish wiki changes

## Additional Features

The Jekyll site provides:

- **Navigation**: Automatic sidebar navigation
- **Mobile-friendly**: Responsive design
- **SEO**: Meta tags and structured data
- **Syntax highlighting**: Code blocks with language support
- **Cross-linking**: Internal page references