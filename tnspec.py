#!/usr/bin/env python
#
# Copyright (c) 2013-2014 NVIDIA Corporation.  All Rights Reserved.
#
# NVIDIA Corporation and its licensors retain all intellectual property
# and proprietary rights in and to this software, related documentation
# and any modifications thereto.  Any use, reproduction, disclosure or
# distribution of this software and related documentation without an express
# license agreement from NVIDIA Corporation is strictly prohibited.
#

###############################################################################
###############################################################################
###                                                                         ###
###                                                                         ###
###   THIS FILE IS TO BE REMOVED.                                           ###
###                                                                         ###
###   NEW LOCATION : vendor/nvidia/tegra/core/tools/tnspec/tnspec.py        ###
###                                                                         ###
###   KEEP THIS FILE UNTIL PACKAGING ISSUE IS RESOLVED.                     ###
###                                                                         ###
###                                                                         ###
###                                                                         ###
###############################################################################
###############################################################################

from __future__ import print_function
from struct import pack, pack_into, unpack, unpack_from, calcsize as csz
import sys
import os
import getopt
import json
import collections
import copy
import mmap
import zlib
import binascii
import types
import re
import contextlib

__metaclass__ = type

###############################################################################
# Globals
###############################################################################

verbose = False
debug = False
product_id = ''
g_spec_file = None
g_group = None
g_nctfile = None
g_stdin = False
g_outfile = None
g_argv_copy = ''

###############################################################################
# Helper Functions
###############################################################################

# Print wrapper functions.
def pr(out, *args, **opt):
    # 1 - stdout, 2 - stderr
    out -= 1
    std = [sys.stdout, sys.stderr]
    if opt.has_key('prefix'):
        print(opt['prefix'], end='', file=std[out])
    print(*args, file=std[out], end=opt.get('end','\n'))

def pr_err(*args):
    pr(2, *args, prefix=bcolors.FAIL, end=bcolors.ENDC + '\n')
def pr_warn(*args):
    pr(2, *args, prefix=bcolors.WARNING, end=bcolors.ENDC + '\n')
def pr_dbg(*args):
    if not debug:
        return
    pr(1, *args, prefix=bcolors.HEADER+'DEBUG: '+bcolors.ENDC)

def merge_dict(d1, d2):
    for k,v2 in d2.items():
        v1 = d1.get(k) # returns None if v1 has no value for this key
        # use dict instead of collections.Mapping on earlier version of python
        if (isinstance(v1, collections.Mapping) and
            isinstance(v2, collections.Mapping)):
            merge_dict(v1, v2)
        else:
            d1[k] = v2

def command_failed():
    # it's stderr by default
    if debug:
        pr_err("Command failed: 'tnspec %s'" % ' '.join(g_argv_copy))

def set_options(options):
    global g_spec_file, g_nctfile, g_outfile, g_group, debug, verbose

    try:
        opts, args = getopt.getopt(options, 'dvs:o:g:n:',
                ['verbose','spec=', 'nct=', 'group='])
    except:
        pr_err('invalid options. (check if option requires argument)')
        CmdHelp.usage(2)
        sys.exit(1)

    for o, a in opts:
        if o in ('-v', '--verbose'):
            verbose = True
        elif o in ('-s', '--spec'):
            g_spec_file = a
        elif o in ('-n', '--nct'):
            g_nctfile = a
        elif o in ('-g', '--group'):
            g_group = a
        elif o in ('-o'):
            g_outfile = a
        elif o == '-d':
            debug = True

@contextlib.contextmanager
def qopen(fobj, mode='rb'):
    if isinstance(fobj, types.StringTypes):
        f = open(fobj, mode)
    elif fobj in [sys.stdout, sys.stdin]:
        f = fobj
    else:
        f = None
    try:
        yield f
    finally:
        if isinstance(fobj, types.StringTypes):
            f.close()

###############################################################################
# Command Classes
###############################################################################

# Base Command Class
class Command(object):
    @staticmethod
    def help(*args):
        pass
    def process(self, args):
        pr_err('Hah!')

