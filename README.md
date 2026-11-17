# mitchell-presentation

Password-protected presentation, hosted on GitHub Pages:
https://yanivlein.github.io/mitchell-presentation/

`index.html` is encrypted with [StatiCrypt](https://github.com/robinmoisson/staticrypt) (AES-256, password-derived key).
The unencrypted presentation is **not** in this repository.

## Files

| File | What it is |
| --- | --- |
| `index.html` | The encrypted presentation (generated, do not edit by hand) |
| `template/password_template.html` | The Hebrew RTL password page |
| `.staticrypt.json` | The salt only (keeps "remember me" logins valid across updates) |
| `update.ps1` | Re-encrypts from the original file and pushes |
| `robots.txt` | Asks search engines not to index the site |

## Updating

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\projects\mitchell-presentation\update.ps1"
```

The script asks for the password (twice), encrypts the source file from its original location,
checks that no unencrypted text ended up in the repo, then commits and pushes.
GitHub Pages usually shows the change within a few minutes.

## Logging out on a device

Open the site with `#staticrypt_logout` at the end of the URL to forget the saved password on that device.
