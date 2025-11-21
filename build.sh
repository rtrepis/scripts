#!/bin/bash




build_project() {
    local build_dir=$1
    cd $build_dir
    npm run build
}