# NCT Command Class (derived from Command)
class CmdNCT(Command):
    @staticmethod
    def help(*args):
        out = args[0]
        pr(out, "tnspec nct dump <[all]|entry|nct> --nct <nctbin>")
        pr(out, "  dumps or generates NCT in text format.")
        pr(out, "  if no option is passed, 'all' is assumed")
        if not verbose:
            pr(out, "  - 'tnspec help nct -v' to show all 'entry' names.")
        else:
            pr(out, "NCT Entries:")
            for e in NCT.base_entries:
                pr(out, "%2d| %20s" % (e['idx'], e['name']))
        pr(out, "")
        pr(out, "tnspec nct new <HW spec ID> -o <outfile> --spec <tnspec>")
        pr(out, "tnspec nct new -o <outfile>")
        pr(out, "  generates a new NCT binary")
        pr(out, "")
        pr(out, "tnspec nct update <HW/SW spec ID> -o <outfile> --nct <nctbin>")
        pr(out, "                  --spec <tnspec> --group <sw|hw>")
        pr(out, "tnspec nct update -o <outfile> --nct <nctbin>")
        pr(out, "  updates the existing NCT binary with specs using the spec")
        pr(out, "  from the specificied spec file or from standard input.")
        pr(out, "  For SW/HW spec IDs, run 'tnspec list'")
        pr(out, "")
        pr(out, "NOTE:")
        pr(out, "HW specs are required for creating a new NCT binary when 'new' is used.")
        pr(out, "HW specs are optional for updating a NCT binary when 'update' is used.")

    def __init__(self):
        pass

    @staticmethod
    def _dump(nct, key):
        tmpl = '%2d|%12s| %s\n'
        out = ''
        if len(key) and key in ['all'] + [e['name'] for e in NCT.base_entries]:
            if key == 'all':
                out += '  |      HEADER| %s\n' % str(map(lambda x:
                                                    x if isinstance(x,str)
                                                    else hex(x), nct.hdr['val']))
                for e in nct.entries:
                    if e['val'] != None:
                        rpr = NCT.print(e)
                        if isinstance(rpr, list) and len(rpr) > 4 and not verbose:
                            out += tmpl % (e['idx'], e['name'][:12], str(rpr[:3] + ['... more ...']))
                        else:
                            out += tmpl % (e['idx'], e['name'][:12], rpr)
            else:
                # Dump values individually. Print headers (index, name) only when verbose is set.
                for e in NCT.base_entries:
                    if e['name'] == key:
                        break
                if e['val'] != None:
                    if verbose:
                        out += tmpl % (e['idx'], e['name'][:8], NCT.print(e))
                    elif e['name'] == 'spec':
                        out += json.dumps(json.loads(NCT.print(e)),
                                sort_keys=True, indent=4, separators=(',', ': '))
                    else:
                        out += NCT.print(e)
        return out

    def dump(self, args):
        if not g_nctfile:
            return 'requires --nct <nct binary>'

        nct = NCT(g_nctfile)

        if len(args) == 0 or args[0] == 'all':
            pr(1, CmdNCT._dump(nct, 'all'), end='')
        elif len(args) and args[0] in [e['name'] for e in NCT.base_entries]:
            pr(1, CmdNCT._dump(nct, args[0]))
        elif len(args) and args[0] == 'nct':
            nct.gen('-', 'txt')
        else:
            return "too many args or invalid entry name. " + \
                   "'tnspec help nct -v' to see a list of valid names"

    def new(self, args):
        spec = Spec()
        if not g_outfile:
            return 'you need to specify an output file.'
        if len(args) == 0 and not g_spec_file:
            hwspec = HwSpec(filename='-')
            hwspec.apply_override()
            spec.set_specs(hwspec.get())
        elif len(args) == 1 and g_spec_file:
            spec_key = args[0]
            hwspec = HwSpec(group='hw', filename=g_spec_file)
            hwspec.apply_override(spec_key)
            hwspec = hwspec.get(spec_key)
            if not hwspec:
                return "%s doesn't seem to contain anything." % spec_key
            spec.set_specs(hwspec)

            # merge SW specs as well.
            if spec.get().has_key('id'):
                cfg = spec.get().get('config', 'default')
                # default and the the non-default one
                if cfg != 'default':
                    _q = spec.get()['id'] + '.default'
                    spec.merge_specs(Spec(group='sw', filename=g_spec_file).get(_q))

                _q = spec.get()['id'] + '.' + cfg
                spec.merge_specs(Spec(group='sw', filename=g_spec_file).get(_q))
                spec.apply_override()
            else:
                pr_warn("Warning: No HW ID was found in the spec. Not attempting to merge SW specs.")

        else:
            return 'invalid command'

        if g_nctfile == g_outfile:
            return "%s and %s can't be the same." % (g_nctfile, g_outfile)

        nct = NCT(spec.get())
        if debug:
            nct.dump()

        nct.gen(g_outfile, 'bin')

    def update(self, args):
        if not (g_outfile and g_nctfile):
            return 'you need to specify an output and nct file'

        if len(args) == 1 and g_group and g_spec_file:
            specid = args[0]

            if g_group == 'sw':
                # check SW spec id format: hwid.config
                r = re.match('([\w\-_]+)\.([\w\-_]+)', specid)
                if not r:
                    return "%s is not valid SW spec id" % specid
                hwid, config = r.groups()
                # if config is not default, get default specs first
                spec = Spec()
                if config != 'default':
                    spec.merge_specs(
                            Spec(group='sw', filename=g_spec_file).get(hwid + '.default'))

                # default or merge with the non-default spec
                spec.merge_specs(
                        Spec(group='sw', filename=g_spec_file).get(specid))

                spec.apply_override()
                spec = spec.get()
            elif g_group == 'hw':
                spec = HwSpec(group='hw', filename=g_spec_file)
                spec.apply_override(specid)
                spec = spec.get(specid)
            else:
                return "Internal error. Bug."
        elif len(args) == 0:
            if g_group == 'sw' or not g_group:
                if not g_group:
                    pr_warn("'--group sw' is assumed.")
                spec = Spec(filename='-')
                spec.apply_override()
                spec = spec.get()
            elif g_group == 'hw':
                spec = HwSpec(filename='-')
                spec.apply_override()
                spec = spec.get()
            else:
                return 'invalid group'
        else:
            return "--group and --spec must be used when spec ID '%s' is given." % args[0]

        if len(spec) == 0:
            pr_warn("empty spec")
            return

        nct = NCT(g_nctfile)
        nct.update(spec)
        nct.gen(g_outfile, 'bin')

    def process(self, args):
        if len(args) == 0:
            return 'missing arguments'

        cmd = args.pop(0)

        if cmd == 'dump':
            return self.dump(args)
        elif cmd == 'new':
            return self.new(args)
        elif cmd == 'update':
            return self.update(args)
        else:
            return 'Unknown command : ' + cmd

