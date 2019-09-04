#!/bin/bash
ls -gGR --time-style=long-iso |sort --key=4r |grep "\-rw\-r\-\-r\-\-" |less -N