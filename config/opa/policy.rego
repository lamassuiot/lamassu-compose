package lamassu.gateway.security

import input.attributes.request.http as http_request

# default allow = false
default allow = true

allow  {
    is_token_valid
    action_allowed
}

is_token_valid {
    now := time.now_ns() / 1000000000
    token.payload.iat <= now
    now < token.payload.exp
}

action_allowed {
  http_request.method == "GET"
  startswith(http_request.path, "/api/ca/v1/ca")
  token.payload.realm_access.roles[_] == "admin"
}

action_allowed {
  http_request.method == "GET"
  startswith(http_request.path, "/api/ca/v1/health")
}

token := {"payload": payload} {
    [_, encoded] := split(http_request.headers.authorization, " ")
    [header, payload, sig] := io.jwt.decode(encoded) 
}