# Help Command Class (derived from Command)
class CmdHelp(Command):
    def __init__(self, cmd_table):
        self.cmds = cmd_table
        super(CmdHelp, self).__init__()

    @staticmethod
    def usage(out=1):
        pr(out, "tnspec <command> [options]")
        pr(out, "")
        pr(out, " commands:")
        pr(out, "   nct  reads, generates NCT in bin or text format")
        pr(out, "   spec lists entries or returns values mapped by key")
        pr(out, "")
        pr(out, " options:")
        pr(out, "   -s, --spec <tnspec>")
        pr(out, "   -g, --group <sw|hw>")
        pr(out, "   -n, --nct <nctbin>")
        pr(out, "   -v, --verbose")
        pr(out, "")
        pr(out, "See 'tnspec help <command>' for more information on a specific command.")

    @staticmethod
    def help(*args):
        out = args[0]
        cmds = args[1]

        pr(out, "tnspec help <command>")
        pr(out, "  shows detailed usage for <command>")
        pr(out, "")
        if cmds:
            pr(out, "commands:")
            for e in sorted(cmds.keys()):
                pr(out, e)

    def process(self, args):
        if len(args):
            if not self.cmds.has_key(args[0]):
                return 'unsupported command'

            o = self.cmds[args[0]]['cls']
            if o:
                o.help(1, *tuple(self.cmds[args[0]].get('help',[])))
        else:
            CmdHelp.usage()

# Spec Command Class
class CmdSpec(Command):
    @staticmethod
    def help(*args):
        out = args[0]
        pr(out, "tnspec spec list --spec <tnspec> [--group <sw|hw>]")
        pr(out, "  lists spec IDs. if --group is missing, it will list both hw and sw.")
        pr(out, "")
        pr(out, "tnspec spec get [<query>] --spec <tnspec> --group <sw|hw>")
        pr(out, "tnspec spec get [<query>] [--group <sw|hw>]")
        pr(out, "  gets property information specified by <query>")
        pr(out, "  'sw' specs are assumed if no group is specified when reading from stdin.")
        pr(out, "")

    def init(self):
        self.specfile = g_spec_file
        self.group = g_group

        # top level error checking
        if self.group and self.group not in ['sw', 'hw']:
            return "--group must be set to either sw or hw"

    def list(self, args):
        if not self.specfile:
            return 'requires specfile'

        # HW
        if self.group == 'hw' or self.group == None:
            hw = HwSpec(group='hw', filename=self.specfile)
            for e in sorted(hw.query('.')):
                if e[0] == '&': continue
                d = hw.query(e +'.desc')
                if verbose:
                    pr(1, '%-30s %s' % (e, '[HW][' +
                        (d if d else 'No Description') + ']'))
                else:
                    pr(1, e)
        # SW
        if self.group == 'sw' or self.group == None:
            sw = Spec(group='sw', filename=self.specfile)
            for e in sorted(sw.query('.')):
                if e[0] == '&': continue
                config = sw.query(e + '.')
                for cfg in config:
                    if cfg != 'compatible' and cfg != 'desc' :
                        pr(1, '%-30s' % (e + '.' + cfg))
                    else:
                        continue
                    c = sw.query(e + '.compatible')
                    for cid in c:
                        pr(1, '%-30s [Compatible with %s]' %
                                (cid + '.' + cfg, e + '.' + cfg))

    @staticmethod
    def find_primary_hwid(spec, compat_hwid):
        hwid_keys = spec.specs.keys()

        if compat_hwid in hwid_keys:
            return compat_hwid
        else:
            for e in hwid_keys:
                if compat_hwid in spec.specs[e].get('compatible',[]):
                    return e

    def get(self, args):
        q = None
        spec_type = None
        config = None
        group_path = None
        cls = HwSpec if self.group == 'hw' else Spec
        fname = self.specfile

        if len(args) < 2 and self.specfile and self.group:
            group_path = self.group
        elif len(args) < 2 and not self.specfile:
            fname = '-'
            group_path = ''
            if not self.group:
                pr_warn("'sw' specs are assumed.")
        else:
            return 'invalid arguments - group needs to be set unless spec is fed to stdin.'

        spec = None

        query = args[0] if len(args) else ''

        if group_path == 'hw':
            spec = cls(group=group_path, filename=fname)

            r = re.match('[\w\-_]+', query)
            pri_key = r.group(0) if r else None
            if pri_key:
                spec.apply_override(pri_key)

            # including stdin spec.
            q = spec.query(query)
        elif group_path == 'sw':
            # sw
            spec = cls()
            swspec = cls(group=group_path, filename=fname, skip_process=True)

            r = re.match('[\w\-_]+', query)
            hwid = r.group(0) if r else None
            if hwid:
                pri_hwid = self.find_primary_hwid(swspec, hwid)
                if pri_hwid and hwid != pri_hwid:
                    query = re.sub('[\w\-_]+', pri_hwid, query, count=1)
                    hwid = pri_hwid

                r = re.match('[\w\-_]+\.([\w\-_]+)', query)
                config = r.group(1) if r else None
                if config:
                    spec.set_specs(swspec.get(hwid + '.default'))
                    if config != 'default':
                        spec.merge_specs(swspec.get(hwid + '.' + config))
                    spec.apply_override('', True)
                    # purge hwid.config
                    query = re.sub('[\w\-_]+\.[\w\-_]+', '', query, count=1)
                    if len(query) > 1:
                        query = query[1:]

            if not hwid or not config:
                spec.set_specs(swspec.get())
                # no need to apply override.

            spec.process()
            # search with pri hwid with the passed config
            q = spec.query(query)
        else:
            # group_path = '' (stdin)
            spec = cls(group=group_path, filename=fname)
            spec.apply_override()
            q = spec.query(query)


        if isinstance(q, types.StringTypes):
            pr(1, q)
        elif isinstance(q, types.BooleanType):
            pr(1, repr(q).lower())
        elif q == None or not len(q):
            pass
        else:
            pr(1, json.dumps(q, sort_keys=False, indent=4, separators=(',', ': ')))

    def process(self, args):
        err = self.init()

        if err:
            return err
        if len(args) == 0:
            return 'missing arguments'
        cmd = args.pop(0)
        if cmd == 'list':
            return self.list(args)
        elif cmd == 'get':
            return self.get(args)

