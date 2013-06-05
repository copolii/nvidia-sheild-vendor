#!/usr/bin/env python
#
# Copyright (C) 2009-2013 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Original copy of this script can be found at $TOP/build/utils

import sys
import os
import optparse

# Command line parser
def parse_cmdline():
    parser = optparse.OptionParser()
    usage = "%s [options]" % os.path.basename(sys.argv[0])
    parser.set_usage(usage)
    parser.add_option("-p", "--prop", help="The property which needs to be changed")
    parser.add_option("-v", "--value", help="The new value of property")
    (options, args) = parser.parse_args()
    if not options.prop:
        print ("A property name must be specified!")
        sys.exit(2)

    if not options.value:
        print ("A property value must be specified!")
        sys.exit(2)

    if len(args) != 1:
        print ("An android prop file is must and only argument!")
        print args
        sys.exit(2)
    return options, args

# Put the modifications that you need to make into the /system/build.prop into this
# function. The prop object has get(name) and put(name,value) methods.
def mangle_prop(prop, name, value):
    oldVal = prop.get(name)
    if value and oldVal:
        prop.put(name,value)

class PropFile:
  def __init__(self, lines):
    self.lines = [s[:-1] for s in lines]

  def get(self, name):
    key = name + "="
    for line in self.lines:
      if line.startswith(key):
        return line[len(key):]
    return ""

  def put(self, name, value):
    key = name + "="
    for i in range(0,len(self.lines)):
      if self.lines[i].startswith(key):
        self.lines[i] = key + value
        return
    self.lines.append(key + value)

  def write(self, f):
    f.write("\n".join(self.lines))
    f.write("\n")

def main():
  (options, arguments) = parse_cmdline()
  filename = arguments[0]
  name=options.prop
  value=options.value
  f = open(filename)
  lines = f.readlines()
  f.close()
  propObj = PropFile(lines)
  mangle_prop(propObj, name, value)

  f = open(filename, 'w+')
  propObj.write(f)
  f.close()

if __name__ == "__main__":
  main()
