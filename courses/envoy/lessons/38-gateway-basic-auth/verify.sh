source "$KDRILL_HOME/courses/envoy/lib.sh"
gw_settle edge
pols="$(kubectl get securitypolicy -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)"
U=http://edge/admin/panel
H=(-H 'Host: shop.lab')

echo "policy"
check "There is a SecurityPolicy" test -n "$pols"
why "kubectl explain securitypolicy.spec.basicAuth"
for p in $pols; do
  check "SecurityPolicy $p is Accepted" eval '[[ " $(kubectl get securitypolicy '"$p"' -o jsonpath="{.status.ancestors[*].conditions[?(@.type==\"Accepted\")].status}") " == *" True "* ]]'
  why "kubectl describe securitypolicy $p: the Secret must exist and have the key .htpasswd"
done
check_eq "A SecurityPolicy targets HTTPRoute admin" admin \
  "$(kubectl get securitypolicy -o jsonpath='{range .items[*]}{range .spec.targetRefs[*]}{.kind}{"/"}{.name}{"\n"}{end}{end}' 2>/dev/null | awk -F/ '$1=="HTTPRoute" && $2=="admin" {print $2; exit}')"
why "spec.targetRefs: [{group: gateway.networking.k8s.io, kind: HTTPRoute, name: admin}]"
# a new policy needs a moment to reach Envoy
wait_until 20 eval '[[ "$(http_code '"$U"' -H "Host: shop.lab")" == 401 ]]' || true

echo "/admin"
check_eq "Without credentials: 401" 401 "$(http_code $U "${H[@]}")"
why "Attach a SecurityPolicy with basicAuth to HTTPRoute admin."
check "... with a WWW-Authenticate: Basic challenge" \
  eval '[[ "$(http_head '"$U"' www-authenticate -H "Host: shop.lab")" == [Bb]asic* ]]'
check_eq "Wrong password: 401" 401 "$(http_code $U "${H[@]}" -u ops:guess)"
check_eq "Unknown user: 401" 401 "$(http_code $U "${H[@]}" -u eve:kdrill-ops)"
out="$(hits_out -n 5 $U "${H[@]}" -u ops:kdrill-ops)"
check_eq "ops / kdrill-ops: 5 x 200 from admin" 5 "$(count_of "200 admin" "$out")"
why "The Secret's .htpasswd line: ops:{SHA}<base64 of the SHA-1 of the password>. See hint 2."
body="$(http_body $U "${H[@]}" -u ops:kdrill-ops)"
check_eq "The backend sees the user name in x-user" "X-User: ops" \
  "$(printf '%s\n' "$body" | grep -i '^x-user:' | tr -d '\r' | head -n 1)"
why "basicAuth.forwardUsernameHeader: x-user"

echo "everything else"
out="$(hits_out -n 5 http://edge/products "${H[@]}")"
check_eq "/products (route web) needs no credentials: 5 x 200 from web" 5 "$(count_of "200 web" "$out")"
why "Attach the policy to HTTPRoute admin only, not to the Gateway or route web."