###############################################################################
# NCT Class
###############################################################################
class NCT(object):
    # supported versions
    supported = ['1.0']
    # global constants
    magic = 'nVCt'
    entry_offset = 0x4000

    # static helper methods
    @staticmethod
    def print(e):
        if e['val'] != None:
            # handle special cases first
            if e['name'] == 'board_info':
                return 'Proc: ' + '.'.join(map(lambda x: str(x),e['val'][:3])) + \
                       ' PMU: ' + '.'.join(map(lambda x: str(x), e['val'][3:6])) + \
                       ' Disp: ' + '.'.join(map(lambda x: str(x), e['val'][-3:]))
            elif e['fmt'] == '6B':
                return ':'.join(map(lambda x: '%02X' % x,e['val']))
            elif e['fmt'].endswith('s'):
                return  str(e['val'][0]).rstrip('\0')
            elif e['fmt'].startswith(('I','H')):
                return e['val'][0]
            else:
                return map(lambda x: '0x%08x' % x, e['val'])

    @staticmethod
    def _tag(e):
        tag = {'s':0x80, 'B': 0x1a, 'H': 0x2a, 'I': 0x4a}
        if e['fmt'][0] in ['s', 'B', 'H', 'I']:
            t = tag[e['fmt'][0]] & 0xf0
        else:
            t = tag[e['fmt'][-1]]
        return hex(t)

    @staticmethod
    def _data(e):
        # string
        if e['fmt'].endswith('s'):
            return ' data:%s' % e['val'][0].rstrip('\0')
        elif e['fmt'] in [ 'B', 'H', 'I'] :
            return ' data:0x%x' % e['val'][0]
        else:
            return ';'.join([' data:0x%x' % x for x in e['val']])

    # e - entry, s - spec, name - key
    def _spec_str(e, s, name):
        if s.has_key(name):
            # use bytearray to make it mutable
            data = bytearray(csz(e['fmt']))
            data[:len(s[name])] = s[name].encode('ascii')
            data = str(data)
            e['val'] = unpack_from(e['fmt'], data)

    def _spec_mac(e, s, name, save=False):
        if s.has_key(name):
            mac = s[name].split(':')
            e['val'] = tuple(map(lambda x: int(x, 16), mac))

    def _spec_board(e, s, name):
        if set(('proc', 'pmu', 'disp')).intersection(set(s.keys())):
            e['val'] = (int(s.get('proc',{}).get('id', '0'),0),
                        int(s.get('proc',{}).get('sku','0'),0),
                        int(s.get('proc',{}).get('fab','0'),0),
                        int(s.get('pmu', {}).get('id', '0'),0),
                        int(s.get('pmu', {}).get('sku','0'),0),
                        int(s.get('pmu', {}).get('fab','0'),0),
                        int(s.get('disp',{}).get('id', '0'),0),
                        int(s.get('disp',{}).get('sku','0'),0),
                        int(s.get('disp',{}).get('fab','0'),0))

    def _spec_lcd(e, s, *unused):
        if s.has_key('disp'):
            e['val'] = (int(s['disp'].get('id',0),0),)

    def _spec_un(e, s, name):
        if s.has_key(name):
            e['val'] = (int(s[name],0),)

    def _spec_arry(e, s, name):
        if s.has_key(name):
            num = int(e['fmt'][:-1])
            data = [0] * num
            # check if # of elements is greater than the expected.
            if len(s[name]) > num:
                pr_err("Number of elements (%d) in %s is greater than %d." %
                        (len(s[name]), name, num))
                sys.exit(1)
            data[:len(s[name])] = map(lambda x: int(x,0), s[name])
            e['val'] = tuple(data)

    def _spec_meta(e, s, *unused):
        export_keys = [ 'id', 'config', 'proc', 'pmu', 'disp', 'misc' ]
        spec = {}
        for ex in export_keys:
            if s.has_key(ex):
                spec[ex] = s[ex]
        spec_str = json.dumps(spec, separators=(',',':'))
        pr_dbg('spec_meta length:', len(spec_str))
        if len(spec_str) > csz(e['fmt']):
            pr_err('spec size too big! please file a bug..')
            sys.exit(1)

        data = bytearray(csz(e['fmt']))
        data[:len(spec_str)] = spec_str.encode('ascii')
        data = str(data)
        e['val'] = unpack_from(e['fmt'], data)

    # various formats
    _fmt_idx = _fmt_crc32 = 'I'
    _fmt_rsvd = '2I'
    _fmt_entry_hdr = _fmt_idx + _fmt_rsvd
    _fmt_entry_body = '256I'
    _fmt_entry_hdr_body = _fmt_entry_hdr + _fmt_entry_body
    _fmt_entry = _fmt_entry_hdr + _fmt_entry_body + _fmt_crc32

    # default header
    header = \
        { 'fmt' : '4s4I',
                 # magic  vendor  product version revision (auto-incremented)
          'val' : (magic, 0xffff, 0xffff, 0x10000, 43) }

    # base entries - always make a copy when instantiated.
    # If 'None' is used to spec functions, 'name' will be passed.
    base_entries = \
    [
        {'name': 'serial'       , 'idx' : 0 , 'fmt': '30s'  , 'fn': _spec_str, 'key': 'sn'},
        {'name': 'wifi'         , 'idx' : 1 , 'fmt': '6B'   , 'fn': _spec_mac  },
        {'name': 'bt'           , 'idx' : 2 , 'fmt': '6B'   , 'fn': _spec_mac  },
        {'name': 'cm'           , 'idx' : 3 , 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'lbh'          , 'idx' : 4 , 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'factory_mode' , 'idx' : 5 , 'fmt': 'I'    , 'fn': _spec_un   },
        {'name': 'ramdump'      , 'idx' : 6 , 'fmt': 'I'    , 'fn': _spec_un   },
        {'name': 'board_info'   , 'idx' : 8 , 'fmt': '9I'   , 'fn': _spec_board},
        {'name': 'gps'          , 'idx' : 9 , 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'lcd'          , 'idx' : 10, 'fmt': 'H'    , 'fn': _spec_lcd  },
        {'name': 'accelerometer', 'idx' : 11, 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'compass'      , 'idx' : 12, 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'gyroscope'    , 'idx' : 13, 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'light'        , 'idx' : 14, 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'charger'      , 'idx' : 15, 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'touch'        , 'idx' : 16, 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'fuelgauge'    , 'idx' : 17, 'fmt': 'H'    , 'fn': _spec_un   },
        {'name': 'emc_table1'   , 'idx' : 18, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table2'   , 'idx' : 19, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table3'   , 'idx' : 20, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table4'   , 'idx' : 21, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table5'   , 'idx' : 22, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table6'   , 'idx' : 23, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table7'   , 'idx' : 24, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table8'   , 'idx' : 25, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table9'   , 'idx' : 26, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table10'  , 'idx' : 27, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table11'  , 'idx' : 28, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table12'  , 'idx' : 29, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table13'  , 'idx' : 30, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table14'  , 'idx' : 31, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table15'  , 'idx' : 32, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table16'  , 'idx' : 33, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table17'  , 'idx' : 34, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table18'  , 'idx' : 35, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table19'  , 'idx' : 36, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'emc_table20'  , 'idx' : 37, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'batt_model'   , 'idx' : 38, 'fmt': '256I' , 'fn': _spec_arry },
        {'name': 'dbgport'      , 'idx' : 39, 'fmt': 'I'    , 'fn': _spec_un   },
        {'name': 'batt_make'    , 'idx' : 40, 'fmt': '20s'  , 'fn': _spec_str  },
        {'name': 'batt_count'   , 'idx' : 41, 'fmt': 'I'    , 'fn': _spec_un   },
        {'name': 'spec'         , 'idx' : 42, 'fmt': '1024s', 'fn': _spec_meta }
    ]

    def __init__(self, source):
        # do a shallow copy on initial table.
        self.hdr = copy.copy(NCT.header)
        self.entries = copy.copy(NCT.base_entries)
        self.spec = {}

        # nullify all 'val's
        for e in self.entries:
            e['val'] = None

        if isinstance(source, str):
            self._init_nctbin(source)
        elif isinstance(source, dict):
            self.spec = source
            self._init_spec()
        else:
            pr_err("NCT: unrecognized nct source - ", source)
            sys.exit(1)

    def _init_nctbin(self, nctbin):

        if not os.path.exists(nctbin):
            command_failed()
            pr_err("Error: nct file '%s' doesn't exist." % nctbin)
            CmdHelp.usage(2)
            sys.exit(1)

        with qopen(nctbin, 'rb') as f:
            self.rawbin = f.read()

            if (len(self.rawbin) != 2 * 1024 * 1024 or
                self.rawbin[:4] != NCT.magic):
                pr_err("'%s' doesn't seem to be a valid NCT binary" % nctbin)
                sys.exit(1)
        # read in the header
        # NCT._unpack_nctbin(self.hdr, self.rawbin) REMOVE
        self.hdr['val'] = unpack_from(self.hdr['fmt'], self.rawbin)

        pr_dbg(map(lambda x: x if isinstance(x,str) else hex(x), self.hdr['val']))
        for e in self.entries:
            base = NCT.entry_offset + e['idx'] * csz(NCT._fmt_entry)
            e['raw'] = self.rawbin[base : base + csz(NCT._fmt_entry)]
            # some sanity checks

            # idx
            idx = unpack('I',e['raw'][:csz(NCT._fmt_idx)])[0]
            if e['idx'] != idx:
                pr_dbg('Invalid idx. Expected %d, but got %d' % (e['idx'], idx))
                continue

            # crc32
            nct_crc32 = unpack('I',e['raw'][-csz(NCT._fmt_crc32):])[0]
            calc_crc32 = zlib.crc32(e['raw'][:-csz(NCT._fmt_crc32)]) & 0xffffffff
            if calc_crc32 != nct_crc32 :
                pr_dbg('CRC32 error. Expected %x, but got %x' %
                    (calc_crc32, nct_crc32))
                continue

            # save values
            e['val'] = unpack_from(e['fmt'], e['raw'][csz(NCT._fmt_entry_hdr):])

            # special case: handling spec
            if e['name'] == 'spec':
                Spec.merge(self.spec, json.loads(NCT.print(e)))

    def _init_spec(self):
        for e in self.entries:
            e['fn'](e, self.spec, e.get('key', e['name']))
            # if e['val'] has some valid value, update revision
            if e['val'] and e['idx'] + 1 > self.hdr['val'][4]:
                hdr = list(self.hdr['val'])
                hdr[4] = e['idx'] + 1
                self.hdr['val'] = tuple(hdr)

    def update(self, spec):
        Spec.merge(self.spec, spec)

        # check if 'invalidate' key exists before updating NCT.
        # any entry listed in 'invalidate' will be first invalidated.
        invalidate = self.spec.get('invalidate', [])
        for e in self.entries:
            if e['name'] in invalidate:
                e['val'] = None

        self._init_spec()

    def gen(self, outfile, mode):
        if mode not in ['bin', 'txt']:
            pr_err('Error: invalid NCT output format %s', mode)
            sys.exit(1)

        if mode == 'txt':
            self._gen_txt(outfile)
        elif mode == 'bin':
            self._gen_bin(outfile)

    def _gen_txt(self, outfile):
        # template
        nct_tmpl_header = \
