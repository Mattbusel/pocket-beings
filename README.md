# Pocket Beings

Seven tiny people live in a town in your pocket. They rob, bribe, run for office
and print money while you watch. Tap to meddle. $4.99, no accounts, no network.

The society engine is the model-free half of [BEINGS](https://beings-phi.vercel.app)
(`lib/verbs.ts`, `power.ts`, `offices.ts`) ported to Swift, with the chat, the
language model and the server removed. `Sources/Engine/Society.swift` is the whole
game as pure functions over a `Town`; everything in `Sources/App` only draws it.

Authored on Windows, built and submitted by the GitHub Actions macOS runner. Same
pipeline as Glyphstorm and Clear the Strait:

```
Actions -> App Store -> compile       build + unit tests
                        screenshots   store screenshots as an artifact
                        review_video  the app playing itself from the home screen
                        dry_run       build, sign, upload; do not submit
                        release       everything, including Submit for Review
```

Listing without a binary, from Windows: `python Store/asc.py create-app`,
`python Store/listing.py finish`.
