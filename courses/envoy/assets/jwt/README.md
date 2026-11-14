# Test JWTs for the envoy course

Signed once with an RSA key (kid `lab-1`) whose public half is `jwks.json`;
the private key was thrown away. Issuer `https://auth.lab`.

| File | sub | role | aud | exp | Note |
|---|---|---|---|---|---|
| alice.jwt | alice | viewer | shop | 2100-01-01 | valid |
| bob.jwt | bob | admin | shop | 2100-01-01 | valid |
| expired.jwt | carol | admin | shop | 2020-09-13 | expired |
| wrong-aud.jwt | dave | admin | billing | 2100-01-01 | wrong audience |
| forged.jwt | mallory | admin | shop | 2100-01-01 | signed with a different key, same kid |

Decode one: `cut -d. -f2 alice.jwt | base64 -d 2>/dev/null; echo`
