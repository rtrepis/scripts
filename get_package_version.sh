#!/bin/bash
get_version() {
    local build_dir=$1
    grep -oP '(?<="version": ")[^"]*' $build_dir/package.json
}