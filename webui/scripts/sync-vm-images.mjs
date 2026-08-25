#!/usr/bin/env node
// Regenerates src/data/vmImages.ts from Sources/cakedlib/Resources/VMImages.json, the catalog
// also consumed by CakedLib's VMImageCatalog.swift (used by Caker.app's wizard, and by
// caked/cakectl's `--<id>` build/launch shorthand flags — see VMImageShorthandFlags.swift).
// Run via `npm run sync-vm-images`, or let `npm run dev` / `npm run build` do it automatically
// (see the `pre*` scripts in package.json).
import { readFileSync, writeFileSync } from 'node:fs'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

const webuiRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const sourcePath = resolve(webuiRoot, '../Sources/cakedlib/Resources/VMImages.json')
const outputPath = resolve(webuiRoot, 'src/data/vmImages.ts')

const catalog = JSON.parse(readFileSync(sourcePath, 'utf8'))

for (const arch of ['arm64', 'amd64']) {
  if (!catalog[arch]) throw new Error(`VMImages.json is missing the "${arch}" architecture`)
  for (const category of ['iso', 'ipsw', 'cloud']) {
    if (!Array.isArray(catalog[arch][category])) throw new Error(`VMImages.json is missing "${arch}.${category}"`)
  }
}

const output = `// GENERATED FILE — DO NOT EDIT BY HAND.
// Source of truth: Sources/cakedlib/Resources/VMImages.json (also read by VMImageCatalog.swift).
// Regenerate with \`npm run sync-vm-images\`.

export interface VMImageEntry {
  id: string
  label: string
  url: string
  minCPU?: number
  minMemoryMiB?: number
}

export interface VMImageCatalog {
  iso: VMImageEntry[]
  ipsw: VMImageEntry[]
  cloud: VMImageEntry[]
}

export const vmImages: Record<'arm64' | 'amd64', VMImageCatalog> = ${JSON.stringify(catalog, null, 2)}
`

writeFileSync(outputPath, output)
console.log(`Synced ${outputPath} from ${sourcePath}`)
