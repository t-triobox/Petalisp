#!/bin/bash
# -*- coding: utf-8 -*-

find . \
     -type f \
     -name '*.lisp' \
     -print \
     -exec sed -i 's/^;.*©.*/;;;; © 2016-2021 Marco Heisig         - license: GNU AGPLv3 -*- coding: utf-8 -*-/' {} +
