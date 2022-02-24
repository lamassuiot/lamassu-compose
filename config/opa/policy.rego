package lamassu.gateway.security

import input.attributes.request.http as http_request

default allow = false

allow  {
    action_allowed
}

action_allowed {
  allowed_methods := ["OPTIONS"]
  allowed_methods[_] == http_request.method 
}

action_allowed {
  token.payload.realm_access.roles[_] == "admin"
}

action_allowed {
  allowed_methods := ["GET", "POST"]
  allowed_methods[_] == http_request.method 
  startswith(http_request.path, "/api/dmsenroller/")
  token.payload.realm_access.roles[_] == "operator"
}

token := {"payload": payload} {
    [_, encoded] := split(http_request.headers.authorization, " ")
    [header, payload, sig] := io.jwt.decode(encoded) 
}