'''// Automatically generated by 'tnspec nct new txt'
//
// [NCT TABLE - %s (ver. %d.%d)]
//
%s//
<version:0x%08x>
<vid:0x%x; pid:0x%x>
<revision:%d>
<offset:0x%x>
'''
        nct_tmpl_entry = "<name: %12s; idx:%2d; tag:%s;%s>\n"

        tbl = ''
        idstr = 'unknown.default'
        # pretty table
        for e in CmdNCT._dump(self, 'all').split('\n'):
            tbl += '// ' + e + '\n'

        # id.config
        for e in self.entries:
            if e['name'] == 'spec' and e['val']:
                sm = self.print(e)
                j = json.loads(sm)
                idstr = j.get('id','unknown') + '.' + j.get('config', 'default')
        # header
        out = nct_tmpl_header % (
                idstr,
                # version (e.g. 1.0)
                self.hdr['val'][3] >> 16,
                self.hdr['val'][3] & 0xffff,
                # pretty
                tbl,
                # version
                self.hdr['val'][3],
                # vid, pid
                self.hdr['val'][1], self.hdr['val'][2],
                # revision
                self.hdr['val'][4],
                # offset
                NCT.entry_offset)
        # entries
        for e in self.entries:
            if e['val'] != None:
                out += nct_tmpl_entry % (
                        e['name'], e['idx'], NCT._tag(e), NCT._data(e))
        pr_dbg(out)
        with qopen(outfile if outfile != '-' else sys.stdout, 'w') as f:
            f.write(out)

    def _gen_bin(self, outfile):
        rawbin = bytearray(2 * 1024 * 1024)
        pack_into(self.hdr['fmt'], rawbin, 0, *self.hdr['val'])

        for e in self.entries:
            if e['val'] != None:
                offset = NCT.entry_offset + e['idx'] * csz(NCT._fmt_entry)
                entry_bin = bytearray(csz(NCT._fmt_entry))
                # idx
                pack_into(NCT._fmt_idx, entry_bin, 0, e['idx'])
                # body
                pack_into(e['fmt'], entry_bin, csz(NCT._fmt_entry_hdr), *e['val'])
                # crc32
                pack_into(NCT._fmt_crc32, entry_bin,
                        csz(NCT._fmt_entry_hdr_body),
                        zlib.crc32(bytes(entry_bin[:-csz(NCT._fmt_crc32)])) & 0xffffffff)
                # store
                assert len(rawbin[offset:offset+csz(NCT._fmt_entry)]) == len(entry_bin)
                rawbin[offset:offset+csz(NCT._fmt_entry)] = entry_bin

        with qopen(outfile, 'wb') as f:
            f.write(rawbin)

    # debug only
    def dump(self):
        pr(1, '  |      HEADER|', map(lambda x: x if isinstance(x,str) else hex(x), self.hdr['val']))
        for e in self.entries:
            if e['val'] != None:
                pr(1, '%2d|%12s|' % (e['idx'], e['name'][:12]), NCT.print(e))

