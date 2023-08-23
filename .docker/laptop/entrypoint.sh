#!/bin/bash

# activate conda
source ~/miniconda3/bin/activate
conda activate polymetis-local

# install pyzed (TODO: move to main build after debug)
cd /usr/local/zed && python get_python_api.py
python -m pip install --ignore-installed /usr/local/zed/pyzed-4.0-cp37-cp37m-linux_x86_64.whl

# run user command
exec "$@"
