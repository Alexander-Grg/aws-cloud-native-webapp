#!/bin/bash
set -e

echo "Building Lambda packages..."

echo "Building post_confirmation lambda..."
rm -rf tmp_post_confirmation post_confirmation.zip
mkdir -p tmp_post_confirmation

# Copy source code
cp ../lambdas/post_confirmation.py tmp_post_confirmation/
cd tmp_post_confirmation

pip install \
    --platform manylinux2014_x86_64 \
    --target . \
    --implementation cp \
    --python-version 3.12 \
    --only-binary=:all: \
    --upgrade \
    psycopg2-binary==2.9.9

rm -rf *.dist-info __pycache__

zip -r ../post_confirmation.zip .
cd ..
rm -rf tmp_post_confirmation


# Build
echo "Building messaging_stream lambda..."
rm -rf tmp_messaging_stream messaging_stream.zip
mkdir -p tmp_messaging_stream

cp ../lambdas/messaging_stream.py tmp_messaging_stream/
cd tmp_messaging_stream

pip install boto3==1.34.101 -t .

rm -rf *.dist-info __pycache__
zip -r ../messaging_stream.zip .
cd ..
rm -rf tmp_messaging_stream

echo "Lambda packages built successfully!"
echo "  - post_confirmation.zip"
echo "  - messaging_stream.zip"