###############################################################################
# Spec Classes
###############################################################################

# Base Spec Class
class Spec(object):
    supported_version = ['2.0']

    def __init__(self, **args):

        self.group = args.get('group', '')
        self.filename = args.get('filename', None)
        self.local_keys = []
        self.handlers = []
        self.specs = self.src = {}
        self.override_env = 'TNSPEC_SET'

        if self.filename != None and self.filename != '-':
            if not os.path.exists(self.filename):
                command_failed()
                pr_err("Error: tnspec file '%s' doesn't exist." % self.filename )
                CmdHelp.usage(2)
                sys.exit(1)

        if self.filename:
            with qopen(self.filename if self.filename != '-'  else sys.stdin) as f:
                try:
                    data = f.read()
                    if not data or data == '\n':
                        data = '{}'
                    self.src = json.loads(data)
                except ValueError as detail:
                    pr_err("Error in %s: " % self.filename if self.filename else 'stdin', detail)
                    sys.exit(1)
                except KeyboardInterrupt:
                    sys.exit(0)

            # remove comments, get version, ..
            self.preprocess()

        if self.group:
            if self.src.has_key(self.group):
                for s in self.src[self.group].keys():
                    pr_dbg('proecessing ', s)
                    self._flatten(self.group, s)
                self.specs = self.src[self.group]
        else:
            self.specs = self.src

        skip_pp = args.get('skip_process', False)
        if not skip_pp:
            self.process()

    def _flatten(self, root_key, spec_name):
        root = self.src[root_key]
        spec = root[spec_name]
        bases = [spec.get('base')] + spec.get('bases',[])

        # DO NOT remove dupes - ordering is important
        # bases = list(set(bases))

        if None in bases:
            bases.remove(None)

        # remove these keys.
        if spec.has_key('bases'): del spec['bases']
        if spec.has_key('base'): del spec['base']

        if len(bases) == 0:
            return spec

        copied_spec = {}
        for base_spec_name in bases:
            if not root.has_key(base_spec_name):
                pr_err("Error: base '%s' in '%s' not found." % (base_spec_name, spec_name))
                sys.exit(1)
            c = copy.deepcopy(self._flatten(root_key, base_spec_name))
            Spec.merge(copied_spec, c, self.local_keys)

        # merge all of resolved bases
        Spec.merge(copied_spec, spec, self.local_keys)
        root[spec_name] = copied_spec
        return root[spec_name]

    @staticmethod
    def _attr_append(current, key):
        if current != '':
            current += '.'
        current += key if key[0] not in ['.', '!'] else key[1:]
        return current

    @staticmethod
    def _merge(base, new):
        for k,v2 in new.items():
            v1 = base.get(k) # returns None if v1 has no value for this key

            if k[0] == '!':
                # '!' overrides the existing key.
                base[k[1:]] = v2
            elif (isinstance(v1, collections.Mapping) and
                isinstance(v2, collections.Mapping)):
                Spec._merge(v1, v2)
            else:
                base[k] = v2
    @staticmethod
    def merge(base, new, local_keys=[]):
        # remove local keys
        Spec._remove_keys(base, '.', local_keys)
        # normalize keys with '!' (remove '!')
        Spec._normalize(base, ['!'])
        Spec._merge(base, new)


    @staticmethod
    def _remove_keys(d, s, attrs_remove=[], attrpath=''):
        keys = d.keys()
        for k in keys:
            if k.startswith(s) or \
               Spec._attr_append(attrpath, k) in attrs_remove:
                del d[k]
            elif isinstance(d[k], collections.Mapping):
                Spec._remove_keys(d[k], s, attrs_remove, Spec._attr_append(attrpath, k))
    @staticmethod
    def _remove_vals(d, s):
        keys = d.keys()
        for k in keys:
            if d[k] == s:
                del d[k]
            elif isinstance(d[k], collections.Mapping):
                Spec._remove_vals(d[k], s)

    @staticmethod
    def _normalize(d, local_keys=[]):
        keys = d.keys()
        for k in keys:
            if k[0] in local_keys:
                d[k[1:]] = d[k]
                del d[k]
                k = k[1:]
            if isinstance(d[k], collections.Mapping):
                Spec._normalize(d[k], local_keys)

    def process_handlers(self):
        for h in self.handlers:
            pr_dbg('Processing handler', h)
            key = h['key']

            if self.group:
                for k,spec in self.specs.items():
                    if spec.has_key(key):
                        spec[key] = h['fn'](spec[key])
            else:
                if self.specs.has_key(key):
                        self.specs[key] = h['fn'](self.specs[key])

    def register_handler(self, handler):
        assert set(handler.keys()) == set(['key', 'fn'])
        pr_dbg('Registering handler', handler)
        self.handlers.append(handler)

    def preprocess(self):
        Spec._remove_keys(self.src, '#')

        if self.group:
            if self.src.has_key(self.group):
                # version is top-level key, but only existent in full spec
                self.version = self.src.get('version', '')
                if len(self.version) == 0:
                    pr_warn("version is missing!")
                elif self.version not in Spec.supported_version:
                    pr_err("Version %s is not supported." % self.version)
                    pr_warn("Trying anyway....")

                if self.src[self.group].has_key('.'):
                    self.local_keys = self.src[self.group]['.']
                    del self.src[self.group]['.']
            else:
                pr_err("Spec group '%s' is not found in spec." % self.group)
                sys.exit(1)

    def process(self):
        Spec._normalize(self.specs, ['.', '!'])
        Spec._remove_vals(self.specs, '-')

        # run registered handlers
        self.process_handlers()

    # replace main specs
    def set_specs(self, specs):
        self.specs = specs

    # merge with new specs
    def merge_specs(self, specs):
        Spec.merge(self.specs, specs)

    def get(self, path=''):
        base = self.specs
        if path:
            for k in path.split('.'):
                base = base.get(k,{})
        return base

    @staticmethod
    def set(base, path, val):
        # path must not be null
        assert path
        # consider supporting non-string types: dict, val, etc..
        assert isinstance(val, types.StringTypes)

        path = path.split('.')
        for k in path[:-1]:
            pr_dbg(type(base), k)
            if not base.has_key(k) or not isinstance(base[k], collections.Mapping):
                base[k] = {}
            base = base.get(k) # base[k]

        pr_dbg(base, path, path[-1], val)
        base[path[-1]] = val

    def apply_override(self, prefix='', skip_pp=False):
        if os.environ.has_key(self.override_env):
            kv = os.environ.get(self.override_env, '').split(',')
            override = [tuple(e.strip().split('=')) for e in kv]
            pr_dbg('override being applied', prefix, override)
            if override:
                for k,v in override:
                    Spec.set(self.specs, prefix + ('.' if prefix else '') + k, v)
                if not skip_pp:
                    self.process()

    def query(self, query=''):
        '''returns two different types depending on the last dot in query'''
        keys_only = False
        if query.endswith('.'):
            keys_only = True
            query = query[:-1]

        d = self.get(query)
        if keys_only:
            return d.keys() if isinstance(d, collections.Mapping) else []
        else:
            # return as-is
            return d

    def dump(self):
        pr(2, json.dumps(self.specs, sort_keys=False, indent=4, separators=(',', ': ')))

