#!/bin/sh
# Vendor html-to-image's ESM build into priv/static so the browser can import
# it natively — there is no bundler here, and the published package uses
# extensionless relative imports, which browsers do not resolve.
#
# Output is committed: the deploy image copies priv/ as-is, so committing the
# transformed files keeps the build free of a Node step whose only job is this.
set -eu
cd "$(dirname "$0")/.."
out=priv/static/vendor/html-to-image
rm -rf "$out"
mkdir -p "$out"
cp node_modules/html-to-image/es/*.js "$out/"
# './clone-node' -> './clone-node.js'
sed -i -E "s@(from ')(\./[^']*[^.]')@\1\2@; s@(from '\./[^']*)'@\1.js'@g" "$out"/*.js
echo "vendored $(ls "$out" | wc -l) files into $out"
