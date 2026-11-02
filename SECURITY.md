# Security

This is a small showcase project. It makes no network calls of its own while listening, and it stores no audio.

To report a security problem, please use GitHub's private vulnerability reporting (the Security tab of this repository) instead of a public issue. Do not send personal data.

Supply chain notes: the speech library is pinned to one exact version in `project.yml`; the model download script only talks to huggingface.co over HTTPS, keeps every file inside `Models/`, and checks the published SHA-256 hash of large files.
