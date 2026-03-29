# GitHub Pages Instructions

## Quick Setup

1. **Enable GitHub Pages**:
   - Go to your repository settings on GitHub
   - Scroll to the "Pages" section
   - Under "Source", select "Deploy from a branch"
   - Choose "main" branch and "/docs" folder
   - Click "Save"

2. **Custom Domain Setup**:
   - The site is configured for the custom domain: `https://caker.aldunelabs.com`
   - Make sure your DNS is configured to point to GitHub Pages
   - The CNAME file is already configured

## What's Included

The GitHub Pages site includes:
- 📖 Complete documentation from the wiki
- 🎨 Professional Jekyll theme with navigation
- 🔍 Search functionality
- 📱 Mobile-responsive design
- 🔗 Cross-linking between pages
- 💻 Syntax highlighting for code examples

## Local Development (Optional)

To preview changes locally before pushing:

```bash
cd docs
gem install bundler jekyll
bundle install
bundle exec jekyll serve
```

Then visit `http://localhost:4000` in your browser.

## Updating Content

The documentation is **automatically synchronized** from the `wiki/` directory when you push changes to the main branch.

### Workflow
1. **Edit wiki files** in the `wiki/` directory
2. **Commit and push** to the main branch
3. **GitHub Action automatically:**
   - Detects wiki changes
   - Converts content to GitHub Pages format
   - Commits updates to the `docs/` directory
   - Rebuilds the GitHub Pages site

### Manual Sync (if needed)
```bash
# Quick sync and review
./Scripts/quick-sync-docs.sh

# Full sync with detailed output  
./Scripts/sync-docs-from-wiki.sh

# Commit the changes
git add docs/ && git commit -m "docs: sync from wiki" && git push
```

### Content Sources
- **Primary source**: `wiki/` directory (edit these files)
- **GitHub Pages**: `docs/` directory (auto-generated, don't edit directly)
- **GitHub Wiki**: Published from `wiki/` using existing publish script

---

*The GitHub Pages setup is complete and ready to activate at **https://caker.aldunelabs.com**!*
