#!/bin/bash

# install pyzed (TODO: move to main build after debug)
cd /usr/local/zed && conda run -n "robot" python get_python_api.py
conda run -n "robot" python -m pip install --ignore-installed /usr/local/zed/pyzed-4.0-cp37-cp37m-linux_x86_64.whl

# run user command
exec "$@"
