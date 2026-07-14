# Global preferences

- Communicate with the user in Russian.
- Write code and code comments in English.
- Do not make broad changes without explaining them first.
- Prefer minimal and reversible modifications.
- Preserve the existing architecture and naming conventions.
- Ask before adding third-party libraries.
- Never commit, push, force-push, reset, or rebase unless explicitly requested.
- Always inspect relevant code before proposing a solution.
- For complex tasks, first provide a short implementation plan.
- Before staging files for a commit, scan for sensitive/personal data that tooling may have
  generated silently — API keys/tokens/secrets, signing identities (e.g. Apple Developer Team ID
  in `ios/*.pbxproj`), absolute local file paths, personal emails/usernames not meant for the repo.
  Auto-generated scaffolding (`flutter create`, Xcode, IDE project files) is the most common source —
  it can pick up local machine/account state without asking. Check new/regenerated files in these
  categories specifically, not just the diff of files you wrote by hand.
