# Work around Ubuntu 25.10 / Python 3.13 pseudo issues
# The postinst should only run on target, not during sysroot staging

# Defer postinst to first boot on target
PACKAGE_WRITE_DEPS:remove = "base-passwd:do_populate_sysroot"
pkg_postinst_ontarget:${PN} () {
    #!/bin/sh
    if [ -x ${sbindir}/update-passwd ]; then
        ${sbindir}/update-passwd
    fi
}

# Remove the sysroot postinst that causes chown failures
do_install:append() {
    rm -f ${D}${bindir}/postinst-base-passwd
}
