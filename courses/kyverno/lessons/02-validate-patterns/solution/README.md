# Solution

    kubectl apply -f solution/policy.yaml      # from the lesson directory

`disallow-latest`:

- `"*:* & !*:latest"`: `&` combines two conditions. `*:*` requires a tag,
  `!*:latest` forbids the latest tag. An image with no tag *is* `:latest`.
- `=(initContainers):` is an **equality anchor**: "if this field exists, it
  must match". A pattern only checks the fields it names, so initContainers
  (and ephemeralContainers) slip through unless you list them. Without the
  anchor, Pods *without* initContainers would fail the pattern.

`restrict-registries` uses `deny` with a JMESPath expression:

    request.object.spec.[initContainers, containers][][].image

builds `[initContainers, containers]`, flattens it to one list of containers
(a missing initContainers is just dropped), and takes every `.image`.
`AnyNotIn` is true when at least one image matches none of the values;
values may contain wildcards. The same expression in the `message` names the
offending images. Try JMESPath offline with `kyverno jp query` (lesson 12
downloads the CLI).

The pattern alternative `image: "registry.acme.io/* | ghcr.io/acme/*"`
works too, but its message can't easily list the bad images.

Gotcha: `registry.acme.io:5000/ranker` matches `*:*` because of the port's
colon. Real-world policies often check `images.containers.*.tag` (Kyverno's
built-in `images` variable) instead.

Takeaways:
- pattern = "what valid looks like"; deny = "when to refuse", with full
  JMESPath and operators (Equals, AnyIn, AllNotIn, GreaterThan, ...).
- Always cover initContainers and ephemeralContainers.
- Put the offending value in the message; users fix things faster.
