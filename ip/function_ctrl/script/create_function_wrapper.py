#=================================================
# Copyright 2025 NTT Corporation
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#=================================================

import argparse

class FunctionWrapper:

    _module_name = ''
    _bundles = {}
    _bundle_types = {}
    _binds = {}
    _unbundles = {}
    _global_signals = {}
    _axis_inputs = []
    _axis_outputs = []
    _axi_slaves = []
    _axi_masters = []
    _inputs = {}
    _outputs = {}

    def __init__(self):
        return

    def Analyze(self, filename):
        signals = []

        self.load_top(filename)
        signals.extend(self._inputs.keys())
        signals.extend(self._outputs.keys())

        bundle_cand = self.infer_bundle(signals)
        unbundles = self.infer_bundle_signals(bundle_cand, signals)
        self.infer_global_signals(unbundles)
        self.map_function_ctrl_ports()

    def AddBind(self, name, bind_name):
        if name in self._unbundles:
            self._binds[name] = bind_name
            self._unbundles.remove(name)
            return True
        return False

    def GetInout(self):
        return self._inputs, self._outputs

    def GetAxis(self):
        return self._axis_inputs, self._axis_outputs

    def GetAxi(self):
        return self._axi_slaves, self._axi_masters

    def GetBinds(self):
        return self._binds

    def GetGlobals(self):
        return self._global_signals

    def GetBundles(self):
        return self._bundles, self._unbundles

    def GetBundleTypes(self):
        return self._bundle_types

    def GetModuleName(self):
        return self._module_name

    def load_top(self, filename):
        local_params = {}
        with open(filename) as f:
            oneline = ''
            for line in f.readlines():
                line = line.strip()
                if len(oneline) > 0:
                    oneline += ' '
                oneline += line
                if len(line) == 0:
                    continue
                if line[-1] != ';':
                    continue
                oneline = oneline.replace(';','').strip()
                while oneline != oneline.replace(' -', ' '):
                    oneline = oneline.replace(' -', '-')
                while oneline != oneline.replace('- ', ' '):
                    oneline = oneline.replace('- ', '-')
                while oneline != oneline.replace('  ', ' '):
                    oneline = oneline.replace('  ', ' ')
                tokens = oneline.split(' ')
                if len(tokens) > 1:
                    if tokens[0] == 'parameter' and len(tokens) > 3:
                        value = ''
                        for token in tokens[3:]:
                            value += token
                            local_params[tokens[1]] = value
                    elif tokens[0] == 'input':
                        if len(tokens) == 2:
                            self._inputs[tokens[1]] = ''
                        else:
                            width = tokens[1]
                            for param in local_params:
                                width = width.replace(param, local_params[param])
                            self._inputs[tokens[2]] = width
                    elif tokens[0] == 'output':
                        if len(tokens) == 2:
                            self._outputs[tokens[1]] = ''
                        else:
                            width = tokens[1]
                            for param in local_params:
                                width = width.replace(param, local_params[param])
                            self._outputs[tokens[2]] = width
                    else:
                        for idx in range(0, len(tokens)-3):
                            if tokens[idx] == 'module' and tokens[idx+2] == '(':
                                self._module_name = tokens[idx+1]
                                break
                oneline = ''

    def infer_bundle(self, signals):
        bundle_cand = []
        for idx in range(0, len(signals)):
            base = signals[idx]
            base_len = len(base)
            bundle_max = 0
            for idx2 in range(idx+1, len(signals)):
                target = signals[idx2]
                tar_len = len(target)
                if base_len < tar_len:
                    length = base_len
                else:
                    length = tar_len
                max_len = 0
                max_len_cand = 0
                for l in range(1, length):
                    if base[:l] != target[:l]:
                        max_len = max_len_cand
                        break
                    if base[l] == '_':
                        max_len_cand = l+1
                if max_len > 1 and bundle_max < max_len:
                    bundle_max = max_len
                    need_append = True
                    for cand in bundle_cand:
                        if base[:max_len] in cand:
                            need_append = False
                            break
                    if not need_append:
                        continue
                    erase_cand = []
                    for cand in bundle_cand:
                        if base[:max_len].find(cand) >= 0:
                            erase_cand.append(cand)
                    for cand in erase_cand:
                        bundle_cand.remove(cand)
                    bundle_cand.append(base[:max_len])
        return bundle_cand

    def infer_bundle_signals(self, bundle_cand, signals):
        unbundles = []
        unbundles.extend(signals)
        funcs = [self.infer_axis, self.infer_axi, self.infer_ap_ctrl]
        types = {'t': 'axis', 'aw': 'axi_aw', 'w': 'axi_w', 'b': 'axi_b', 'ar': 'axi_ar', 'r': 'axi_r'}
        for cand in bundle_cand:
            cur_bundle = {}
            cur_types = []
            for sig in signals:
                if not cand in sig:
                    continue
                for func in funcs:
                    sig_cand = func(cand, sig)
                    if sig_cand is not None:
                        cur_bundle[sig_cand] = sig
                        unbundles.remove(sig)
                        cur_type = ''
                        if sig[0:3] == 'ap_':
                            cur_type = 'ap_ctrl'
                        elif sig_cand[0] in types:
                            cur_type = types[sig_cand[0]]
                        elif sig_cand[0:2] in types:
                            cur_type = types[sig_cand[0:2]]
                        if len(cur_type)>0 and not cur_type in cur_types:
                            cur_types.append(cur_type)
            if len(cur_bundle) > 0:
                self._bundles[cand] = cur_bundle
                self._bundle_types[cand] = cur_types
        return unbundles

    def infer_axis(self, prefix, signal):
        if prefix == 'ap_':
            return None
        signals = ['data', 'keep', 'strb', 'last', 'id', 'user', 'dest', 'valid', 'ready']
        name = signal.replace(prefix, '').lower()
        for sig in signals:
            tsig = 't' + sig
            if name == tsig or name == sig:
                return tsig
        return None

    def infer_axi(self, prefix, signal):
        if prefix == 'ap_':
            return None
        asignals = ['addr', 'len', 'size', 'burst', 'id', 'cache', 'lock', 'prot', 'qos', 'region', 'user', 'valid', 'ready']
        dsignals = ['data', 'id', 'last', 'user', 'valid', 'ready']
        wsignals = ['strb']
        rsignals = ['resp']
        bsignals = ['id', 'resp', 'user', 'valid', 'ready']
        name = signal.replace(prefix, '').lower()
        for sig in asignals:
            arsig = 'ar' + sig
            awsig = 'aw' + sig
            if name == arsig:
                return arsig
            elif name == awsig:
                return awsig
        for sig in dsignals:
            rsig = 'r' + sig
            wsig = 'w' + sig
            if name == rsig:
                return rsig
            elif name == wsig:
                return wsig
        for sig in wsignals:
            wsig = 'w' + sig
            if name == wsig:
                return wsig
        for sig in rsignals:
            rsig = 'r' + sig
            if name == rsig:
                return rsig
        for sig in bsignals:
            bsig = 'b' + sig
            if name == bsig:
                return bsig
        return None

    def infer_ap_ctrl(self, prefix, signal):
        if prefix != 'ap_':
            return None
        signals = ['start', 'idle', 'done', 'ready', 'continue']
        name = signal.replace(prefix, '').lower()
        for sig in signals:
            if name == sig:
                return sig
        return None

    def infer_global_signals(self, signals):
        unbundles = []
        unbundles.extend(signals)
        for sig in signals:
            sig_cand = self.infer_global_signal(sig)
            if sig_cand is not None:
                self._global_signals[sig_cand] = sig
                unbundles.remove(sig)
        self._unbundles = unbundles

    def infer_global_signal(self, sig):
        rsts = ['rst', 'reset']
        negs = ['_n', 'n']
        clks = ['clk', 'clock']
        for rst in rsts:
            if sig.find(rst) >= 0:
                for neg in negs:
                    if sig.rfind(neg) == len(sig) - len(neg):
                        return 'resetn'
                return 'reset'
        for clk in clks:
            if sig.find(clk) >= 0:
                return 'clk'
        return None

    def map_function_ctrl_ports(self):
        for port in self._bundles:
            cur_bundle = self._bundles[port]
            if 'axis' in self._bundle_types[port]:
                valid_signal = cur_bundle['tvalid']
                if valid_signal in self._inputs:
                    self._axis_inputs.append(port)
                else:
                    self._axis_outputs.append(port)
            elif 'axi_ar' in self._bundle_types[port] and 'axi_aw' in self._bundle_types[port]:
                valid_signal = cur_bundle['arvalid']
                if valid_signal in self._inputs:
                    self._axi_slaves.append(port)
                else:
                    self._axi_masters.append(port)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', '--input', required=True)
    parser.add_argument('-o', '--output', required=True)

    args = parser.parse_args()

    wrapper = FunctionWrapper()
    wrapper.Analyze(args.input)

    module_name = wrapper.GetModuleName()
    inputs, outputs = wrapper.GetInout()
    bundles, unbundles = wrapper.GetBundles()
    bundle_types = wrapper.GetBundleTypes()
    global_signals = wrapper.GetGlobals()
    axis_inputs, axis_outputs = wrapper.GetAxis()
    axi_slaves, axi_masters = wrapper.GetAxi()
    print('function: ', module_name)
    for key in bundles:
        print('bundle: ', key, bundles[key], bundle_types[key])
    print('globals: ', global_signals)
    print('unbundle: ', unbundles)
    print('axis input: ', axis_inputs)
    print('axis output: ', axis_outputs)
    print('axi slaves: ', axi_slaves)
    print('axi masters: ', axi_masters)
