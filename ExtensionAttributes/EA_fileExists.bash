#!/bin/bash

# Does file at /path/to/file exist?
if [ -f /path/to/file ]
then
echo "<result>Present</result>"
else
echo "<result>Not Found</result>"
fi
exit 0
