package policy

default allow = false

cannot_privileged{
    token.payload.realm_access.roles[_] != "enroller"
}

allowed_calls{
    http_request.method == "GET"
}{
    http_request.method == "OPTIONS"
}

allowed_paths_enroller{
    endswith(http_request.path, "/cas") 
}{
    contains(http_request.path, "/cas/issued/ops")
}{
    contains(http_request.path, "/auth/realms/lamassu/protocol/openid-connect/token")
}{
    contains(http_request.path, "/health/checks/")
}{
    endswith(http_request.path, "/csrs/1/crt")
}{
    endswith(http_request.path, "/csrs/2/crt")
}


allowed_paths_operator{
    endswith(http_request.path, "/devices")
}{
    contains(http_request.path, "/devices/dms-cert-history/last-issued")
}{
    endswith(http_request.path, "/csrs")
}

allow {
    allowed_calls
    token.payload.realm_access.roles[_] == "enroller"
}

allow {
    allowed_calls
    token.payload.realm_access.roles[_] == "operator"
    allowed_paths_operator
}


allow {
    not cannot_privileged
    http_request.method == allowed_calls
    http_request.path== allowed_paths_enroller
}


