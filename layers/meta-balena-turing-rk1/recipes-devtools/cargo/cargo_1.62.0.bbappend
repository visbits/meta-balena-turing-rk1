# Provide hardcodepaths.patch that meta-balena-rust cargo recipes expect
FILESEXTRAPATHS:prepend := "${THISDIR}/cargo-${PV}:"
