# GitHub Pages Setup for Caker

This directory contains the GitHub Pages documentation site for Caker. The site is built using Jekyll and provides a comprehensive documentation experience at **https://caker.aldunelabs.com**.

## Activating GitHub Pages

To activate GitHub Pages for this repository:

1. Go to your GitHub repository settings
2. Scroll down to the "Pages" section
3. Under "Source", select "Deploy from a branch"
4. Choose "main" branch and "/docs" folder
5. Click "Save"
6. Configure your custom domain in the Pages settings (already done via CNAME file)

GitHub will automatically build and deploy your site at: `https://caker.aldunelabs.com`

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
bundle exec jekyll serve
```

The site will be available at `http://localhost:4000`

## File Structure

```
docs/
├── _config.yml          # Jekyll configuration
├── CNAME                # Custom domain configuration
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

## Syncing with Wiki

The content in this directory is automatically synchronized from the `wiki/` folder when wiki changes are pushed to the main branch. The synchronization can also be triggered manually.

### Automatic Synchronization

A GitHub Action automatically:
1. Detects changes to the `wiki/` directory
2. Converts wiki content to GitHub Pages format
3. Commits and pushes the updates
4. Rebuilds the GitHub Pages site

### Manual Synchronization

To manually sync docs from wiki changes:

```bash
# Full sync with detailed output
./Scripts/sync-docs-from-wiki.sh

# Quick sync with summary
./Scripts/quick-sync-docs.sh

# Then commit and push
git add docs/
git commit -m "docs: sync from wiki"
git push
```

### When to Update

**Update wiki (`wiki/`) when:**
- Making content changes
- Adding new documentation
- Updating existing guides

**The docs folder will automatically sync from wiki changes via:**
- GitHub Action on push to main (if wiki files changed)
- Manual script execution
- GitHub Actions workflow dispatch

### Content Conversion

The sync process automatically:
- Adds Jekyll frontmatter to each page
- Converts wiki-style links to docs-style links
- Updates image references for proper GitHub Pages paths
- Maintains proper navigation order

## Theme and Customization

The site uses the `minima` theme. To customize:

1. Override theme files by creating them locally
2. Modify `_config.yml` for site-wide settings
3. Add custom CSS in `assets/css/style.scss`

### Custom Domain

The site is configured to use the custom domain `caker.aldunelabs.com`:
- DNS should point to GitHub Pages IP addresses
- CNAME file in this directory contains the domain name
- GitHub Pages settings should be configured for the custom domain

## Additional Features

The Jekyll site provides:

- **Navigation**: Automatic sidebar navigation
- **Search**: Built-in search functionality (theme dependent)
- **Mobile-friendly**: Responsive design
- **SEO**: Meta tags and structured data
- **Syntax highlighting**: Code blocks with language support
- **Cross-linking**: Internal page references
