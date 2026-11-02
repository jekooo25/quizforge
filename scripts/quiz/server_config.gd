class_name ServerConfig
extends RefCounted
## Where the question server lives.
##
## This is the one place to set the address for a build. Leave it empty and the
## student/teacher enters the address in Settings instead — the app never
## silently assumes the phone's own loopback (127.0.0.1), which is a different
## machine on a phone and the usual reason "it works on the laptop" fails.
##
## For a LAN demo, set this to the laptop's address, or type that address into
## Settings once (it is saved with the profile and wins over this default).
## For a deployed server, put the HTTPS URL here.

const DEFAULT_URL := ""
