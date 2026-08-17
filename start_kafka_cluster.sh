#!/usr/bin/env bash
# Kept for the walkthroughs that reference this filename (example_cluster).
# The platform is managed by platform.sh now — this is a one-line shim.
#
# Note: this starts in the background (-d) rather than the foreground, and it
# also brings up whatever 'kafka' depends on. Use './platform.sh logs' to
# follow the output.
exec "$(dirname "$0")/platform.sh" up kafka