# HW Spec Class (derived fom Spec)
class HwSpec(Spec):
    def _mac_generator(s):
        if not isinstance(s, collections.Mapping):
            return s
        prefix = s.get('prefix')
        if prefix == None or len(prefix.split(':')) != 3:
            prefix = '0E:04:4B'

        prefix = prefix.upper()

        # 'random' is the only method supported for now
        if s['method'] == 'random':
            pass

        addr = binascii.b2a_hex(os.urandom(3)).upper()
        addr = prefix + ':' + ':'.join([addr[i:i+2] for i in range(0,len(addr),2)])

        return addr

    hw_key_modifier = \
        [ {'key' : 'wifi', 'fn': _mac_generator},
          {'key' : 'bt',   'fn': _mac_generator}]

    def __init__(self, **args):
        super(HwSpec, self).__init__(**args)

        self.override_env = 'TNSPEC_SET_HW'

        for m in HwSpec.hw_key_modifier:
            self.register_handler(m)

        skip_pp = args.get('skip_process', False)
        if not skip_pp:
            self.process()

    def process(self):
        # add id and config fields if they are not found
        if self.group:
            for e in self.specs.keys():
                if e[0] == '&':
                    continue
                if not self.specs[e].has_key('id'):
                    pr_dbg("adding a new id : ", e)
                    self.specs[e]['id'] = e
                if not self.specs[e].has_key('config'):
                    self.specs[e]['config'] = 'default'

        super(HwSpec, self).process()

