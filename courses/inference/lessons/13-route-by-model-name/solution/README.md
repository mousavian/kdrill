# Solution

From the lesson directory:

    kubectl apply -f solution/route.yaml
    kubectl apply -f solution/bbr.yaml

Two objects:

- `route.yaml`: HTTPRoute `llm` with one rule per model matching the header `x-model`, and a final
  catch-all rule whose HTTPRouteFilter (`directResponse`) answers an OpenAI-style 404 for any other
  model. The catch-all is also needed for a technical reason: Envoy Gateway enables the Lua filter per
  matched route, so a request that matches no route at all never reaches it.
- `bbr.yaml`: an EnvoyExtensionPolicy on the Gateway with an inline Lua filter that
  buffers the request body, finds `"model": "<name>"`, and **replaces** the header
  `x-model` with it (or removes it when there is none).

This is *body-based routing*. The Gateway API's matches only look at the path, the
headers, query parameters and method; the model lives in the JSON body. Envoy's
Lua filter (or an ext_proc server) can read the body and set a header, and
setting a header makes Envoy re-evaluate the route. Always overwrite, never
trust a client-sent value, or a client picks its own backend.

Streaming still works because only the *request* body is buffered (a chat request
is a few kB); the response path is untouched. Do not buffer responses.

Lua must be enabled in Envoy Gateway (`extensionApis.enableLua`; the course component
does it). With the Gateway API Inference Extension this job is done by the
**body-based router** (BBR): a small ext_proc server that does the same
extraction and writes `X-Gateway-Model-Name`; Envoy AI Gateway does it natively. A
regex on JSON is a lab shortcut: a real filter parses the JSON.
