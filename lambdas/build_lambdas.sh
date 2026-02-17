#!/bin/bash
set -e

echo "Building Lambda packages..."

echo "Building post_confirmation lambda..."
mkdir -p tmp_post_confirmation

cp ../lambdas/post_confirmation.py tmp_post_confirmation/
cd tmp_post_confirmation
zip -r ../post_confirmation.zip .
cd ..
rm -rf tmp_post_confirmation

echo "Building messaging_stream lambda..."