# Go pretty :)
class bcolors(object):
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'

    def disable(self):
        self.HEADER = ''
        self.OKBLUE = ''
        self.OKGREEN = ''
        self.WARNING = ''
        self.FAIL = ''
        self.ENDC = ''

def main(cmds):
    commands = \
        {
            'nct'   : {'cls': CmdNCT},
            'spec'  : {'cls': CmdSpec},
            'help'  : {'cls': CmdHelp}
        }

    # set arguments for each method
    commands['help']['init'] = [commands]
    commands['help']['help'] = [commands]

    global product_id

    cmd = cmds[0]
    if not commands.has_key(cmd):
        command_failed()
        pr_err("Error: unknown command: " + cmd)
        CmdHelp.usage(2)
        sys.exit(1)

    pr_dbg(commands['help'])
    cmdobj = commands[cmd]['cls'](*tuple(commands[cmd].get('init', [])))
    ret = cmdobj.process(cmds[1:])
    if ret:
        command_failed()
        pr_err("Error: tnspec %s %s: %s" %
                (cmd, cmds[1] if len(cmds) > 1 else '', ret))
        cmdobj.help(2, *tuple(commands[cmd].get('help',[])))
        sys.exit(1)
    sys.exit(0)

def split_cmds():
    # split commands and args. find the first occurence of a string starting
    # with '-'
    global g_argv_copy
    g_argv_copy = cmds = sys.argv[1:]
    options = []

    for i in range(len(g_argv_copy)):
        if len(g_argv_copy[i]) and g_argv_copy[i][0] == '-':
            options = g_argv_copy[i:]
            cmds = g_argv_copy[:i]
            break

    return (cmds, options)

if __name__ == "__main__":
    (cmds, options) = split_cmds()
    if len(cmds) == 0:
        CmdHelp.usage(2)
        sys.exit(1)
    # set options (-o, --options)
    set_options(options)
    main(cmds)
