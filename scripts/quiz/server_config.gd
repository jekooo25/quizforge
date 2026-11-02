class_name ServerConfig
extends RefCounted
## Where the question server lives — the one line to change per build.
##
## Students never configure this. The address is baked into the build here, and
## the only override is the hidden developer menu (behind the Settings version
## label), which exists for LAN testing on a laptop.
##
## To point the app at a hosted server, change DEFAULT_URL to the HTTPS URL and
## rebuild. Nothing else in the app reads an address.

const DEFAULT_URL := "http://127.0.0.1:8765"
